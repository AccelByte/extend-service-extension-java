# Example: Debugging a 500 Internal Server Error

This annotated example shows a realistic debugging session for an Extend Service Extension
(Java/Spring Boot) app where `GetGuildProgress` returns `500 Internal Server Error`.

---

## The Report

A developer sends this message:

> *"My service is running but when I call GET
> `/v1/admin/namespace/mygame/progress/guild_001` through the gateway I get 500.
> The service started fine and I can see it in the logs."*

---

## Step 1 — Collect logs

Ask for or enable structured logging. Have the developer enable the gRPC debug logger
in `application.yml` (or via environment override):

```yaml
plugin:
  grpc:
    server:
      interceptor:
        debug-logger:
          enabled: true
```

The developer restarts and shares the relevant log lines:

```
INFO  n.a.e.s.grpc.DebugLoggerServerInterceptor - --> GetGuildProgress /service.Service/GetGuildProgress
ERROR n.a.e.s.service.MyService - java.lang.IllegalArgumentException:
  net.accelbyte.sdk.api.cloudsave.operations.admin_game_record.AdminGetGameRecordHandlerV1.execute(AdminGetGameRecordHandlerV1.java:74):
  [GET /cloudsave/v1/admin/namespaces/{namespace}/records/{key}][404] adminGetGameRecordHandlerV1NotFound
INFO  n.a.e.s.grpc.DebugLoggerServerInterceptor - <-- UNKNOWN GetGuildProgress
```

**What this tells us:**
- The request passed auth successfully (debug logger printed `-->`).
- `MyService.getGuildProgress` caught an exception from `CloudsaveStorage`.
- CloudSave returned HTTP 404 (record not found) for key `guildProgress_guild_001`.
- `MyService` rethrew it as `IllegalArgumentException`, which the gRPC framework maps to `Status.UNKNOWN` — exposed as HTTP 500 at the gateway.

---

## Step 2 — Read the service and storage layers

Looking at `src/main/java/.../service/MyService.java`:

```java
@Override
public void getGuildProgress(
    GetGuildProgressRequest request, StreamObserver<GetGuildProgressResponse> responseObserver
) {
    String guildProgressKey = String.format("guildProgress_%s", request.getGuildId());
    GetGuildProgressResponse response;
    try {
        GuildProgress result = storage.getGuildProgress(namespace, guildProgressKey);
        response = GetGuildProgressResponse.newBuilder()
                .setGuildProgress(result)
                .build();
    } catch (Exception e) {
        throw new IllegalArgumentException(e);   // ← all errors become UNKNOWN (500)
    }
    responseObserver.onNext(response);
    responseObserver.onCompleted();
}
```

Looking at `src/main/java/.../storage/CloudsaveStorage.java`:

```java
@Override
public GuildProgress getGuildProgress(String namespace, String key) throws Exception {
    AdminGetGameRecordHandlerV1 input = AdminGetGameRecordHandlerV1.builder()
            .namespace(namespace)
            .key(key)
            .build();
    ModelsGameRecordAdminResponse response = csStorage.adminGetGameRecordHandlerV1(input);
    // ↑ throws if CloudSave returns 404 — no special handling
    ...
}
```

**Problem identified:** `CloudsaveStorage` throws any CloudSave error unchanged. `MyService`
catches all `Exception` types and re-throws as `IllegalArgumentException`, which the gRPC
framework maps to `Status.UNKNOWN`. A legitimate "record not found" (a normal 404) surfaces
as a 500 Internal Server Error to the caller.

---

## Step 3 — Confirm with a breakpoint (optional)

If the logs are ambiguous, set a breakpoint at the `catch (Exception e)` line in
`MyService.getGuildProgress`.

1. Enable JDWP in `docker-compose.yaml` by uncommenting:
   ```yaml
   ports:
     - "5006:5006"
   environment:
     - JAVA_OPTS=-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5006
   ```
2. Restart the container (`docker-compose up --build`).
3. In VS Code, add a `launch.json` entry and attach:
   ```json
   {
     "type": "java",
     "name": "Attach to Remote JVM",
     "request": "attach",
     "hostName": "localhost",
     "port": 5006
   }
   ```
4. Set the breakpoint, trigger the request, inspect `e` in the Variables panel.
   The exception message will contain `[404] adminGetGameRecordHandlerV1NotFound`.

---

## Step 4 — The fix

There are two layers to correct:

**`CloudsaveStorage.java`** — detect the 404 and throw a typed exception:

```java
// Before
@Override
public GuildProgress getGuildProgress(String namespace, String key) throws Exception {
    ...
    ModelsGameRecordAdminResponse response = csStorage.adminGetGameRecordHandlerV1(input);
    CloudSaveModel model = mapper.convertValue(response.getValue(), CloudSaveModel.class);
    return model.toGuildProgress();
}

// After
@Override
public GuildProgress getGuildProgress(String namespace, String key) throws Exception {
    ...
    try {
        ModelsGameRecordAdminResponse response = csStorage.adminGetGameRecordHandlerV1(input);
        CloudSaveModel model = mapper.convertValue(response.getValue(), CloudSaveModel.class);
        return model.toGuildProgress();
    } catch (Exception e) {
        if (e.getMessage() != null && e.getMessage().contains("NotFound")) {
            throw new io.grpc.StatusRuntimeException(
                io.grpc.Status.NOT_FOUND.withDescription("Guild progress not found: " + key));
        }
        throw e;
    }
}
```

**`MyService.java`** — let `StatusRuntimeException` propagate without re-wrapping:

```java
// Before
} catch (Exception e) {
    throw new IllegalArgumentException(e);
}

// After
} catch (io.grpc.StatusRuntimeException e) {
    throw e;   // already a proper gRPC status — let it propagate
} catch (Exception e) {
    throw io.grpc.Status.INTERNAL
            .withDescription("Internal error in getGuildProgress")
            .withCause(e)
            .asRuntimeException();
}
```

---

## Step 5 — Verify

```bash
# Rebuild the service
./gradlew build

# Restart (or docker-compose up --build if running in Docker)

# The response should now be 404, not 500
curl -s -o /dev/null -w "%{http_code}" \
  http://localhost:8000/v1/admin/namespace/mygame/progress/nonexistent_guild
# Expected: 404

# Via grpcurl directly to the Java server
grpcurl -plaintext -d '{"guild_id":"nonexistent_guild"}' \
  localhost:6565 service.Service/GetGuildProgress
# Expected: status: NOT_FOUND
```

---

## Key takeaways from this session

1. **Enable the debug logger interceptor** — `DebugLoggerServerInterceptor` already logs the
   gRPC method name and status code; enable it with one config flag to get request/response
   details without adding any code.
2. **`IllegalArgumentException` becomes `UNKNOWN`** — the gRPC Spring Boot framework maps
   unchecked exceptions that are not `StatusRuntimeException` to `Status.UNKNOWN` (HTTP 500).
   Always throw `StatusRuntimeException` with an appropriate `Status` code.
3. **CloudSave 404 is not an error** — a missing record is a normal "not found" condition,
   not an internal server error. Map it to `Status.NOT_FOUND` so callers can handle it correctly.
4. **JDWP is pre-wired** — `docker-compose.yaml` already has the JDWP and port 5006 block;
   it just needs to be uncommented. No Dockerfile changes are required.
