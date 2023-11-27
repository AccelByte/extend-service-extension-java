package net.accelbyte.grpc;

import com.google.protobuf.Descriptors;
import lombok.extern.slf4j.Slf4j;
import net.accelbyte.custom.guild.Action;
import net.accelbyte.custom.guild.Permission;
import org.springframework.stereotype.Component;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static net.accelbyte.sdk.core.AccessTokenPayload.Types;

@Component
@Slf4j
public class ProtoPermissionExtractor {

    public Types.Permission extractPermission(Descriptors.ServiceDescriptor serviceDesc, String protoFullMethod) {
        Pattern pattern = Pattern.compile("(.*)/(.*)");
        Matcher matcher = pattern.matcher(protoFullMethod);

        if (!matcher.matches()) {
            throw new IllegalArgumentException("Invalid gRPC method name format");
        }

        String serviceName = matcher.group(1);
        String methodName = matcher.group(2);

        Descriptors.MethodDescriptor method = serviceDesc.findMethodByName(methodName);
        if (method == null) {
            throw new IllegalArgumentException("gRPC Method not found");
        }

        Action action = method.getOptions().getExtension(Permission.action);
        String resource = method.getOptions().getExtension(Permission.resource);

        return wrapPermission(resource, action.getNumber());
    }

    private Types.Permission wrapPermission(String resource, int action) {
        return Types.Permission.builder()
                .resource(resource)
                .action(action)
                .build();
    }

}
