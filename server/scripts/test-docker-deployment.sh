#!/usr/bin/env bash
set -Eeuo pipefail

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

fake_docker="$test_root/docker"
docker_log="$test_root/docker.log"
cat > "$fake_docker" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s image=%s\n' "$*" "${MONEYSNAP_IMAGE:-}" >> "$DOCKER_LOG"
case "${1:-}" in
  network)
    exit 0
    ;;
  load)
    cat >/dev/null
    exit 0
    ;;
  inspect)
    printf '%s\n' 'moneysnap-server:previous'
    exit 0
    ;;
  compose)
    if [[ "${FAIL_NEW_IMAGE:-0}" == 1 && "${MONEYSNAP_IMAGE:-}" == "moneysnap-server:new" ]]; then
      exit 1
    fi
    exit 0
    ;;
esac
exit 0
EOF
chmod +x "$fake_docker"

make_fixture() {
  local fixture=$1
  mkdir -p "$fixture"
  printf 'image-archive' | gzip > "$fixture/image.tar.gz"
  (cd "$fixture" && sha256sum image.tar.gz > image.tar.gz.sha256)
  printf 'services: {}\n' > "$fixture/compose.yaml"
  printf 'NEON_RUNTIME_DATABASE_URL=jdbc:postgresql://example.invalid/db\n' > "$fixture/runtime.env"
}

healthy_fixture="$test_root/healthy"
make_fixture "$healthy_fixture"
DOCKER_LOG="$docker_log" \
DOCKER_BIN="$fake_docker" \
MONEYSNAP_INSTALL_ROOT="$healthy_fixture/install" \
  bash infra/ubuntu/deploy.sh \
    "$healthy_fixture/image.tar.gz" \
    "$healthy_fixture/image.tar.gz.sha256" \
    "$healthy_fixture/compose.yaml" \
    "$healthy_fixture/runtime.env" \
    moneysnap-server:new \
    healthy-release

[[ $(cat "$healthy_fixture/install/current-release") == healthy-release ]]
grep -q 'compose .* image=moneysnap-server:new' "$docker_log"
echo 'healthy deployment: OK'

rollback_fixture="$test_root/rollback"
make_fixture "$rollback_fixture"
mkdir -p "$rollback_fixture/install"
printf 'services: previous\n' > "$rollback_fixture/install/compose.yaml"
printf 'PREVIOUS_SECRET=preserved\n' > "$rollback_fixture/install/.env"
printf 'previous-release\n' > "$rollback_fixture/install/current-release"
if DOCKER_LOG="$docker_log" \
   DOCKER_BIN="$fake_docker" \
   FAIL_NEW_IMAGE=1 \
   MONEYSNAP_INSTALL_ROOT="$rollback_fixture/install" \
     bash infra/ubuntu/deploy.sh \
       "$rollback_fixture/image.tar.gz" \
       "$rollback_fixture/image.tar.gz.sha256" \
       "$rollback_fixture/compose.yaml" \
       "$rollback_fixture/runtime.env" \
       moneysnap-server:new \
       failed-release; then
  echo 'failed deployment unexpectedly succeeded' >&2
  exit 1
fi

grep -q 'compose .* image=moneysnap-server:previous' "$docker_log"
grep -q 'services: previous' "$rollback_fixture/install/compose.yaml"
grep -q 'PREVIOUS_SECRET=preserved' "$rollback_fixture/install/.env"
[[ $(cat "$rollback_fixture/install/current-release") == previous-release ]]
echo 'rollback after failed health gate: OK'
