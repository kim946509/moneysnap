package com.ansandy.moneysnap;

import org.springframework.boot.SpringApplication;

public class TestMoneySnapServerApplication {

	public static void main(String[] args) {
		SpringApplication.from(MoneySnapServerApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
