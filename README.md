# CoolBoost Auto

[![Latest release](https://img.shields.io/github/v/release/edgarmcarvalho/nitrosense-coolboost-auto?label=release&color=e2231a)](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/edgarmcarvalho/nitrosense-coolboost-auto/total?color=555)](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-555)](LICENSE)
![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-555)

**Automatic CoolBoost™ for Acer Nitro laptops.** It turns CoolBoost **off on battery**, **back on your terms when you plug in**, and **on while you're gaming**. One click on the tray icon switches it whenever you want. NitroSense never has to open.

**[⬇ Download the latest version](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/releases/latest)** · 🇧🇷 [Leia em português](README.pt-BR.md)

![CoolBoost Auto: tray icon states and menu](docs/screenshot.png?v=3)

> Not affiliated with or endorsed by Acer. *Acer, Nitro, NitroSense and CoolBoost are trademarks of Acer Inc.*

## What it does

| When… | CoolBoost Auto… |
|---|---|
| **You unplug the charger** | Turns CoolBoost **off**, so the fans don't drain the battery. |
| **You plug it back in** | Applies your rule: **restore** what it was before you unplugged (default), **always on**, **always off**, or **keep** the battery state. |
| **A game starts** (plugged in) | Turns CoolBoost **on**, and puts it back when the game closes. |
| **You switch it yourself during a game** | Respects your choice until the game closes. |
| **The laptop starts or wakes up** | Checks again, in case the power source changed. |

On battery, the battery rule always wins: a game never turns CoolBoost on while you're unplugged.

## Install

**Easiest, and not blocked by Windows:** copy this line, open **PowerShell** (Start menu → type *PowerShell* → Enter), paste it with a right-click and press Enter:

```powershell
irm https://raw.githubusercontent.com/edgarmcarvalho/nitrosense-coolboost-auto/main/get.ps1 | iex
```

It downloads the latest release, checks its SHA-256 checksum, and runs the installer (Windows asks for administrator permission). It checks your laptop first and installs nothing if it isn't supported. Because PowerShell does the download, not the browser, SmartScreen and the other download blocks never come into play. You can read the script first: [get.ps1](https://raw.githubusercontent.com/edgarmcarvalho/nitrosense-coolboost-auto/main/get.ps1).

Afterwards, a red or grey fan appears next to the clock (or under the **^** arrow; drag it onto the taskbar to keep it visible).

**Prefer the setup wizard?** Download **`CoolBoostAuto-Setup-x.y.z.exe`** from the [latest release](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/releases/latest) and run it. Because it isn't code-signed, Windows may block it (see below); if it does, use the line above.

**Upgrading:** run the same line again (or the newer setup). Your settings are kept.

**Uninstalling:** *Settings → Apps → Installed apps → CoolBoost Auto → Uninstall*. Everything is removed; CoolBoost stays in its current state.

> **If Windows blocks the setup .exe or the zip:** they aren't code-signed, so SmartScreen may say *Windows protected your PC* (**More info → Run anyway**), and **Smart App Control** may block them with no way around. That's why the PowerShell line above exists. The files are the same and have published checksums.

<details><summary><b>Install with scripts instead of the wizard</b></summary>

Download `CoolBoostAuto-Scripts-x.y.z.zip` from the release. Before extracting, right-click it → **Properties** → tick **Unblock** → OK. Then open PowerShell in the extracted folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

(Windows' own **Run with PowerShell** menu doesn't work on a default Windows, which forbids running script files; the line above allows it for this one run.)

- `-NoAutostart` (add it after `install.ps1`): don't start with Windows (you can turn it on later from the menu).
- To remove: run **`uninstall.ps1`** (add `-KeepSettings` to keep your settings).
</details>

## Using it

| Icon | Meaning |
|:---:|---|
| <img src="docs/icons/tray_on.png" width="32" alt="red fan"> | CoolBoost is **on** |
| <img src="docs/icons/tray_off.png" width="32" alt="grey fan"> | CoolBoost is **off** |
| <img src="docs/icons/tray_on_game.png" width="32" alt="red fan, green badge"> <img src="docs/icons/tray_off_game.png" width="32" alt="grey fan, green badge"> | A **game is running** |
| <img src="docs/icons/tray_on_paused.png" width="32" alt="red fan, amber pause badge"> <img src="docs/icons/tray_off_paused.png" width="32" alt="grey fan, amber pause badge"> | Automation is **paused** |

- **Left-click** switches CoolBoost, with no admin prompt.
- **Hover** to see what's going on, e.g. *CoolBoost ON · plugged in · gaming: BeamNG.drive*.
- **Right-click** for the menu.

<img src="docs/notice.png" width="210" align="right" alt="Notice reading: CoolBoost ON, gaming: BeamNG.drive">

Whenever CoolBoost switches, a small notice appears above the taskbar for about 3 seconds and says why (*unplugged*, *gaming: (the game)*, *game closed*…). It never takes focus; turn it off in **Settings ▸ On-screen notice**.

<details><summary><b>Everything in the menu</b></summary>

- **Turn CoolBoost ON / OFF**: same as a left-click.
- **On battery: turn CoolBoost off**: the battery rule (needed for *Restore*).
- **When plugged in** ▸ *Restore state from before unplugging* · *Always ON* · *Always OFF* · *Keep the battery state*.
- **While gaming: turn CoolBoost on (when plugged in)**: the game rule.
- **Games** ▸ the games detected now, **Add a running app** (treat an open app as a game), **Ignore a game**, and **Ignored apps** (click one to stop ignoring it).
- **Pause automation**: nothing switches by itself until you untick it. Clicking the icon still works.
- **Settings** ▸ **Start with Windows** · **On-screen notice** · **Check for updates automatically** (off by default) · **Check for updates now**: asks GitHub for the latest version number and tells you if there's a newer one. Nothing is downloaded or installed unless you click the update; it then opens a window that runs the same PowerShell installer shown above, stays open, and waits for you to press Enter.
- **Tools** ▸ **Open NitroSense** · **Open log** (everything CoolBoost Auto did, in time order, with *[power]* or *[tray]* showing where each line came from).
- **Exit (stops all automation)**: closes the icon and stops every rule until you start CoolBoost Auto again from the Start menu.
</details>

## How games are detected

Every few seconds, CoolBoost Auto treats a running program as a game if:

- **Windows already knows it's a game** (the list Game Bar uses), or
- it was installed by **Steam**, **Epic Games**, **GOG**, **Ubisoft Connect**, **EA app**, **Battle.net**, the **Xbox app / Game Pass**, **Amazon Games**, **Riot Games**, **itch.io** or **Rockstar Games**, or
- you added it with **Games ▸ Add a running app**.

There's no list to maintain. Launchers, installers, updaters, crash reporters and anti-cheat services are ignored. Games bought elsewhere (Nuuvem, Humble…) are covered through the store they're activated on; a DRM-free game in a custom folder can be added by hand.

## Compatibility

| | |
|---|---|
| **Works on** | Acer Nitro 5 **AN515-55** (tested, Windows 11, NitroSense 3.01) · Acer Nitro 5 **AN515-57** (reported by a user) |
| **Likely works on** | Other Acer Nitro models with NitroSense |
| **Not supported yet** | Predator laptops with PredatorSense (testers welcome) |
| **Not supported** | Predator Triton 300 **PT315-53** (Acer doesn't offer CoolBoost on it) |
| **Requires** | NitroSense installed (it doesn't need to be open), Windows 10 or 11 64-bit, an admin account to install |

The installer checks for the CoolBoost interface and NitroSense, not for a model name, and changes nothing if either is missing.

**Tried it on another model?** Please [send a compatibility report](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/issues/new?template=compatibility-report.yml), even if it didn't work. The form includes an optional, read-only [hardware check](tools/hardware-check.ps1) that never changes a setting.

## Troubleshooting

**CoolBoost changed when I didn't expect it.** Hover over the icon to see the status, then check **Open log**: every switch is logged with its reason. If it looks like a bug, [open an issue](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/issues) with your model and both logs.

**A game doesn't turn CoolBoost on.** Make sure you're plugged in and the icon has no pause badge, then use **Games ▸ Add a running app** while the game is open.

**Something that isn't a game turns it on.** Use **Games ▸ Ignore a game**.

**The icon disappeared.** You probably clicked **Exit**. Start **CoolBoost Auto** again from the Start menu.

**Does it slow the laptop down?** No. At rest it uses about 0.1% of the CPU and around 130 MB of memory.

## Privacy

No telemetry, no account, nothing leaves your laptop. The only exception is the optional update check, which asks GitHub for the latest release number when you turn it on or click it. If you then click the update itself, the new version is downloaded from GitHub and installed; that only happens when you click.

## Code signing policy

The setup and the scripts are currently **unsigned**: a code-signing certificate for an independent open-source project needs either money or proof of public adoption. The [SignPath Foundation](https://signpath.org) free program declined the application for now, because the project doesn't yet have enough public visibility, and it can be reapplied for later. Until then, install with the **PowerShell line above**, which Windows doesn't block, and check the SHA-256 checksums published with each release.

The release workflow already has the signing steps prepared, so every release can be signed once a certificate exists.

## How it works

<details><summary><b>Technical details</b></summary>

| Part | Where | Runs as | Does |
|---|---|---|---|
| Worker (`CoolBoostSys.ps1`) | `C:\Program Files\CoolBoostAuto` (admin-only) | SYSTEM, via scheduled tasks | Switches CoolBoost, applies the plug/unplug rules |
| Tray icon (`CoolBoostTray.ps1`) | `C:\ProgramData\CoolBoostAuto` | you | Icon, menu, game detection |

- **Scheduled tasks:** `CoolBoostAuto` runs on power-source changes (Kernel-Power event 105), at startup and after sleep. `CoolBoostOn`, `CoolBoostOff` and `CoolBoostToggle` can be started by normal users, which is how the icon switches CoolBoost without an admin prompt.
- **The CoolBoost call:** read with `APGeAction.GetFunction(0x207)` (byte 1) and set with `APGeAction.SetFunction((state << 16) | 7)` in `root\WMI`, the same firmware call NitroSense uses. NitroSense's own setting (`HKLM\SOFTWARE\OEM\NitroSense\FanControl\CoolBoostMode`) is kept in sync.
- **Files:** settings in `C:\ProgramData\CoolBoostAuto\settings.json`; logs in `C:\Program Files\CoolBoostAuto\CoolBoostAuto.log` (power and manual) and `C:\ProgramData\CoolBoostAuto\tray.log` (gaming), both trimmed automatically.
- **Security:** the SYSTEM part lives in a folder only admins can change, and reads only true/false values and a fixed list of options from the user-editable settings file.
- **Building:** GitHub Actions ([`release.yml`](.github/workflows/release.yml)) builds each `v*` tag: it checks the PowerShell syntax, compiles [`installer/setup.iss`](installer/setup.iss) with Inno Setup, and attaches the setup, a scripts zip and SHA-256 checksums, with notes from [`release-notes/`](release-notes). Locally: `ISCC.exe /DAppVersion=1.2.3 installer\setup.iss`.
- **Limitations:** games are recognised by their executable, so a game started through a launcher counts once the game itself runs. Built on Windows PowerShell, so it uses more memory than a native app (about 130 MB).
</details>

## Credits

- The CoolBoost firmware command was identified thanks to **[OpenPredator](https://github.com/KRWCLASSIC/OpenPredator)** by KRWCLASSIC (MIT). No code was copied; the call was verified independently on an AN515-55.
- Thanks to everyone who tested it on their own laptop and reported back.
- Built by [@edgarmcarvalho](https://github.com/edgarmcarvalho) with help from Claude (Anthropic).

## License

[MIT](LICENSE). Provided as-is, without warranty. You use it at your own risk.
