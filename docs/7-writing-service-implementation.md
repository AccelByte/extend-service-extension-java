# Chapter 7: Writing Service Implementations

Now that we have defined our service, the next step is to implement our service. 
This is where we define the actual logic of our gRPC methods.

We'll be doing this in the `src/main/java/net/accelbyte/service/GuildService.java` file.

Here's a brief outline of what this chapter will cover:

## 7.1 Setting Up the Guild Service

### 7.1 Setting Up the Guild Service
To set up our guild service, we'll first create a class derived from `GuildServiceGrpc.GuildServiceImplBase `. This class will act as our service implementation.

```java
import io.grpc.stub.StreamObserver;
import lombok.extern.slf4j.Slf4j;
import net.accelbyte.custom.guild.*;
import net.accelbyte.sdk.core.AccelByteSDK;
import net.accelbyte.storage.CloudsaveStorage;
import net.accelbyte.storage.Storage;
import org.lognet.springboot.grpc.GRpcService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;

@GRpcService
@Slf4j
public class GuildService extends GuildServiceGrpc.GuildServiceImplBase {
    
}

```

To implement the `CreateOrUpdateGuildProgress` function, you can override the method like this:
```java
   @Override
    public void createOrUpdateGuildProgress(
        CreateOrUpdateGuildProgressRequest request, StreamObserver<CreateOrUpdateGuildProgressResponse> responseObserver
    ) {
        
        // Implementation goes here
    }
```

And similarly for the `GetGuildProgress` function:

```java
    @Override
    public void getGuildProgress(
        GetGuildProgressRequest request, StreamObserver<GetGuildProgressResponse> responseObserver
    ) {
        // Implementation goes here
    }
```

In these methods, you would include the logic to interact with CloudSave or 
any other dependencies in order to process the requests.