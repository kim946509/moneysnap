package com.ansandy.moneysnap;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.PosixFilePermission;
import java.time.Instant;
import java.util.Properties;

import com.ansandy.moneysnap.shared.SqliteColumns;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assumptions.assumeThat;

class SqliteConfigurationContractTests {

	@Test
	void runtimeUsesASingleSqliteDatasourceWithoutNeonOrSeparateFlywayUrl() throws IOException {
		Properties properties = new Properties();
		try (InputStream input = getClass().getResourceAsStream("/application.properties")) {
			assertThat(input).isNotNull();
			properties.load(input);
		}

		assertThat(properties.getProperty("spring.datasource.url"))
				.startsWith("${MONEYSNAP_SQLITE_URL:jdbc:sqlite:");
		assertThat(properties.getProperty("spring.datasource.driver-class-name"))
				.isEqualTo("org.sqlite.JDBC");
		assertThat(properties.getProperty("spring.datasource.hikari.maximum-pool-size"))
				.isEqualTo("1");
		assertThat(properties)
				.doesNotContainKeys(
						"spring.flyway.url",
						"spring.flyway.user",
						"spring.flyway.password",
						"spring.datasource.username",
						"spring.datasource.password");
		assertThat(properties.stringPropertyNames())
				.noneMatch(name -> name.contains("NEON"));
	}

	@Test
	void storesInstantsAsIso8601TruncatedToMicroseconds() {
		Instant nanoseconds = Instant.parse("2026-08-13T15:30:00.123456789Z");
		assertThat(SqliteColumns.instant(nanoseconds)).isEqualTo("2026-08-13T15:30:00.123456Z");
		assertThat(SqliteColumns.instant(nanoseconds)).isNotEqualTo(nanoseconds.toString());
	}

	@Test
	void sqliteDirectoryAndDatabaseFileAreOwnerOnlyOnPosix() throws IOException {
		assumeThat(FileSystems.getDefault().supportedFileAttributeViews()).contains("posix");
		Path root = Files.createTempDirectory("moneysnap-sqlite-perm");
		Path database = root.resolve("data").resolve("moneysnap.db");
		Files.createDirectories(database.getParent());
		Files.writeString(database, "");
		Files.writeString(Path.of(database + "-wal"), "");

		MoneySnapServerApplication.prepareSqliteFile(
				"jdbc:sqlite:file:" + database.toAbsolutePath().toString().replace('\\', '/') + "?foreign_keys=on");

		assertThat(Files.getPosixFilePermissions(database.getParent()))
				.containsExactlyInAnyOrder(
						PosixFilePermission.OWNER_READ,
						PosixFilePermission.OWNER_WRITE,
						PosixFilePermission.OWNER_EXECUTE);
		assertThat(Files.getPosixFilePermissions(database))
				.containsExactlyInAnyOrder(PosixFilePermission.OWNER_READ, PosixFilePermission.OWNER_WRITE);
		assertThat(Files.getPosixFilePermissions(Path.of(database + "-wal")))
				.containsExactlyInAnyOrder(PosixFilePermission.OWNER_READ, PosixFilePermission.OWNER_WRITE);
	}
}
