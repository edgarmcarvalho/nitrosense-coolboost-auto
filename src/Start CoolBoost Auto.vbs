' CoolBoost Auto - starts the tray icon without a console window
' "/autostart" (used by the startup shortcut) lets the app respect its "Start with Windows" setting
Set sh = CreateObject("WScript.Shell")
p = sh.ExpandEnvironmentStrings("%ProgramData%") & "\CoolBoostAuto\CoolBoostTray.ps1"
a = ""
If WScript.Arguments.Count > 0 Then a = " -Autostart"
sh.Run "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & p & """" & a, 0, False