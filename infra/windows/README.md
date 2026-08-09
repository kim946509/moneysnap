# Windows Spring Boot origin

폐쇄형 development origin은 개발자 소유 Windows에서 실행한다. GitHub Actions의 전용 self-hosted runner는 검증된 JAR을 이 host의 loopback Spring Boot process에만 배포한다.

## 디렉터리 계약

기본 root는 `C:\ProgramData\MoneySnap\server`다.

```text
bin/run-server.ps1
bin/java-path.txt
current/moneysnap-server.jar
releases/<git-sha>/moneysnap-server.jar
releases/<git-sha>/run-server.ps1
secrets/NEON_*
state/current-release.txt
state/previous-release.txt
logs/server.log
```

`secrets/` ACL은 LocalSystem, Administrators와 실제 deployment runner identity만 허용한다. secret 값은 command line, workflow artifact, repository, deployment output에 넣지 않는다.

## 최초 준비

1. Java/OpenJDK 21 executable을 준비한다. bootstrap은 확인한 절대 경로를 `bin/java-path.txt`에 고정하므로 LocalSystem task가 runner 계정과 다른 `PATH`를 사용해도 같은 Java를 실행한다.
2. GitHub repository Settings → Actions → Runners에서 Windows x64 runner를 이 repository 전용으로 등록한다.
3. runner에 기본 label 외 `moneysnap-dev`를 추가한다. registration token과 runner credential은 저장소에 기록하지 않는다.
4. runner service가 deployment directory와 Scheduled Task를 관리할 수 있는 전용 Windows identity로 실행되는지 확인한다.
5. elevated PowerShell에서 실행한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\windows\install-server-host.ps1
```

`PATH` 밖의 Java를 사용할 때는 절대 경로를 명시한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\infra\windows\install-server-host.ps1 -JavaPath 'C:\Program Files\Eclipse Adoptium\jdk-21\bin\java.exe'
```

이 명령은 `MoneySnapServer` Scheduled Task만 등록하며 JAR이나 secret이 없는 상태에서 task를 시작하지 않는다. 첫 `main` deployment가 canonical JAR과 secret files를 설치한 뒤 task를 시작한다.

checksum·ACL·이전 JAR/runner/secret 복원은 GitHub Actions의 Windows job과 아래 로컬 명령으로 검증한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\server\scripts\test-deployment-support.ps1
```

## GitHub environment

`server-development` environment에 `docs/CI_CD.md`의 Neon secret 여섯 개를 등록한다. 값은 `infra/neon/.env.development.local`의 development 연결만 사용하며 production project 값을 dev environment에 복사하지 않는다.

현재 private 무료 repository에서는 required reviewer를 보안 경계로 가정하지 않는다. production secret, production runner, public deployment는 별도 승인 전 추가하지 않는다.

## 운영 확인

```powershell
Get-ScheduledTask -TaskName MoneySnapServer
Invoke-RestMethod http://127.0.0.1:8080/actuator/health
Get-Content C:\ProgramData\MoneySnap\server\state\current-release.txt
```

외부 Tunnel은 이 task와 별도 `cloudflared` Windows service로 실행한다. application rollback이 tunnel을 재시작하거나 token을 읽지 않게 한다.
