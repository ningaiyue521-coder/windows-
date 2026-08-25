# 工作时间悬浮闹钟

一个适用于 Windows 的轻量级桌面悬浮工具，将工作时间倒计时、创业板指分时行情和同步歌词组合在同一个自适应窗口中。

## 功能

- 显示当前时间、日期、工作状态和距离下一时间节点的倒计时。
- 默认工作时段：`09:00–12:00`、`13:30–18:00`。
- 周末以及下班后自动计算到下一个工作日的时间。
- 显示创业板指 `399006` 的实时点数、涨跌、高低价和分时走势。
- 支持搜索歌曲、推荐歌曲以及同步歌词平滑滚动。
- 根据窗口宽度和高度自动调整信息密度：
  - 极小模式显示一张信息卡，左右拖动可切换倒计时、创业板和当前歌词；
  - 摘要模式同时显示三张信息卡，拖动卡片可调整排列顺序；
  - 展开模式恢复走势图、歌词搜索和推荐功能，模块也可拖动换序。
- 自动保存模块顺序和极小模式当前卡片，下次启动继续沿用。
- 支持四边及四角拖动缩放、`Ctrl + 滚轮`缩放、双击切换紧凑/展开模式。
- 控制按钮默认隐藏，鼠标移到右上角后显示。

## 使用方法

### 直接运行 EXE

从 GitHub Releases 下载最新版 `工作时间悬浮闹钟-综合优化版.exe`，双击运行即可。

由于程序暂未进行商业代码签名，Windows SmartScreen 可能显示安全提醒。请从本仓库 Releases 下载，并可对照源码自行检查或构建。

### 运行源码

系统要求：Windows 10/11、Windows PowerShell 5.1。

双击：

```text
start-work-clock.bat
```

或在 PowerShell 中执行：

```powershell
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File .\workday-floating-clock.ps1
```

## 操作

- 拖动空白区域：移动窗口。
- 拖动四边或四角：自由调整大小。
- `Ctrl + 鼠标滚轮`：按预设档位缩放。
- 双击窗口：在纯倒计时与上次展开尺寸之间切换。
- 右键窗口：打开显示模式、最小化和退出菜单。
- 鼠标移到右上角：显示缩小、放大、最小化和关闭按钮。

## 数据来源与网络

行情数据来自腾讯行情公开接口；歌曲搜索和歌词来自网易云音乐公开接口及 LRCLIB。行情、歌曲搜索和歌词功能需要网络连接，倒计时功能可离线使用。

## 从源码构建 EXE

安装 [PS2EXE](https://www.powershellgallery.com/packages/ps2exe) 后执行：

```powershell
Invoke-PS2EXE `
  -inputFile .\workday-floating-clock.ps1 `
  -outputFile .\工作时间悬浮闹钟-综合优化版.exe `
  -noConsole -STA -DPIAware `
  -title '工作时间悬浮闹钟' `
  -description '工作时间、创业板分时与歌词悬浮工具'
```

## 项目文件

- `workday-floating-clock.ps1`：程序源码。
- `start-work-clock.bat`：源码启动脚本。
- Releases：已构建的 Windows EXE。

## 说明

本项目仅作为桌面效率工具。行情信息仅供展示，不构成投资建议。第三方接口可能调整，届时相关网络功能可能需要更新。
