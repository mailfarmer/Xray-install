#!/usr/bin/env bash

set -euo pipefail

DAT_PATH=${DAT_PATH:-/usr/local/share/xray}
JSON_PATH=${JSON_PATH:-/usr/local/etc/xray}
BIN_PATH='/usr/local/bin/xray'
SERVICE_PATH='/etc/systemd/system/xray.service'
LOG_DIR='/var/log/xray'
XRAY_USER='xray'
XRAY_GROUP='xray'

TMP_DIR=''
ARCH=''
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

detect_arch() {
  case "$(uname -m)" in
    i386|i686)
      ARCH='32'
      ;;
    x86_64|amd64)
      ARCH='64'
      ;;
    armv5tel)
      ARCH='arm32-v5'
      ;;
    armv6l)
      ARCH='arm32-v6'
      grep -q 'vfp' /proc/cpuinfo || ARCH='arm32-v5'
      ;;
    armv7l|armv7)
      ARCH='arm32-v7a'
      grep -q 'vfp' /proc/cpuinfo || ARCH='arm32-v5'
      ;;
    aarch64|armv8)
      ARCH='arm64-v8a'
      ;;
    mips)
      ARCH='mips32'
      ;;
    mipsle)
      ARCH='mips32le'
      ;;
    mips64)
      ARCH='mips64'
      lscpu | grep -q 'Little Endian' && ARCH='mips64le'
      ;;
    mips64le)
      ARCH='mips64le'
      ;;
    ppc64)
      ARCH='ppc64'
      ;;
    ppc64le)
      ARCH='ppc64le'
      ;;
    riscv64)
      ARCH='riscv64'
      ;;
    s390x)
      ARCH='s390x'
      ;;
    *)
      die "不支持的架构: $(uname -m)"
      ;;
  esac
}

detect_package_manager() {
  if command -v apt >/dev/null 2>&1; then
    PKG_INSTALL='apt-get update && apt-get install -y --no-install-recommends curl unzip ca-certificates'
  elif command -v dnf >/dev/null 2>&1; then
    PKG_INSTALL='dnf install -y curl unzip ca-certificates'
  elif command -v yum >/dev/null 2>&1; then
    PKG_INSTALL='yum install -y curl unzip ca-certificates'
  elif command -v zypper >/dev/null 2>&1; then
    PKG_INSTALL='zypper install -y --no-recommends curl unzip ca-certificates'
  elif command -v pacman >/dev/null 2>&1; then
    PKG_INSTALL='pacman -Sy --noconfirm curl unzip ca-certificates'
  else
    die '未识别的包管理器，无法自动安装依赖。'
  fi
}

install_dependencies() {
  if command -v curl >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
    return 0
  fi

  detect_package_manager
  msg 'info: 正在安装依赖 curl / unzip / ca-certificates'
  eval "${PKG_INSTALL}"
}

create_xray_user() {
  if ! getent group "${XRAY_GROUP}" >/dev/null 2>&1; then
    groupadd --system "${XRAY_GROUP}"
  fi

  if ! id -u "${XRAY_USER}" >/dev/null 2>&1; then
    useradd \
      --system \
      --gid "${XRAY_GROUP}" \
      --home-dir /nonexistent \
      --no-create-home \
      --shell /usr/sbin/nologin \
      --comment 'Xray service user' \
      "${XRAY_USER}" 2>/dev/null || useradd \
      --system \
      --gid "${XRAY_GROUP}" \
      --home /nonexistent \
      --no-create-home \
      --shell /sbin/nologin \
      --comment 'Xray service user' \
      "${XRAY_USER}"
  fi
}

download_file() {
  local url="$1"
  local output="$2"

  curl -fL --retry 5 --retry-delay 3 --retry-connrefused -o "${output}" "${url}"
}

download_geodata() {
  local name="$1"
  local url="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/${name}"
  local sum_url="${url}.sha256sum"

  download_file "${url}" "${TMP_DIR}/${name}"
  download_file "${sum_url}" "${TMP_DIR}/${name}.sha256sum"
  (
    cd "${TMP_DIR}"
    sha256sum -c "${name}.sha256sum"
  )
}

stop_service_if_exists() {
  if systemctl list-unit-files | grep -q '^xray\.service'; then
    systemctl stop xray.service 2>/dev/null || true
    systemctl disable xray.service 2>/dev/null || true
  fi
}

write_default_config_if_missing() {
  if ! find "${JSON_PATH}" -maxdepth 1 -type f -name '*.json' | grep -q .; then
    cat >"${JSON_PATH}/00-default.json" <<'EOF'
{}
EOF
    chown root:"${XRAY_GROUP}" "${JSON_PATH}/00-default.json"
    chmod 640 "${JSON_PATH}/00-default.json"
    msg "info: 已创建默认配置 ${JSON_PATH}/00-default.json"
  fi
}

