package com.ansandy.moneysnap;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.event.ApplicationEnvironmentPreparedEvent;
import org.springframework.context.ApplicationListener;

@SpringBootApplication
public class MoneySnapServerApplication {

	public static void main(String[] args) {
		SpringApplication application = new SpringApplication(MoneySnapServerApplication.class);
		application.addListeners((ApplicationListener<ApplicationEnvironmentPreparedEvent>) event ->
				prepareSqliteFile(event.getEnvironment().getProperty("spring.datasource.url")));
		application.run(args);
	}

	static void prepareSqliteFile(String jdbcUrl) {
		if (jdbcUrl == null || !jdbcUrl.startsWith("jdbc:sqlite:")) {
			return;
		}
		String path = jdbcUrl.substring("jdbc:sqlite:".length());
		if (path.startsWith("file:")) {
			path = path.substring("file:".length());
		}
		int query = path.indexOf('?');
		if (query >= 0) {
			path = path.substring(0, query);
		}
		if (path.isBlank() || path.contains("mode=memory") || ":memory:".equals(path)) {
			return;
		}
		Path file = Path.of(path);
		Path parent = file.getParent();
		if (parent != null) {
			try {
				Files.createDirectories(parent);
			}
			catch (IOException exception) {
				throw new IllegalStateException("Unable to create SQLite data directory: " + parent, exception);
			}
		}
	}

}
