package net.accelbyte.storage;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.Data;
import lombok.EqualsAndHashCode;
import lombok.NoArgsConstructor;
import lombok.experimental.FieldNameConstants;
import net.accelbyte.custom.guild.GuildProgress;
import net.accelbyte.sdk.api.cloudsave.models.ModelsGameRecordRequest;
import net.accelbyte.sdk.api.cloudsave.models.ModelsGameRecordAdminResponse;
import net.accelbyte.sdk.api.cloudsave.operations.admin_game_record.AdminGetGameRecordHandlerV1;
import net.accelbyte.sdk.api.cloudsave.operations.admin_game_record.AdminPostGameRecordHandlerV1;
import net.accelbyte.sdk.api.cloudsave.wrappers.AdminGameRecord;
import net.accelbyte.sdk.core.AccelByteSDK;

import java.util.Map;

public class CloudsaveStorage implements Storage {

    private final AdminGameRecord csStorage;

    private final ObjectMapper mapper;

    public CloudsaveStorage(AccelByteSDK sdk) {
        this.csStorage = new AdminGameRecord(sdk);
        mapper = new ObjectMapper();
    }

    @Override
    public GuildProgress getGuildProgress(String namespace, String key) throws Exception {
        AdminGetGameRecordHandlerV1 input = AdminGetGameRecordHandlerV1.builder()
                .namespace(namespace)
                .key(key)
                .build();
        ModelsGameRecordAdminResponse response = csStorage.adminGetGameRecordHandlerV1(input);
        CloudSaveModel model = mapper.convertValue(response.getValue(), CloudSaveModel.class);
        return model.toGuildProgress();
    }

    @Override
    public GuildProgress saveGuildProgress(String namespace, String key, GuildProgress value) throws Exception {
        CloudSaveModel cloudModel = new CloudSaveModel(value);
        AdminPostGameRecordHandlerV1 input = AdminPostGameRecordHandlerV1.builder()
                .namespace(namespace)
                .key(key)
                .body(cloudModel)
                .build();
        ModelsGameRecordAdminResponse response = csStorage.adminPostGameRecordHandlerV1(input);
        CloudSaveModel model = mapper.convertValue(response.getValue(), CloudSaveModel.class);
        return model.toGuildProgress();
    }

    @Data
    @EqualsAndHashCode(callSuper = true)
    @FieldNameConstants
    @NoArgsConstructor
    public static class CloudSaveModel extends ModelsGameRecordRequest {

        @JsonProperty
        private String guild_id;

        @JsonProperty
        private String namespace;

        @JsonProperty
        private Map<String, Integer> objectives;


        public CloudSaveModel(GuildProgress guildProgress) {
            guild_id = guildProgress.getGuildId();
            namespace = guildProgress.getNamespace();
            objectives = guildProgress.getObjectivesMap();
        }

        public GuildProgress toGuildProgress() {
            return GuildProgress.newBuilder()
                    .setGuildId(guild_id)
                    .setNamespace(namespace)
                    .putAllObjectives(objectives)
                    .build();
        }

    }
}