install_files() {
  install -d -m 755 -o root -g root /usr/local/bin
  install -d -m 755 -o root -g root "${DAT_PATH}"
  install -d -m 750 -o root -g "${XRAY_GROUP}" "${JSON_PATH}"
  install -d -m 750 -o "${XRAY_USER}" -g "${XRAY_GROUP}" "${LOG_DIR}"

  install -m 755 -o root -g root "${TMP_DIR}/xray" "${BIN_PATH}"
  install -m 644 -o root -g root "${TMP_DIR}/geoip.dat" "${DAT_PATH}/geoip.dat"
  install -m 644 -o root -g root "${TMP_DIR}/geosite.dat" "${DAT_PATH}/geosite.dat"

  install -m 640 -o "${XRAY_USER}" -g "${XRAY_GROUP}" /dev/null "${LOG_DIR}/access.log"
  install -m 640 -o "${XRAY_USER}" -g "${XRAY_GROUP}" /dev/null "${LOG_DIR}/error.log"

  write_default_config_if_missing
  chown root:"${XRAY_GROUP}" "${JSON_PATH}"
  chmod 750 "${JSON_PATH}"
  find "${JSON_PATH}" -maxdepth 1 -type f -exec chown root:"${XRAY_GROUP}" {} +
  find "${JSON_PATH}" -maxdepth 1 -type f -exec chmod 640 {} +
}

write_service() {
  cat >"${SERVICE_PATH}" <<EOF
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
After=network-online.target nss-lookup.target
Wants=network-online.target

[Service]
User=${XRAY_USER}
Group=${XRAY_GROUP}
Type=simple
ExecStart=${BIN_PATH} run -confdir ${JSON_PATH}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5s
RestartPreventExitStatus=23
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
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
ReadWritePaths=${LOG_DIR}
RuntimeDirectory=xray
RuntimeDirectoryMode=0750
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  chmod 644 "${SERVICE_PATH}"
}

install_xray() {
  require_root
  [[ "$(uname)" == 'Linux' ]] || die '仅支持 Linux。'
  [[ -d /run/systemd/system ]] || die '仅支持使用 systemd 的系统。'

  detect_arch
  install_dependencies
  create_xray_user

  TMP_DIR="$(mktemp -d)"
  local zip_file="${TMP_DIR}/xray.zip"

  msg "info: 正在下载 Xray 最新版本，架构 ${ARCH}"
  download_file "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${ARCH}.zip" "${zip_file}"
  unzip -q "${zip_file}" -d "${TMP_DIR}"

  msg 'info: 正在下载并校验 geoip.dat / geosite.dat'
  download_geodata 'geoip.dat'
  download_geodata 'geosite.dat'

  stop_service_if_exists
  install_files
  write_service

  systemctl daemon-reload
  systemctl enable --now xray.service

  if systemctl is-active --quiet xray.service; then
    msg "info: Xray 安装完成，当前版本: $(${BIN_PATH} version | head -n 1)"
  else
    die 'Xray 服务启动失败，请检查配置文件。'
  fi
}

remove_xray() {
  require_root

  if systemctl list-unit-files | grep -q '^xray\.service'; then
    systemctl stop xray.service 2>/dev/null || true
    systemctl disable xray.service 2>/dev/null || true
  fi

  rm -f "${SERVICE_PATH}"
  systemctl daemon-reload

  rm -f "${BIN_PATH}"
  rm -rf "${DAT_PATH}"
  rm -rf "${JSON_PATH}"
  rm -rf "${LOG_DIR}"

  if id -u "${XRAY_USER}" >/dev/null 2>&1; then
    userdel "${XRAY_USER}" 2>/dev/null || true
  fi
  if getent group "${XRAY_GROUP}" >/dev/null 2>&1; then
    groupdel "${XRAY_GROUP}" 2>/dev/null || true
  fi

  msg 'info: Xray 已卸载。'
}

show_help() {
  cat <<'EOF'
用法:
  ./install-release.sh install
  ./install-release.sh uninstall

参数:
  install      安装或覆盖安装最新版 Xray，并下载 Loyalsoldier geodata
  uninstall    卸载 Xray、配置、数据文件、日志以及 systemd 服务
EOF
}

main() {
  local action="${1:-}"

  case "${action}" in
    install)
      [[ $# -eq 1 ]] || die 'install 不接受额外参数。'
      install_xray
      ;;
    uninstall)
      [[ $# -eq 1 ]] || die 'uninstall 不接受额外参数。'
      remove_xray
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
