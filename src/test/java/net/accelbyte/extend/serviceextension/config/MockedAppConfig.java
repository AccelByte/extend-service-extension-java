package net.accelbyte.extend.serviceextension.config;

import net.accelbyte.sdk.core.AccelByteSDK;
import org.mockito.Mockito;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

@TestConfiguration
public class MockedAppConfig {

    @Bean
    @Primary
    public AccelByteSDK provideAccelbyteSdk() {
        return Mockito.mock(AccelByteSDK.class);
    }
}
