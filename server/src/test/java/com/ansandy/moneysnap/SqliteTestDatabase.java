package com.ansandy.moneysnap;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

import javax.sql.DataSource;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.context.DynamicPropertyRegistry;

public final class SqliteTestDatabase {

	private static final String[] TABLES = {
			"media_cleanup_tombstones",
			"snap_share_mutations",
			"snap_shares",
			"media_objects",
			"snap_delete_mutations",
			"snap_revise_mutations",
			"snap_record_mutations",
			"snaps",
			"group_join_mutations",
			"group_invites",
			"group_delete_mutations",
			"group_create_mutations",
			"group_memberships",
			"spend_groups",
			"apple_account_event_receipts",
			"identity_refresh_tokens",
			"identity_sessions",
			"apple_identities",
			"users"
	};

	private SqliteTestDatabase() {
	}

	public static String fileUrl() {
		try {
			Path file = Files.createTempFile("moneysnap-", ".db");
			file.toFile().deleteOnExit();
			return "jdbc:sqlite:file:" + file.toAbsolutePath().toString().replace('\\', '/')
					+ "?foreign_keys=on&journal_mode=WAL&busy_timeout=5000";
		}
		catch (IOException exception) {
			throw new IllegalStateException("Unable to create SQLite test database", exception);
		}
	}

	public static void register(DynamicPropertyRegistry registry) {
		String url = fileUrl();
		registry.add("spring.datasource.url", () -> url);
		registry.add("spring.datasource.driver-class-name", () -> "org.sqlite.JDBC");
		registry.add("spring.datasource.hikari.maximum-pool-size", () -> "4");
	}

	public static DataSource dataSource(String url) {
		DriverManagerDataSource dataSource = new DriverManagerDataSource();
		dataSource.setDriverClassName("org.sqlite.JDBC");
		dataSource.setUrl(url);
		return dataSource;
	}

	public static void clear(JdbcClient jdbc) {
		jdbc.sql("PRAGMA foreign_keys = OFF").update();
		for (String table : TABLES) {
			jdbc.sql("DELETE FROM " + table).update();
		}
		jdbc.sql("PRAGMA foreign_keys = ON").update();
	}
}
