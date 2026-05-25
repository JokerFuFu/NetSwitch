# NetSwitch

NetSwitch 是一个原生 macOS 菜单栏应用，用来在无线网络和有线网络之间快速切换。

NetSwitch 会自动识别这台 Mac 上的网络服务：

- 内建 Wi-Fi 服务
- 真实的以太网、USB 网卡或雷雳网卡服务

VPN、代理、桥接和虚拟网卡不会被推荐为有线网络目标。

默认语言为中文，默认登录 macOS 后自动启动。
应用带有单实例保护，重复打开或登录项重复触发时不会叠加多个菜单栏图标。

## 环境要求

- macOS 13 or later
- Apple Swift command line tools
- 目标网络服务需要存在于 macOS 网络设置中

## 构建

运行测试：

```sh
swift run NetSwitchParserTests
```

构建 macOS app：

```sh
./scripts/build-app.sh
```

产物位置：

```text
.build/NetSwitch.app
```

## 运行

开发时直接打开：

```sh
open .build/NetSwitch.app
```

NetSwitch 会出现在菜单栏，状态显示为「无线」「有线」「离线」或「混合」。点击菜单栏图标可以切换网络、刷新状态、打开设置或查看使用引导。

## 图文引导

菜单栏里有「使用引导」。它用图文方式展示无线 → NetSwitch → 有线的切换流程，并说明主要操作：

- 「无线」：切回选中的 Wi-Fi 服务
- 「有线」：切到选中的以太网、USB 网卡或雷雳网卡服务
- 「设置」：选择本机网络服务、自动模式和登录自启
- 「刷新」：更新 IP、SSID 和连接状态

首次启动会自动打开一次图文引导。

## 设置

在菜单栏中打开「设置...」可以：

- 选择这台 Mac 的无线服务和有线服务
- 开启或关闭自动模式
- 选择自动优先级：有线优先或无线优先
- 开启或关闭登录时自动启动

配置保存在 macOS `UserDefaults` 中，每台 Mac 都有自己的本机配置。

## 安装

安装到 `~/Applications` 并注册登录自启：

```sh
./scripts/install-app.sh
```

安装后也可以手动打开：

```sh
open ~/Applications/NetSwitch.app
```

移除 app 和登录自启项：

```sh
./scripts/uninstall-app.sh
```

## 分发

构建 Apple Silicon + Intel 通用 app、zip 和 pkg：

```sh
./scripts/package-app.sh
```

产物会写入 `dist/`：

- `NetSwitch.app`
- `NetSwitch-<version>-universal.zip`
- `NetSwitch-<version>-universal.pkg`

`.pkg` 会把 NetSwitch 安装到 `/Applications`，并添加 `/Library/LaunchAgents/com.joker2.netswitch.plist`，让应用默认随用户登录自动启动。
启动项不会强制新开实例；如果 NetSwitch 已在运行，macOS 会复用当前实例。

app bundle 使用 ad-hoc 签名，适合本地安装和内部分享。`.pkg` 尚未使用 Developer ID 签名。面向陌生用户公开分发时仍需要 Apple Developer ID Installer 证书和公证。

## 工作方式

NetSwitch 使用 macOS 内置的 `networksetup` 命令：

- 通过 `networksetup -listallnetworkservices` 读取网络服务
- 通过 `networksetup -listallhardwareports` 读取硬件端口
- 通过 `networksetup -getinfo` 读取目标服务 IP
- 自动推荐本机的 Wi-Fi 和有线服务
- 通过 `networksetup -setnetworkserviceenabled <service> on` 启用目标服务
- 切到无线时，停用托管的有线服务
- 切到有线时，保持 Wi-Fi 开关开启，只通过 CoreWLAN 断开当前 Wi-Fi 连接
- Wi-Fi 活跃时通过 `networksetup -getairportnetwork` 读取 SSID

切换后，NetSwitch 会自动刷新几秒，让 DHCP 分配的 IP 自动显示出来。
