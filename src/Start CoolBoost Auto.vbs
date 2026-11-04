' CoolBoost Auto - starts the tray icon without a console window
Set sh = CreateObject("WScript.Shell")
p = sh.ExpandEnvironmentStrings("%ProgramData%") & "\CoolBoostAuto\CoolBoostTray.ps1"
sh.Run "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & p & """", 0, False
