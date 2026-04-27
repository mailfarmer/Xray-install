# Xray-install

English | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

A minimal Bash installer for Xray on Linux systems using systemd.

This fork keeps only two actions:

- `install`
- `uninstall`

It installs Xray as a dedicated `xray:xray` system user, starts Xray with `-confdir`, and downloads `geoip.dat` / `geosite.dat` from `Loyalsoldier/v2ray-rules-dat`.

## Installed Paths

```text
/etc/systemd/system/xray.service
/usr/local/bin/xray
/usr/local/etc/xray/*.json
/usr/local/share/xray/geoip.dat
/usr/local/share/xray/geosite.dat
/var/log/xray/access.log
/var/log/xray/error.log
```

## Behavior

- The service runs as `xray:xray`
- The service starts with `xray run -confdir /usr/local/etc/xray`
- If `/usr/local/etc/xray` contains no `.json` file, the installer creates `00-default.json`
- `geoip.dat` and `geosite.dat` are downloaded from:
  - `https://github.com/Loyalsoldier/v2ray-rules-dat`
- Downloaded geodata is verified with upstream `.sha256sum`
- Permissions are tightened for config and log files

## Usage

Install:

```bash
sudo ./install-release.sh install
```

Uninstall:

```bash
sudo ./install-release.sh uninstall
```

Help:

```bash
./install-release.sh --help
```

## Caddy

This fork also provides a one-click Caddy installer:

```bash
sudo ./install-caddy.sh install
sudo ./install-caddy.sh uninstall
```

Behavior:

- Runs as dedicated `caddy:caddy`
- Uses JSON config at `/usr/local/etc/caddy/config.json`
- Starts with `caddy run --config /usr/local/etc/caddy/config.json --adapter json`
- Uses hardened systemd sandbox settings and only keeps `CAP_NET_BIND_SERVICE`
- Stores runtime data in `/var/lib/caddy`

Binary source order:

1. `CADDY_BINARY_URL`
2. This repository `latest` release asset, such as `caddy-linux-amd64.tar.gz`
3. The versioned release asset defined by `CADDY_VERSION`
4. `https://github.com/lxhao61/integrated-examples` latest release

## Build Caddy With GitHub Actions

Yes. Caddy can be built automatically with GitHub Actions in:

`/.github/workflows/build-caddy.yml`

Behavior:

- `workflow_dispatch`: build artifacts for manual runs, defaulting to the latest Caddy release tag
- `push tag v*`: build and refresh the fixed `latest` release assets
- The workflow only builds Linux `amd64` and `arm64`

Release output:

- The workflow publishes binaries to the repository release tag `latest`
- After each run, download from `Releases -> latest`

Included plugins:

- `github.com/caddyserver/forwardproxy`
- `github.com/imgk/caddy-trojan`
- `github.com/mholt/caddy-webdav`
- `github.com/WeidiDeng/caddy-cloudflare-ip`
- `github.com/xcaddyplugins/caddy-trusted-cloudfront`
- `github.com/caddy-dns/cloudflare`
- `github.com/caddy-dns/duckdns`
- `github.com/caddy-dns/tencentcloud`
- `github.com/mholt/caddy-events-exec`
- `github.com/mholt/caddy-l4`
- `github.com/caddyserver/jsonc-adapter`

Example:

```bash
git tag v2.11.2
git push origin v2.11.2
```
