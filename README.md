# CoolBoost Auto

[![Latest release](https://img.shields.io/github/v/release/edgarmcarvalho/nitrosense-coolboost-auto?label=release&color=e2231a)](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/edgarmcarvalho/nitrosense-coolboost-auto/total?color=555)](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-555)](LICENSE)
![Windows 10/11](https://img.shields.io/badge/Windows-10%20%7C%2011-555)

**Automatic CoolBoost™ for Acer Nitro laptops.** CoolBoost Auto turns CoolBoost on and off for you, based on what you're doing: **off on battery**, **back to your choice when you plug in**, and **on while you're gaming**. When you want to decide yourself, one click on the tray icon switches it. NitroSense never has to open.

**[⬇ Download the latest version](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/releases/latest)** · 🇧🇷 [Leia em português](README.pt-BR.md)

![CoolBoost Auto: tray icon states and menu](docs/screenshot.png)

> Not affiliated with or endorsed by Acer. *Acer, Nitro, NitroSense and CoolBoost are trademarks of Acer Inc.*

## What it does

| When… | CoolBoost Auto… |
|---|---|
| **You unplug the charger** | Turns CoolBoost **off**, so the fans don't drain the battery, and remembers whether it was on. |
| **You plug it back in** | Applies your rule: **restore** the state from before you unplugged (default), **always on**, **always off**, or **keep** the battery state. |
| **A game starts** (while plugged in) | Turns CoolBoost **on**, and puts it back the way it was when the game closes. |
| **You switch CoolBoost yourself during a game** | Leaves your choice alone until the game closes, whether you used the tray icon or NitroSense. |
| **The laptop starts or wakes from sleep** | Checks again, in case you plugged in or unplugged in the meantime. |
| **You pause the automation** | Changes nothing until you resume. Then it catches up with whatever changed. |

On battery the battery rule always wins, so a game never turns CoolBoost on while you're unplugged. If you plug in during a game, CoolBoost goes back on a few seconds later.

## The tray icon

| Icon | Meaning |
|:---:|---|
| <img src="docs/icons/tray_on.png" width="32" alt="red fan"> | CoolBoost is **on** |
| <img src="docs/icons/tray_off.png" width="32" alt="grey fan"> | CoolBoost is **off** |
| <img src="docs/icons/tray_on_game.png" width="32" alt="red fan, green badge"> <img src="docs/icons/tray_off_game.png" width="32" alt="grey fan, green badge"> | A **game is running** and the automation is in charge |
| <img src="docs/icons/tray_on_paused.png" width="32" alt="red fan, amber pause badge"> <img src="docs/icons/tray_off_paused.png" width="32" alt="grey fan, amber pause badge"> | The **automation is paused**: nothing switches by itself |

- **Left-click** switches CoolBoost on or off, with no admin prompt. The icon changes once the laptop confirms the switch, so it always shows the real state.
- **Hover** to see what's going on, for example *CoolBoost ON · plugged in · gaming: BeamNG.drive*.
- **Right-click** for the menu.

## The menu

- **CoolBoost Auto x.y.z** and a **status line**: what CoolBoost is doing and why.
- **Turn CoolBoost ON / OFF**: same as a left-click.
- **On battery: turn CoolBoost off**: the battery rule. *Restore* (below) needs it, because that's when the state is remembered.
- **When plugged in** ▸ *Restore state from before unplugging* · *Always turn CoolBoost ON* · *Always turn CoolBoost OFF* · *Keep the battery state*
- **While gaming: turn CoolBoost on (when plugged in)**: the game rule.
- **Games** ▸ the games detected right now, plus:
  - **Add a running app**: treat an open app as a game, for anything that isn't detected automatically.
  - **Ignore a game**: for something that turns CoolBoost on by mistake.
  - **Ignored apps**: click one to stop ignoring it.
- **Pause automation**: stops all automatic switching until you untick it. Clicking the icon still works.
- **Start with Windows**: start CoolBoost Auto when you sign in.
- **Open NitroSense** · **Open log** (power and manual switching, or gaming automation).
- **Exit (stops all automation)**: closes the icon and turns off every rule until you start CoolBoost Auto again from the Start menu. CoolBoost stays as it is.

## How games are detected

CoolBoost Auto looks at the running programs every few seconds and treats one as a game if:

- **Windows already knows it's a game** (the same list Game Bar uses), or
- it's installed in one of your **Steam libraries** or the **Rockstar Games** folder, or
- you added it with **Games ▸ Add a running app**.

New games are picked up automatically, with no list to maintain. Launchers, uninstallers, crash reporters, updaters and anti-cheat services are ignored. A game is recognised by its executable, so games started through a launcher are detected once the game itself is running. If something is detected by mistake, use **Games ▸ Ignore a game**.

## Compatibility

| | |
|---|---|
| **Tested on** | Acer Nitro 5 **AN515-55** (Windows 11, NitroSense 3.01) · Acer Nitro 5 **AN515-57** (reported working by a user) |
| **Likely works on** | Other Acer Nitro models with NitroSense whose firmware has the `APGeAction` WMI interface |
| **Not supported yet** | Predator laptops with PredatorSense (help testing is welcome) |
| **Not supported** | Acer Predator Triton 300 **PT315-53**: Acer doesn't offer CoolBoost on this model (checked by a user) |
| **Requires** | NitroSense installed (it doesn't need to be open), Windows 10 or 11 (64-bit), an admin account to install |

The installer checks for the CoolBoost interface and for NitroSense, not for a model name. If either is missing, it stops without changing anything. Tried it on another model? Please [open an issue](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/issues) saying whether it worked, so it can be added here.

## Install

1. Download **`CoolBoostAuto-Setup-x.y.z.exe`** from the [latest release](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/releases/latest).
2. Run it, accept the admin (UAC) prompt and go through the wizard. It checks your laptop first and stops before installing anything if it isn't supported.
3. A red or grey fan appears next to the clock. If you don't see it, it's under the **^** arrow; drag it onto the taskbar to keep it visible.

**Upgrading:** run the newer setup over the old one. Your settings are kept.

**Windows warnings:** the installer isn't code-signed yet (see [Code signing policy](#code-signing-policy)). SmartScreen may show *Windows protected your PC*: click **More info → Run anyway**. If **Smart App Control** blocks it, use the scripts zip below.

<details><summary><b>Install with scripts instead of the wizard</b></summary>

Download `CoolBoostAuto-Scripts-x.y.z.zip` from the release (or **Code → Download ZIP**), extract it, then right-click **`install.ps1`** → **Run with PowerShell**.

- `-NoAutostart`: turns **Start with Windows** off (you can turn it back on from the menu).
- To remove: run **`uninstall.ps1`**. Add `-KeepSettings` to keep your settings for a later reinstall.
</details>

## Uninstall

**Settings → Apps → Installed apps → CoolBoost Auto → Uninstall.** Everything is removed: the tray icon, the scheduled tasks, the files and the shortcuts. CoolBoost stays in whatever state it was in; change it in NitroSense if needed.

## Troubleshooting

**CoolBoost changed when I didn't expect it.** Hover over the icon or open the menu to see the status line. Then check **Open log**: every automatic and manual switch is written there with the reason. If it looks like a bug, please [open an issue](https://github.com/edgarmcarvalho/nitrosense-coolboost-auto/issues) with your laptop model and both logs.

**A game doesn't turn CoolBoost on.** Check that you're plugged in and that the icon has no pause badge. Then use **Games ▸ Add a running app** while the game is open.

**Something that isn't a game turns CoolBoost on.** Use **Games ▸ Ignore a game**.

**The icon disappeared.** You probably clicked **Exit**. Start it again from the Start menu: **CoolBoost Auto**.

**Does it slow the laptop down?** No. At rest it uses about 0.1% of the CPU and around 130 MB of memory (it runs on Windows PowerShell).

## How it works

CoolBoost Auto has two parts:

| Part | Where | Runs as | What it does |
|---|---|---|---|
| Worker (`CoolBoostSys.ps1`) | `C:\Program Files\CoolBoostAuto` (only admins can change it) | SYSTEM, via scheduled tasks | Switches CoolBoost and applies the plug/unplug rules |
| Tray icon (`CoolBoostTray.ps1`) | `C:\ProgramData\CoolBoostAuto` | you | The icon and menu, game detection |

**Scheduled tasks**
- `CoolBoostAuto` runs when the power source changes (Kernel-Power event 105), at startup and after waking from sleep. The tray icon also starts it when it opens and when automation resumes. It does nothing while the automation is paused or CoolBoost Auto is closed.
- `CoolBoostOn`, `CoolBoostOff` and `CoolBoostToggle` can be started by normal users. That's how the tray icon switches CoolBoost without an admin prompt.

**The CoolBoost call:** the state is read with `APGeAction.GetFunction(0x207)` (it's in byte 1) and set with `APGeAction.SetFunction((state << 16) | 7)`, in the `root\WMI` namespace. This is the same firmware call NitroSense uses. NitroSense's own setting (`HKLM\SOFTWARE\OEM\NitroSense\FanControl\CoolBoostMode`) is kept in sync, so the NitroSense app always shows the right state.

**Files**
- Settings: `C:\ProgramData\CoolBoostAuto\settings.json`
- Logs: `C:\Program Files\CoolBoostAuto\CoolBoostAuto.log` (power and manual switching) and `C:\ProgramData\CoolBoostAuto\tray.log` (gaming automation). Both are trimmed automatically.

**Security and privacy**
- The part that runs as SYSTEM lives in a folder only admins can change.
- From the settings file, which you can edit, it reads only true/false values and a fixed list of options.
- No network access, no telemetry. Everything stays on your laptop.

## Building the installer

Releases are built by GitHub Actions ([`.github/workflows/release.yml`](.github/workflows/release.yml)) whenever a `v*` tag is pushed. The workflow checks the PowerShell syntax, compiles [`installer/setup.iss`](installer/setup.iss) with Inno Setup and attaches the setup, a scripts zip and SHA-256 checksums to the release, with notes from [`release-notes/`](release-notes). To build locally: `ISCC.exe /DAppVersion=1.2.3 installer\setup.iss`.

## Code signing policy

The setup is currently **unsigned**. Windows SmartScreen may warn about it and Smart App Control may block it; if that happens, use the scripts zip. Signing through the [SignPath Foundation](https://signpath.org) open-source program has been requested. Once it's approved, every release built by the [release workflow](.github/workflows/release.yml) will be signed, and this section will say so.

- Committers and reviewers: [@edgarmcarvalho](https://github.com/edgarmcarvalho)
- Approvers: [@edgarmcarvalho](https://github.com/edgarmcarvalho)

**Privacy:** this program does not transfer any information to other networked systems. It works entirely offline.

## Known limitations

- Tested on the AN515-55 and AN515-57 only. Other models may use different firmware calls; the installer refuses to install if the call isn't there.
- Games are recognised by their executable (see [How games are detected](#how-games-are-detected)).
- Built on Windows PowerShell, so it uses more memory than a native app would (about 130 MB).

## Credits

- The CoolBoost firmware command was identified thanks to **[OpenPredator](https://github.com/KRWCLASSIC/OpenPredator)** by KRWCLASSIC (MIT), an open-source reimplementation of the NitroSense/PredatorSense stack. No code was copied; the call was verified independently on an AN515-55.
- Thanks to everyone who tested it on their own laptop and reported back.
- Built by [@edgarmcarvalho](https://github.com/edgarmcarvalho) with help from Claude (Anthropic).

## License

[MIT](LICENSE). Provided as-is, without warranty. You use it at your own risk.
