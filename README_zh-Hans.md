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
