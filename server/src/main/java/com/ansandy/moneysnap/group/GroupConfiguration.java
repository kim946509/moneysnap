package com.ansandy.moneysnap.group;

import java.time.Clock;

import javax.sql.DataSource;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@Configuration(proxyBeanMethods = false)
class GroupConfiguration {

    @Bean
    GroupSharing groupSharing(DataSource dataSource, Clock identityClock) {
        return new GroupSharing(
                JdbcClient.create(dataSource),
                new TransactionTemplate(new DataSourceTransactionManager(dataSource)),
                identityClock);
    }
}
