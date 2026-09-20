# Workday Floating Clock

A lightweight Windows desktop widget that combines a workday countdown, intraday ChiNext Index quotes, and synchronized lyrics in an adaptive floating window.

## Features

- Current time, date, work status, and a countdown to the next schedule milestone
- Default work periods: `09:00–12:00` and `13:30–18:00`
- Automatic calculation of the next working day after work and on weekends
- Live values, price changes, highs, lows, and intraday trends for the ChiNext Index (`399006`)
- Song search, recommendations, and smoothly scrolling synchronized lyrics
- A layout that adapts to the window's width and height:
  - Mini mode shows one card; drag left or right to switch between the countdown, index data, and current lyrics.
  - Summary mode shows three cards together; drag them to change their order.
  - Expanded mode restores charts, lyric search, and recommendations; its modules can also be reordered.
- Automatic saving of module order and the active mini-mode card
- Resizing from any edge or corner, zooming with `Ctrl + mouse wheel`, and double-click switching between compact and expanded views
- Window controls that appear when the pointer moves to the upper-right corner

## Getting started

### Run the executable

Download the latest `工作时间悬浮闹钟-综合优化版.exe` (Workday Floating Clock, optimized edition) from GitHub Releases and double-click it.

The executable is not commercially code-signed, so Windows SmartScreen may display a warning. Download from this repository's Releases, or inspect the source and build it yourself.

### Run from source

Requirements: Windows 10/11 and Windows PowerShell 5.1.

Double-click:

```text
start-work-clock.bat
```

Or run in PowerShell:

```powershell
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File .\workday-floating-clock.ps1
```

## Controls

- Drag an empty area to move the window.
- Drag an edge or corner to resize it.
- Use `Ctrl + mouse wheel` to switch between preset zoom levels.
- Double-click the window to switch between countdown-only mode and the previous expanded size.
- Right-click the window to open the display-mode, minimize, and exit menu.
- Move the pointer to the upper-right corner to reveal the shrink, enlarge, minimize, and close controls.

## Data sources and networking

Market data comes from Tencent's public quote interface. Song search and lyrics use NetEase Cloud Music's public interfaces and LRCLIB. Quotes, song search, and lyrics require an internet connection; the countdown works offline.

## Build an executable

Install [PS2EXE](https://www.powershellgallery.com/packages/ps2exe), then run:

```powershell
Invoke-PS2EXE `
  -inputFile .\workday-floating-clock.ps1 `
  -outputFile .\工作时间悬浮闹钟-综合优化版.exe `
  -noConsole -STA -DPIAware `
  -title 'Workday Floating Clock' `
  -description 'A floating workday countdown, ChiNext quote and lyrics widget'
```

The output filename above matches the existing release filename; its English meaning is explained in the download instructions.

## Project files

- `workday-floating-clock.ps1`: application source
- `start-work-clock.bat`: source launcher
- Releases: prebuilt Windows executables

## Notes

This project is a desktop productivity tool. Market data is provided for display only and is not investment advice. Third-party interfaces may change and require updates to the network features.
