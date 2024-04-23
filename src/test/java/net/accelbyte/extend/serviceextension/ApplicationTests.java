package net.accelbyte.extend.serviceextension;

import net.accelbyte.extend.serviceextension.config.MockedAppConfig;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest(
	classes = MockedAppConfig.class,
	properties = "spring.main.allow-bean-definition-overriding=true"
)
class ApplicationTests {

	@Test
	void contextLoads() {
		
	}

}
