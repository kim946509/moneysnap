#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 6 ]]; then
  echo "usage: deploy.sh <image.tar.gz> <sha256> <compose.yaml> <runtime.env> <image> <release>" >&2
  exit 64
fi

image_archive=$1
checksum_file=$2
compose_source=$3
runtime_env_source=$4
image=$5
release=$6

install_root=${MONEYSNAP_INSTALL_ROOT:-/opt/moneysnap}
docker_bin=${DOCKER_BIN:-docker}
compose_file="$install_root/compose.yaml"
runtime_env_file="$install_root/runtime.env"
compose_interpolation_env="$install_root/.env"
state_file="$install_root/current-release"
backup_dir=$(mktemp -d)
trap 'rm -rf "$backup_dir"' EXIT

for source_file in "$image_archive" "$checksum_file" "$compose_source" "$runtime_env_source"; do
  if [[ ! -f "$source_file" ]]; then
    echo "required deployment input is missing: $source_file" >&2
    exit 66
  fi
done

archive_dir=$(cd "$(dirname "$image_archive")" && pwd)
archive_name=$(basename "$image_archive")
checksum_name=$(basename "$checksum_file")
(
  cd "$archive_dir"
  sha256sum --check "$checksum_name"
)

if ! "$docker_bin" network inspect main >/dev/null 2>&1; then
  echo "required external Docker network does not exist: main" >&2
  exit 69
fi

previous_image=$($docker_bin inspect --format '{{.Config.Image}}' moneysnap-server 2>/dev/null || true)
had_previous_compose=false
had_previous_env=false

install -d -m 700 "$install_root"
if [[ -f "$compose_file" ]]; then
  install -m 644 "$compose_file" "$backup_dir/compose.yaml"
  had_previous_compose=true
fi
if [[ -f "$runtime_env_file" ]]; then
  install -m 600 "$runtime_env_file" "$backup_dir/runtime.env"
  had_previous_env=true
elif [[ -f "$compose_interpolation_env" ]]; then
  install -m 600 "$compose_interpolation_env" "$backup_dir/runtime.env"
  had_previous_env=true
fi

install -m 600 "$runtime_env_source" "$runtime_env_file"
install -m 644 "$compose_source" "$compose_file"
printf '# compose interpolation only; runtime secrets stay in runtime.env\n' > "$compose_interpolation_env"
chmod 600 "$compose_interpolation_env"
gzip --decompress --stdout "$archive_dir/$archive_name" | "$docker_bin" load >/dev/null

data_dir=${MONEYSNAP_DATA_DIR:-$install_root/data}
install -d -m 700 "$data_dir"
if [[ "$(id -u)" -eq 0 ]]; then
  chown 21000:21000 "$data_dir"
  chmod 700 "$data_dir"
  for sqlite_file in "$data_dir"/moneysnap.db "$data_dir"/moneysnap.db-wal "$data_dir"/moneysnap.db-shm; do
    if [[ -e "$sqlite_file" ]]; then
      chown 21000:21000 "$sqlite_file"
      chmod 600 "$sqlite_file"
    fi
  done
else
  chmod 700 "$data_dir" || true
fi

deploy_image() {
  local candidate_image=$1
  MONEYSNAP_IMAGE="$candidate_image" \
  MONEYSNAP_ENV_FILE="$runtime_env_file" \
    "$docker_bin" compose \
      --project-name moneysnap \
      --project-directory "$install_root" \
      --file "$compose_file" \
      --env-file "$compose_interpolation_env" \
      up --detach --force-recreate --wait --wait-timeout 180
}

if ! deploy_image "$image"; then
  echo "new release failed its health gate: $release" >&2
  "$docker_bin" logs --tail 80 moneysnap-server >&2 || true
  if [[ -n "$previous_image" ]]; then
    echo "rolling back to previous image; keeping parseable runtime.env" >&2
    if [[ "$had_previous_compose" == true ]]; then
      install -m 644 "$backup_dir/compose.yaml" "$compose_file"
    else
      rm -f "$compose_file"
    fi
    printf '# compose interpolation only; runtime secrets stay in runtime.env\n' > "$compose_interpolation_env"
    chmod 600 "$compose_interpolation_env"
    deploy_image "$previous_image"
  fi
  exit 1
fi

printf '%s\n' "$release" > "$state_file"
chmod 600 "$state_file"
printf 'deployed %s as %s\n' "$release" "$image"
