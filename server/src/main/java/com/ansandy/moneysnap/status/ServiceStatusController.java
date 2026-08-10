package com.ansandy.moneysnap.status;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
class ServiceStatusController {

	@GetMapping("/")
	ServiceStatus status() {
		return new ServiceStatus("moneysnap-api", "UP");
	}

	private record ServiceStatus(String service, String status) {
	}
}
