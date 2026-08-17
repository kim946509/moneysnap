package com.ansandy.moneysnap.identity;

import java.io.IOException;
import java.util.List;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import com.ansandy.moneysnap.shared.AuthenticatedUser;

final class MoneySnapAuthenticationFilter extends OncePerRequestFilter {

	private static final String BEARER_PREFIX = "Bearer ";

	private final IdentitySessionService sessions;

	MoneySnapAuthenticationFilter(IdentitySessionService sessions) {
		this.sessions = sessions;
	}

	@Override
	protected void doFilterInternal(
			HttpServletRequest request,
			HttpServletResponse response,
			FilterChain filterChain) throws ServletException, IOException {
		String authorization = request.getHeader("Authorization");
		if (authorization != null && authorization.startsWith(BEARER_PREFIX)) {
			String accessToken = authorization.substring(BEARER_PREFIX.length());
			try {
				SessionActor actor = sessions.authenticate(accessToken);
				SecurityContextHolder.getContext().setAuthentication(
						UsernamePasswordAuthenticationToken.authenticated(
								new AuthenticatedUser(actor.userId()), accessToken, List.of()));
			}
			catch (IdentitySessionException ignored) {
				SecurityContextHolder.clearContext();
			}
		}
		filterChain.doFilter(request, response);
	}
}
