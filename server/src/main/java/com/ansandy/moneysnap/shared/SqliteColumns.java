package com.ansandy.moneysnap.shared;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.DateTimeException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

public final class SqliteColumns {

	private SqliteColumns() {
	}

	public static UUID uuid(ResultSet row, String column) throws SQLException {
		return parseUuid(row.getString(column));
	}

	public static UUID uuid(ResultSet row, int index) throws SQLException {
		return parseUuid(row.getString(index));
	}

	public static UUID firstUuid(ResultSet row, int rowNumber) throws SQLException {
		return uuid(row, 1);
	}

	public static String instant(Instant value) {
		return value == null ? null : value.truncatedTo(ChronoUnit.MICROS).toString();
	}

	public static Instant instant(ResultSet row, String column) throws SQLException {
		String value = row.getString(column);
		if (value == null || value.isBlank()) {
			return null;
		}
		if (value.chars().allMatch(Character::isDigit)) {
			long number = Long.parseLong(value);
			return number > 10_000_000_000L ? Instant.ofEpochMilli(number) : Instant.ofEpochSecond(number);
		}
		try {
			return Instant.parse(value);
		}
		catch (DateTimeException ignored) {
			try {
				String normalized = value.replace(' ', 'T');
				if (!normalized.endsWith("Z") && !normalized.contains("+")) {
					normalized = normalized + "Z";
				}
				return Instant.parse(normalized);
			}
			catch (DateTimeException ignoredAgain) {
				return Timestamp.valueOf(value).toInstant();
			}
		}
	}

	public static LocalDate localDate(ResultSet row, String column) throws SQLException {
		String value = row.getString(column);
		if (value == null || value.isBlank()) {
			return null;
		}
		if (value.chars().allMatch(Character::isDigit)) {
			return instant(row, column).atZone(java.time.ZoneOffset.UTC).toLocalDate();
		}
		if (value.length() > 10) {
			return LocalDate.parse(value.substring(0, 10));
		}
		return LocalDate.parse(value);
	}

	private static UUID parseUuid(String value) {
		if (value == null || value.isBlank()) {
			return null;
		}
		return UUID.fromString(value);
	}
}
