package com.ansandy.moneysnap;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.PosixFilePermission;
import java.util.Set;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.event.ApplicationEnvironmentPreparedEvent;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.ApplicationListener;

@SpringBootApplication
public class MoneySnapServerApplication {

	public static void main(String[] args) {
		SpringApplication application = new SpringApplication(MoneySnapServerApplication.class);
		application.addListeners((ApplicationListener<ApplicationEnvironmentPreparedEvent>) event ->
				prepareSqliteFile(event.getEnvironment().getProperty("spring.datasource.url")));
		application.addListeners((ApplicationListener<ApplicationReadyEvent>) event ->
				prepareSqliteFile(event.getApplicationContext().getEnvironment().getProperty("spring.datasource.url")));
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
		try {
			if (parent != null) {
				Files.createDirectories(parent);
				restrictToOwner(parent, true);
			}
			restrictToOwner(file, false);
			restrictToOwner(Path.of(path + "-wal"), false);
			restrictToOwner(Path.of(path + "-shm"), false);
		}
		catch (IOException exception) {
			throw new IllegalStateException("Unable to prepare SQLite data directory: " + parent, exception);
		}
	}

	private static void restrictToOwner(Path path, boolean directory) throws IOException {
		if (!Files.exists(path)) {
			return;
		}
		try {
			Files.setPosixFilePermissions(path, directory
					? Set.of(
							PosixFilePermission.OWNER_READ,
							PosixFilePermission.OWNER_WRITE,
							PosixFilePermission.OWNER_EXECUTE)
					: Set.of(PosixFilePermission.OWNER_READ, PosixFilePermission.OWNER_WRITE));
		}
		catch (UnsupportedOperationException ignored) {
			// Windows local runs do not expose POSIX permission bits.
		}
	}

}
