# nitrosense-coolboost-auto

**Automatic CoolBoost™ for Acer Nitro laptops**: turns CoolBoost off on battery, brings it back when you plug in, switches it on while you're gaming, and gives you a one-click tray icon. NitroSense itself never has to open.

🇧🇷 [Leia em português](README.pt-BR.md)

> Not affiliated with or endorsed by Acer. *Acer, Nitro, NitroSense and CoolBoost are trademarks of Acer Inc.*

## Features

- **Battery rule:** CoolBoost turns **off** when you unplug, so the fans don't drain the battery.
- **Plug-in rule:** when you plug back in, choose what happens:
  - **Restore previous state** (default)
  - **Always ON**
  - **Always OFF**
  - **Leave it as it is**
- **Gaming mode:** CoolBoost turns **on** while a game is running and goes back to its previous state when the game closes.
  - Games are detected from Windows' own game list, your Steam libraries and Rockstar games, plus any app you mark yourself. New installs are picked up automatically.
  - Uninstallers, crash reporters and launchers are ignored.
  - If you change CoolBoost yourself mid-game, the automation leaves it alone until the game closes.
  - On battery, the battery rule wins.
- **Tray icon:**
  - Blue = ON, grey with a red slash = OFF, green badge = game running.
  - Left-click to toggle. Right-click for all the options.
  - No UAC prompts.
- **No NitroSense window.** CoolBoost is switched through the same firmware call NitroSense uses, and NitroSense's own setting is kept in sync, so the app always shows the right state.

## Compatibility

| | |
|---|---|
| **Tested on** | Acer Nitro 5 **AN515-55**, Windows 11, NitroSense 3.01 |
| **Likely works on** | Other Acer Nitro / Predator models whose firmware exposes the `APGeAction` WMI interface |
| **Requires** | NitroSense installed, Windows PowerShell 5.1 (built into Windows 10/11), an admin account for installing |

The installer checks your laptop first. If it doesn't support this CoolBoost interface, the installer stops without changing anything. If you try it on another model, please open an issue saying whether it worked.

## Install

1. Download this repository: **Code → Download ZIP**, then extract it.
2. Right-click **`install.ps1`** → **Run with PowerShell**, and accept the admin (UAC) prompt.
   - Or, from a terminal in the extracted folder: `powershell -ExecutionPolicy Bypass -File .\install.ps1`
3. A snowflake icon appears next to the clock. It may be hidden under the **^** arrow; drag it onto the taskbar to keep it visible.

Options: `-NoAutostart` (don't start the icon at login). Re-running the installer upgrades an existing install and keeps your settings.

## Uninstall

Right-click **`uninstall.ps1`** → **Run with PowerShell**. Add `-KeepSettings` to keep your settings for a later reinstall. CoolBoost stays in whatever state it was in.

## Using it

Right-click the tray icon:

- **Turn CoolBoost ON / OFF**
- **Automation**
  - **Turn off on battery**
  - **When plugged in:** Restore previous state / Always turn ON / Always turn OFF / Leave it as it is
  - **Turn ON while gaming**
  - **Mark a running app as a game**: for anything that isn't detected automatically
  - **Stop treating as a game**: if something triggers by mistake (*Reset exclusions* undoes it)
- **Open NitroSense** / **Open log**

You can also reopen the icon from the Start menu: **CoolBoost Tray**.

## How it works

| Part | Where | Runs as |
|---|---|---|
| Worker (`CoolBoostSys.ps1`) | `C:\Program Files\CoolBoostAuto` (admin-only) | SYSTEM, via scheduled tasks |
| Tray icon (`CoolBoostTray.ps1`) | `C:\ProgramData\CoolBoostAuto` | you |
| Settings (`settings.json`), tray log | `C:\ProgramData\CoolBoostAuto` | — |
| Worker log | `C:\Program Files\CoolBoostAuto\CoolBoostAuto.log` | — |

**Scheduled tasks**
- `CoolBoostAuto` runs on power plug/unplug (Kernel-Power event 105), at startup and after waking from sleep.
- `CoolBoostToggle`, `CoolBoostOn` and `CoolBoostOff` can be started by normal users. That's how the tray icon switches CoolBoost without admin rights.

**The CoolBoost call:** CoolBoost is read with `APGeAction.GetFunction(0x207)` (the state is in byte 1) and set with `APGeAction.SetFunction((state << 16) | 7)`, in the `root\WMI` namespace.

**Security notes**
- The SYSTEM part lives in an admin-only folder.
- It reads only true/false values and a fixed list of options from the user-editable settings file.
- No network access and no telemetry.

## Known limitations

- Tested only on the AN515-55. Other models may use different firmware calls.
- If you exit the tray icon while a game is running, CoolBoost stays in its current state.
- A game is identified by its executable. Games that run through a launcher stub get detected once the real game process starts.

## Credits

- The CoolBoost firmware command was identified thanks to **[OpenPredator](https://github.com/KRWCLASSIC/OpenPredator)** by KRWCLASSIC (MIT), an open-source reimplementation of the NitroSense/PredatorSense stack. No code was copied; the call was verified independently on an AN515-55.
- Built by [@edgarmcarvalho](https://github.com/edgarmcarvalho) with help from Claude (Anthropic).

## License

[MIT](LICENSE). Provided as-is, without warranty. You use it at your own risk.
