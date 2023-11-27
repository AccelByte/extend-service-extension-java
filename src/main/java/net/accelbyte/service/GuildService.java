package net.accelbyte.service;

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

    private final String namespace;

    private final Storage storage;

    @Autowired
    public GuildService(
        @Value("${plugin.grpc.config.namespace}") String namespace,
        AccelByteSDK sdk
    ) {
        storage = new CloudsaveStorage(sdk);
        this.namespace = namespace;
        log.info("GuildService initialized");
    }

    @Override
    public void createOrUpdateGuildProgress(
        CreateOrUpdateGuildProgressRequest request, StreamObserver<CreateOrUpdateGuildProgressResponse> responseObserver
    ) {
        String guildProgressKey = String.format("guildProgress_%s", request.getGuildProgress().getGuildId());
        GuildProgress guildProgressValue = request.getGuildProgress();

        CreateOrUpdateGuildProgressResponse response;
        try {
            GuildProgress result = storage.saveGuildProgress(namespace, guildProgressKey, guildProgressValue);
            response = CreateOrUpdateGuildProgressResponse.newBuilder()
                    .setGuildProgress(result)
                    .build();
        } catch (Exception e) {
            throw new IllegalArgumentException(e);
        }

        responseObserver.onNext(response);
        responseObserver.onCompleted();
    }

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
            throw new IllegalArgumentException(e);
        }

        responseObserver.onNext(response);
        responseObserver.onCompleted();
    }

}