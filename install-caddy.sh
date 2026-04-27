#!/usr/bin/env bash

set -euo pipefail

CADDY_VERSION="${CADDY_VERSION:-v2.11.2}"
CADDY_REPO="${CADDY_REPO:-mailfarmer/Xray-install}"
CADDY_CONFIG_DIR="${CADDY_CONFIG_DIR:-/usr/local/etc/caddy}"
CADDY_CONFIG_FILE="${CADDY_CONFIG_FILE:-${CADDY_CONFIG_DIR}/config.json}"
CADDY_BIN_PATH="${CADDY_BIN_PATH:-/usr/local/bin/caddy}"
CADDY_SERVICE_PATH="${CADDY_SERVICE_PATH:-/etc/systemd/system/caddy.service}"
CADDY_DATA_DIR="${CADDY_DATA_DIR:-/var/lib/caddy}"
CADDY_USER='caddy'
CADDY_GROUP='caddy'

TMP_DIR=''
OS=''
ARCH=''
ARCH_LABEL=''
PKG_INSTALL=''

cleanup() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}

trap cleanup EXIT

msg() {
  printf '%s\n' "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die '必须以 root 运行此脚本。'
}

detect_platform() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  [[ "${OS}" == 'linux' ]] || die '仅支持 Linux。'

  case "$(uname -m)" in
    x86_64|amd64)
      ARCH='amd64'
      ARCH_LABEL='linux-amd64'
      ;;
    aarch64|arm64)
      ARCH='arm64'
      ARCH_LABEL='linux-arm64'
      ;;
    armv5tel|armv5*)
      ARCH='arm'
      ARCH_LABEL='linux-armv5'
      export GOARM=5
      ;;
    s390x)
      ARCH='s390x'
      ARCH_LABEL='linux-s390x'
      ;;
    i386|i686)
      ARCH='386'
      ARCH_LABEL='linux-386'
      ;;
    *)
      die "不支持的架构: $(uname -m)"
      ;;
  esac
}

detect_package_manager() {
  if command -v apt >/dev/null 2>&1; then
    PKG_INSTALL='apt-get update && apt-get install -y --no-install-recommends curl tar ca-certificates libcap2-bin'
  elif command -v dnf >/dev/null 2>&1; then
    PKG_INSTALL='dnf install -y curl tar ca-certificates libcap'
  elif command -v yum >/dev/null 2>&1; then
    PKG_INSTALL='yum install -y curl tar ca-certificates libcap'
  elif command -v zypper >/dev/null 2>&1; then
    PKG_INSTALL='zypper install -y --no-recommends curl tar ca-certificates libcap-progs'
  elif command -v pacman >/dev/null 2>&1; then
    PKG_INSTALL='pacman -Sy --noconfirm curl tar ca-certificates libcap'
  else
    die '未识别的包管理器，无法自动安装依赖。'
  fi
}

install_dependencies() {
  if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    return 0
  fi

  detect_package_manager
  msg 'info: 正在安装依赖 curl / tar / ca-certificates / libcap'
  eval "${PKG_INSTALL}"
}

create_caddy_user() {
  if ! getent group "${CADDY_GROUP}" >/dev/null 2>&1; then
    groupadd --system "${CADDY_GROUP}"
  fi

  if ! id -u "${CADDY_USER}" >/dev/null 2>&1; then
    useradd \
      --system \
      --gid "${CADDY_GROUP}" \
      --home-dir /nonexistent \
      --no-create-home \
      --shell /usr/sbin/nologin \
      --comment 'Caddy service user' \
      "${CADDY_USER}" 2>/dev/null || useradd \
      --system \
      --gid "${CADDY_GROUP}" \
      --home /nonexistent \
      --no-create-home \
      --shell /sbin/nologin \
      --comment 'Caddy service user' \
      "${CADDY_USER}"
  fi
}

download_file() {
  local url="$1"
  local output="$2"

  curl -fsSL --retry 5 --retry-delay 3 --retry-connrefused -o "${output}" "${url}"
}

download_caddy_archive() {
  local urls=(
    "${CADDY_BINARY_URL:-}"
    "https://github.com/${CADDY_REPO}/releases/download/${CADDY_VERSION}/caddy-${ARCH_LABEL}.tar.gz"
    "https://github.com/lxhao61/integrated-examples/releases/latest/download/caddy-${ARCH_LABEL}.tar.gz"
  )
  local url
  local archive="${TMP_DIR}/caddy.tar.gz"

  for url in "${urls[@]}"; do
    [[ -n "${url}" ]] || continue
    if curl -fsSLI "${url}" >/dev/null 2>&1; then
      printf 'info: 使用二进制来源 %s\n' "${url}" >&2
      download_file "${url}" "${archive}"
      printf '%s\n' "${archive}"
      return 0
    fi
  done

  die '无法获取 Caddy 二进制。可设置 CADDY_BINARY_URL 指向你自己的构建产物。'
}

write_default_config_if_missing() {
  if [[ ! -f "${CADDY_CONFIG_FILE}" ]]; then
    cat >"${CADDY_CONFIG_FILE}" <<'EOF'
{
  "admin": {
    "disabled": true
  },
  "storage": {
    "module": "file_system",
    "root": "/var/lib/caddy"
  },
  "apps": {
    "http": {
      "servers": {
        "srv0": {
          "listen": [
            ":80"
          ],
          "routes": [
            {
              "handle": [
                {
                  "handler": "static_response",
                  "status_code": 200,
                  "body": "caddy is running\n"
                }
              ]
            }
          ]
        }
      }
    }
  }
}
EOF
    chown root:"${CADDY_GROUP}" "${CADDY_CONFIG_FILE}"
    chmod 640 "${CADDY_CONFIG_FILE}"
    msg "info: 已创建默认配置 ${CADDY_CONFIG_FILE}"
  fi
}

