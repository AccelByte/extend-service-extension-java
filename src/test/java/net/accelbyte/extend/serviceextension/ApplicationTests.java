package net.accelbyte.extend.serviceextension;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import net.accelbyte.extend.serviceextension.config.AppConfig;

@SpringBootTest(
	classes = AppConfig.class,
	properties = "spring.main.allow-bean-definition-overriding=true"
)
class ApplicationTests {

	@Test
	void contextLoads() {
		
	}

}
