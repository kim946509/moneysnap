package com.ansandy.moneysnap.identity;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.authentication.AnonymousAuthenticationFilter;
import org.springframework.security.web.SecurityFilterChain;

import tools.jackson.databind.ObjectMapper;

import com.ansandy.moneysnap.shared.http.ApiErrorCode;
import com.ansandy.moneysnap.shared.http.ApiErrorResponse;

import static org.springframework.http.MediaType.APPLICATION_JSON_VALUE;

@Configuration(proxyBeanMethods = false)
class ApiSecurityConfiguration {

	@Bean
	SecurityFilterChain apiSecurityFilterChain(
			HttpSecurity http,
			IdentitySessionService sessions,
			ObjectMapper objectMapper) throws Exception {
		http.csrf(AbstractHttpConfigurer::disable)
				.sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.exceptionHandling(exceptions -> exceptions.authenticationEntryPoint(
						(request, response, exception) -> {
							response.setStatus(401);
							response.setContentType(APPLICATION_JSON_VALUE);
							objectMapper.writeValue(
									response.getOutputStream(),
									ApiErrorResponse.of(ApiErrorCode.SESSION_REJECTED));
						}))
				.addFilterBefore(new MoneySnapAuthenticationFilter(sessions), AnonymousAuthenticationFilter.class);
		http.authorizeHttpRequests(authorize -> authorize
				.requestMatchers(
						"/",
						"/actuator/health",
						"/actuator/prometheus",
						"/api/v1/auth/apple",
						"/api/v1/auth/apple/events",
						"/api/v1/auth/refresh").permitAll()
				.requestMatchers("/api/v1/**").authenticated()
				.anyRequest().denyAll());

		return http.build();
	}
}
