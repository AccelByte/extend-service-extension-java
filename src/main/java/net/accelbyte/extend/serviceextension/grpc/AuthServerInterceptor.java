package net.accelbyte.extend.serviceextension.grpc;

import com.google.protobuf.Descriptors;
import io.grpc.*;
import io.grpc.protobuf.ProtoMethodDescriptorSupplier;
import lombok.extern.slf4j.Slf4j;
import net.accelbyte.sdk.core.AccelByteSDK;
import net.accelbyte.sdk.core.validator.UserAuthContext;
import org.lognet.springboot.grpc.GRpcGlobalInterceptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.annotation.Order;

import static net.accelbyte.sdk.core.AccessTokenPayload.Types.Permission;

@Slf4j
@GRpcGlobalInterceptor
@Order(20)
public class AuthServerInterceptor implements ServerInterceptor {

    @Value("${plugin.grpc.server.interceptor.auth.enabled:true}")
    private boolean enabled;

    private AccelByteSDK sdk;

    private ProtoPermissionExtractor permissionExtractor;

    private String namespace;

    @Autowired
    public AuthServerInterceptor(
            @Value("${plugin.grpc.config.namespace}") String namespace,
            AccelByteSDK sdk,
            ProtoPermissionExtractor permissionExtractor) {

        this.sdk = sdk;
        this.namespace = namespace;
        this.permissionExtractor = permissionExtractor;

        log.info("AuthServerInterceptor initialized");
    }

    @Override
    public <ReqT, RespT> ServerCall.Listener<ReqT> interceptCall(ServerCall<ReqT, RespT> call, Metadata headers,
            ServerCallHandler<ReqT, RespT> next) {
        if (!enabled) {
            return next.startCall(call, headers);
        }

        log.info("AuthServerInterceptor::interceptCall start");
        try {
            final String authHeader = headers.get(Metadata.Key.of("authorization", Metadata.ASCII_STRING_MARSHALLER));

            if (authHeader == null) {
                throw new Exception("Auth header is null");
            }

            final String[] authTypeToken = authHeader.split(" ");

            if (authTypeToken.length != 2) {
                throw new Exception("Invalid auth header format");
            }

            final String authToken = authTypeToken[1];
            log.debug("TOKEN: {}",authToken);
            MethodDescriptor<ReqT, RespT> methodDesc = call.getMethodDescriptor();
            Object methodSchemaDesc = methodDesc.getSchemaDescriptor();
            if (!(methodSchemaDesc instanceof ProtoMethodDescriptorSupplier)) {
                throw new Exception("Invalid grpc method descriptor");
            }
            Descriptors.ServiceDescriptor serviceDesc = ((ProtoMethodDescriptorSupplier) methodSchemaDesc).getServiceDescriptor();
            String methodFullName = call.getMethodDescriptor().getFullMethodName();
            Permission permission = permissionExtractor.extractPermission(serviceDesc, methodFullName);
            UserAuthContext authContext = UserAuthContext.builder()
                    .token(authToken)
                    .namespace(this.namespace)
                    .build();
            if (!sdk.validateToken(authContext, permission)) {
                throw new Exception("Auth token validation failed");
            }
        } catch (Exception e) {
            log.info("Authorization error: " + e.getMessage());
            log.error("Authorization error", e);
            unAuthorizedCall(call, headers, e);
        }

        return next.startCall(call, headers);
    }

    private <ReqT, RespT> void unAuthorizedCall(ServerCall<ReqT, RespT> call, Metadata headers, Exception e) {
        String reason = e.getLocalizedMessage();
        String message = "Call not authorized: [%s]".formatted(reason);
        call.close(Status.UNAUTHENTICATED.withDescription(message).withCause(e), headers);
    }
}