install_files() {
  install -d -m 755 -o root -g root /usr/local/bin
  install -d -m 750 -o root -g "${CADDY_GROUP}" "${CADDY_CONFIG_DIR}"
  install -d -m 700 -o "${CADDY_USER}" -g "${CADDY_GROUP}" "${CADDY_DATA_DIR}"

  install -m 755 -o root -g root "${TMP_DIR}/caddy" "${CADDY_BIN_PATH}"
  write_default_config_if_missing
  find "${CADDY_CONFIG_DIR}" -maxdepth 1 -type f -name '*.json' -exec chown root:"${CADDY_GROUP}" {} +
  find "${CADDY_CONFIG_DIR}" -maxdepth 1 -type f -name '*.json' -exec chmod 640 {} +
}

write_service() {
  cat >"${CADDY_SERVICE_PATH}" <<EOF
[Unit]
Description=Caddy Service
Documentation=https://caddyserver.com/docs/
After=network-online.target
Wants=network-online.target

[Service]
User=${CADDY_USER}
Group=${CADDY_GROUP}
Type=simple
ExecStart=${CADDY_BIN_PATH} run --config ${CADDY_CONFIG_FILE} --adapter json
ExecStartPre=${CADDY_BIN_PATH} validate --config ${CADDY_CONFIG_FILE} --adapter json
Restart=on-failure
RestartSec=5s
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectSystem=strict
ProtectHome=true
ProtectControlGroups=true
ProtectKernelModules=true
ProtectKernelTunables=true
LockPersonality=true
MemoryDenyWriteExecute=true
RestrictSUIDSGID=true
RestrictRealtime=true
SystemCallArchitectures=native
UMask=0077
ReadWritePaths=${CADDY_DATA_DIR}
StateDirectory=caddy
StateDirectoryMode=0700
RuntimeDirectory=caddy
RuntimeDirectoryMode=0750

[Install]
WantedBy=multi-user.target
EOF

  chmod 644 "${CADDY_SERVICE_PATH}"
}

stop_service_if_exists() {
  if systemctl list-unit-files | grep -q '^caddy\.service'; then
    systemctl stop caddy.service 2>/dev/null || true
    systemctl disable caddy.service 2>/dev/null || true
  fi
}

install_caddy() {
  require_root
  [[ -d /run/systemd/system ]] || die '仅支持使用 systemd 的系统。'

  detect_platform
  install_dependencies
  create_caddy_user

  TMP_DIR="$(mktemp -d)"
  local archive
  archive="$(download_caddy_archive)"
  tar -xzf "${archive}" -C "${TMP_DIR}"
  [[ -f "${TMP_DIR}/caddy" ]] || die '解压后未找到 caddy 二进制。'

  stop_service_if_exists
  install_files
  write_service

  "${CADDY_BIN_PATH}" validate --config "${CADDY_CONFIG_FILE}" --adapter json
  systemctl daemon-reload
  systemctl enable --now caddy.service

  if systemctl is-active --quiet caddy.service; then
    msg "info: Caddy 安装完成，当前版本: $(${CADDY_BIN_PATH} version)"
  else
    die 'Caddy 服务启动失败，请检查配置。'
  fi
}

remove_caddy() {
  require_root

  if systemctl list-unit-files | grep -q '^caddy\.service'; then
    systemctl stop caddy.service 2>/dev/null || true
    systemctl disable caddy.service 2>/dev/null || true
  fi

  rm -f "${CADDY_SERVICE_PATH}"
  systemctl daemon-reload

  rm -f "${CADDY_BIN_PATH}"
  rm -rf "${CADDY_CONFIG_DIR}"
  rm -rf "${CADDY_DATA_DIR}"

  if id -u "${CADDY_USER}" >/dev/null 2>&1; then
    userdel "${CADDY_USER}" 2>/dev/null || true
  fi
  if getent group "${CADDY_GROUP}" >/dev/null 2>&1; then
    groupdel "${CADDY_GROUP}" 2>/dev/null || true
  fi

  msg 'info: Caddy 已卸载。'
}

show_help() {
  cat <<'EOF'
用法:
  ./install-caddy.sh install
  ./install-caddy.sh uninstall

环境变量:
  CADDY_VERSION     指定你自己仓库 release tag，默认 v2.11.2
  CADDY_REPO        指定仓库，默认 mailfarmer/Xray-install
  CADDY_BINARY_URL  直接指定 caddy tar.gz 下载地址

说明:
  install      安装 Caddy，配置文件为 JSON，服务使用最小权限运行
  uninstall    卸载 Caddy、配置、状态目录以及 systemd 服务
EOF
}

main() {
  local action="${1:-}"

  case "${action}" in
    install)
      [[ $# -eq 1 ]] || die 'install 不接受额外参数。'
      install_caddy
      ;;
    uninstall)
      [[ $# -eq 1 ]] || die 'uninstall 不接受额外参数。'
      remove_caddy
      ;;
    help|-h|--help|'')
      show_help
      ;;
    *)
      die "不支持的参数: ${action}"
      ;;
  esac
}

main "$@"
