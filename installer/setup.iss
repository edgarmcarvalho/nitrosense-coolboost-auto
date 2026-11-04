; nitrosense-coolboost-auto - setup wizard (Inno Setup 6.6+)
; Build:  ISCC.exe /DAppVersion=0.9.0 installer\setup.iss   ->  dist\CoolBoostAuto-Setup-0.9.0.exe
; The wizard copies the package to Program Files and runs install.ps1, which does the real work
; (compatibility check, scheduled tasks, permissions, shortcuts). Uninstall runs uninstall.ps1.
; Testing switch: /SKIPCHECK skips the hardware check and installs with install.ps1 -Force
; (used to test the wizard in Windows Sandbox, which has no Acer hardware).

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif
#define AppName "CoolBoost Auto"
#define RepoUrl "https://github.com/edgarmcarvalho/nitrosense-coolboost-auto"

[Setup]
AppId={{8F3C2B1E-6A4D-4E8B-9C2F-1D5E7A9B0C34}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=edgarmcarvalho
AppPublisherURL={#RepoUrl}
AppSupportURL={#RepoUrl}/issues
AppUpdatesURL={#RepoUrl}/releases
DefaultDirName={autopf}\nitrosense-coolboost-auto
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=no
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\dist
OutputBaseFilename=CoolBoostAuto-Setup-{#AppVersion}
SetupIconFile=..\assets\app.ico
UninstallDisplayIcon={app}\assets\app.ico
UninstallDisplayName={#AppName}
LicenseFile=..\LICENSE
Compression=lzma2
SolidCompression=yes
CloseApplications=no
#if Ver >= EncodeVer(6,6,0)
WizardStyle=modern dark
#else
WizardStyle=modern
#endif
WizardImageFile=wizard_100.png,wizard_125.png,wizard_150.png,wizard_175.png,wizard_200.png,wizard_250.png
WizardSmallImageFile=wizard_small_100.png,wizard_small_125.png,wizard_small_150.png,wizard_small_175.png,wizard_small_200.png,wizard_small_250.png
WizardImageStretch=no

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "ptbr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[CustomMessages]
en.AutoStart=Start the CoolBoost tray icon when I sign in to Windows
ptbr.AutoStart=Iniciar o ícone do CoolBoost ao entrar no Windows
en.LaunchTray=Start the CoolBoost tray icon now
ptbr.LaunchTray=Iniciar o ícone do CoolBoost agora
en.Configuring=Setting up CoolBoost automation...
ptbr.Configuring=Configurando a automação do CoolBoost...
en.NotSupported=This laptop doesn't expose Acer's CoolBoost control (WMI class APGeAction), so CoolBoost Auto can't work here.%n%nIt is made for Acer Nitro / Predator laptops. Setup will now exit without changing anything.
ptbr.NotSupported=Este notebook não oferece o controle de CoolBoost da Acer (classe WMI APGeAction), então o CoolBoost Auto não funciona aqui.%n%nEle foi feito para notebooks Acer Nitro / Predator. A instalação vai ser encerrada sem alterar nada.
en.NoNitroSense=NitroSense doesn't seem to be installed.%n%nInstall NitroSense (Microsoft Store or Acer support) first, then run this setup again.
ptbr.NoNitroSense=O NitroSense não parece estar instalado.%n%nInstale o NitroSense (Microsoft Store ou suporte da Acer) e rode esta instalação de novo.
en.CheckFailed=The compatibility check could not run (code %1). Setup will exit.
ptbr.CheckFailed=Não foi possível verificar a compatibilidade (código %1). A instalação será encerrada.
en.InstallFailed=Setting up the automation failed (code %1).%n%nDetails are in:%n%2
ptbr.InstallFailed=A configuração da automação falhou (código %1).%n%nDetalhes em:%n%2

[Tasks]
Name: "autostart"; Description: "{cm:AutoStart}"

[Files]
Source: "..\install.ps1";   DestDir: "{app}"; Flags: ignoreversion
Source: "..\uninstall.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\*";         DestDir: "{app}\src";    Flags: ignoreversion
Source: "..\assets\*";      DestDir: "{app}\assets"; Flags: ignoreversion
Source: "..\README.md";     DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.pt-BR.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE";       DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "{commonprograms}\CoolBoost Tray.lnk"; Description: "{cm:LaunchTray}"; Flags: postinstall nowait shellexec skipifsilent runasoriginaluser

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\uninstall.ps1"" -Quiet"; Flags: runhidden waituntilterminated; RunOnceId: "RemoveCoolBoostAuto"

[UninstallDelete]
Type: files; Name: "{app}\install.log"

[Code]
function SkipCheck(): Boolean;
var i: Integer;
begin
  Result := False;
  for i := 1 to ParamCount do
    if CompareText(ParamStr(i), '/SKIPCHECK') = 0 then Result := True;
end;

function PowerShell(const Args: String; var Code: Integer): Boolean;
begin
  Result := Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
                 '-NoProfile -ExecutionPolicy Bypass ' + Args, '', SW_HIDE, ewWaitUntilTerminated, Code);
end;

// Refuse to install on laptops without the CoolBoost interface, before anything is copied.
function InitializeSetup(): Boolean;
var Code: Integer;
begin
  Result := True;
  if SkipCheck() then Exit;
  ExtractTemporaryFile('install.ps1');
  if not PowerShell('-File "' + ExpandConstant('{tmp}\install.ps1') + '" -CheckOnly -Quiet', Code) then Code := -1;
  case Code of
    0: Result := True;
    2: begin SuppressibleMsgBox(CustomMessage('NotSupported'), mbCriticalError, MB_OK, IDOK); Result := False; end;
    3: begin SuppressibleMsgBox(CustomMessage('NoNitroSense'), mbError, MB_OK, IDOK); Result := False; end;
  else
    begin SuppressibleMsgBox(FmtMessage(CustomMessage('CheckFailed'), [IntToStr(Code)]), mbError, MB_OK, IDOK); Result := False; end;
  end;
end;

// After the files are in place, run the real setup (tasks, permissions, shortcuts).
procedure CurStepChanged(CurStep: TSetupStep);
var Code: Integer; Args, LogFile: String;
begin
  if CurStep = ssPostInstall then
  begin
    WizardForm.StatusLabel.Caption := CustomMessage('Configuring');
    LogFile := ExpandConstant('{app}\install.log');
    Args := '-File "' + ExpandConstant('{app}\install.ps1') + '" -Quiet -NoStartTray -LogPath "' + LogFile + '"';
    if not WizardIsTaskSelected('autostart') then Args := Args + ' -NoAutostart';
    if SkipCheck() then Args := Args + ' -Force';
    if (not PowerShell(Args, Code)) or (Code <> 0) then
      SuppressibleMsgBox(FmtMessage(CustomMessage('InstallFailed'), [IntToStr(Code), LogFile]), mbError, MB_OK, IDOK);
  end;
end;
