package com.ansandy.moneysnap.identity;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.authentication.AnonymousAuthenticationFilter;
import org.springframework.security.web.SecurityFilterChain;

@Configuration(proxyBeanMethods = false)
class ApiSecurityConfiguration {

	@Bean
	SecurityFilterChain apiSecurityFilterChain(
			HttpSecurity http,
			IdentitySessionService sessions) throws Exception {
		http.csrf(AbstractHttpConfigurer::disable)
				.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.exceptionHandling(exceptions -> exceptions.authenticationEntryPoint(
						(request, response, exception) -> response.sendError(401)))
				.addFilterBefore(new MoneySnapAuthenticationFilter(sessions), AnonymousAuthenticationFilter.class);
		http.authorizeHttpRequests(authorize -> authorize
				.requestMatchers(
						"/",
						"/actuator/health",
						"/actuator/prometheus",
						"/api/v1/auth/apple",
						"/api/v1/auth/refresh").permitAll()
				.requestMatchers("/api/v1/**").authenticated()
				.anyRequest().denyAll());

		return http.build();
	}
}
