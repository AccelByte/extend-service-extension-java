package net.accelbyte.config;

import net.accelbyte.sdk.core.AccelByteSDK;
import net.accelbyte.sdk.core.client.OkhttpClient;
import net.accelbyte.sdk.core.repository.DefaultConfigRepository;
import net.accelbyte.sdk.core.repository.DefaultTokenRefreshRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.server.ServerErrorException;

@Configuration
public class AppConfig {

    @Bean
    public AccelByteSDK provideAccelbyteSdk() {
        AccelByteSDK sdk = new AccelByteSDK(
                new OkhttpClient(), new DefaultTokenRefreshRepository(), new DefaultConfigRepository());
        boolean isSuccess = sdk.loginClient();
        if (!isSuccess) {
            throw new ServerErrorException("failed to sdk.loginClient()", new IllegalArgumentException());
        }
        return sdk;
    }

}
