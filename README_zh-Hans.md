# Xray-install

[English](README.md) | 简体中文 | [繁體中文](README_zh-Hant.md)

这是一个面向 systemd Linux 系统的精简版 Xray 安装脚本。

这个 fork 只保留两个动作：

- `install`
- `uninstall`

脚本会默认使用独立的 `xray:xray` 系统用户运行 Xray，使用 `-confdir` 方式加载配置目录，并从 `Loyalsoldier/v2ray-rules-dat` 下载 `geoip.dat` 和 `geosite.dat`。

## 安装后的路径

```text
/etc/systemd/system/xray.service
/usr/local/bin/xray
/usr/local/etc/xray/*.json
/usr/local/share/xray/geoip.dat
/usr/local/share/xray/geosite.dat
/var/log/xray/access.log
/var/log/xray/error.log
```

## 行为说明

- 服务进程用户为 `xray:xray`
- 服务启动命令为 `xray run -confdir /usr/local/etc/xray`
- 如果 `/usr/local/etc/xray` 目录下没有任何 `.json` 配置文件，安装脚本会自动创建 `00-default.json`
- `geoip.dat` 和 `geosite.dat` 下载源为：
  - `https://github.com/Loyalsoldier/v2ray-rules-dat`
- geodata 下载后会校验上游提供的 `.sha256sum`
- 配置文件和日志文件权限已收紧

## 用法

安装：

```bash
sudo ./install-release.sh install
```

卸载：

```bash
sudo ./install-release.sh uninstall
```

查看帮助：

```bash
./install-release.sh --help
```

## Caddy

这个 fork 还提供了一个 Caddy 一键部署脚本：

```bash
sudo ./install-caddy.sh install
sudo ./install-caddy.sh uninstall
```

行为说明：

- 使用独立的 `caddy:caddy` 用户运行
- 使用 JSON 配置文件 `/usr/local/etc/caddy/config.json`
- 启动命令为 `caddy run --config /usr/local/etc/caddy/config.json --adapter json`
- systemd 服务做了更严格的沙箱限制，仅保留 `CAP_NET_BIND_SERVICE`
- 运行时状态目录为 `/var/lib/caddy`

二进制下载顺序：

1. 环境变量 `CADDY_BINARY_URL`
2. 当前仓库 `latest` Release 里的二进制资产，例如 `caddy-linux-amd64.tar.gz`
3. 由 `CADDY_VERSION` 指定的版本 release 资产
4. `https://github.com/lxhao61/integrated-examples` 最新 release

## GitHub Actions 自动编译 Caddy

可以，已经补了工作流：

`/.github/workflows/build-caddy.yml`

行为说明：

- `workflow_dispatch`：手动触发构建，默认使用 Caddy 最新 release tag
- `push tag v*`：自动构建并刷新固定的 `latest` Release 资产
- 工作流只构建 Linux `amd64` 和 `arm64`

产物位置：

- 工作流会把二进制发布到仓库的 `latest` Release
- 每次运行完成后，直接去 `Releases -> latest` 下载

内置插件：

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

示例：

```bash
git tag v2.11.2
git push origin v2.11.2
```
