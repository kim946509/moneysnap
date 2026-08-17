package com.ansandy.moneysnap.media;

import java.time.Clock;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@Configuration(proxyBeanMethods = false)
@EnableScheduling
class MediaConfiguration {

    @Bean
    ObjectStore objectStore(
            @Value("${moneysnap.r2.enabled:false}") boolean enabled,
            @Value("${moneysnap.r2.endpoint:}") String endpoint,
            @Value("${moneysnap.r2.bucket:}") String bucket,
            @Value("${moneysnap.r2.access-key-id:}") String accessKey,
            @Value("${moneysnap.r2.secret-access-key:}") String secret) {
        return selectStore(enabled, endpoint, bucket, accessKey, secret);
    }

    static ObjectStore selectStore(
            boolean enabled,
            String endpoint,
            String bucket,
            String accessKey,
            String secret) {
        if (!enabled) {
            return new MemoryObjectStore();
        }
        if (isBlank(endpoint) || isBlank(bucket) || isBlank(accessKey) || isBlank(secret)) {
            throw new IllegalStateException("R2 is enabled but endpoint, bucket, or credentials are blank");
        }
        return R2ObjectStore.connect(endpoint, bucket, accessKey, secret);
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    @Bean
    MediaVault mediaVault(DataSource dataSource, Clock identityClock, ObjectStore objectStore) {
        return new MediaVault(
                JdbcClient.create(dataSource),
                new TransactionTemplate(new DataSourceTransactionManager(dataSource)),
                identityClock,
                objectStore);
    }

    @Bean
    MediaCleanup mediaCleanup(DataSource dataSource, Clock identityClock, ObjectStore objectStore) {
        return new MediaCleanup(
                JdbcClient.create(dataSource),
                identityClock,
                objectStore);
    }
}
