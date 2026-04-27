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
