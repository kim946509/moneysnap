package com.ansandy.moneysnap.identity;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration(proxyBeanMethods = false)
class ApiSecurityConfiguration {

	@Bean
	SecurityFilterChain apiSecurityFilterChain(HttpSecurity http) throws Exception {
		http.authorizeHttpRequests(authorize -> authorize
				.requestMatchers("/", "/actuator/health", "/actuator/prometheus").permitAll()
				.anyRequest().denyAll());

		return http.build();
	}
}
