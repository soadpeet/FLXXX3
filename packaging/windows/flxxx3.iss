; AI disclaimer: this file was written autonomously by an AI agent (Claude).
;
; Inno Setup script of the Windows installer of FLXXX3. Built by tools/windows/make_installer.sh,
; which passes the version (from the Android manifest), the folder put together by
; stage_windows.py and the output folder:
;   ISCC.exe /DAppVersion=0.1.2 /DStageDir=... /DOutputDir=... flxxx3.iss
;
; Installs for the current user without administrator rights (%LOCALAPPDATA%\Programs\FLXXX3);
; an administrator can choose "for all users". The settings (%LOCALAPPDATA%\FLXXX3) stay when
; FLXXX3 is uninstalled, like on a reinstall.

#ifndef AppVersion
  #error AppVersion is missing (/DAppVersion=...)
#endif
#ifndef StageDir
  #error StageDir is missing (/DStageDir=...)
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

[Setup]
; The AppId must never change: Windows recognises an update of FLXXX3 by it.
AppId={{6F3C1B2E-8D4A-4C7B-9E21-5A0F7D3B9C64}
AppName=FLXXX3
AppVersion={#AppVersion}
AppVerName=FLXXX3 {#AppVersion}
AppPublisher=FLXXX3
AppPublisherURL=https://github.com/soadpeet/FLXXX3
AppSupportURL=https://github.com/soadpeet/FLXXX3/issues
AppUpdatesURL=https://github.com/soadpeet/FLXXX3/releases
DefaultDirName={autopf}\FLXXX3
DefaultGroupName=FLXXX3
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
LicenseFile=..\..\res\licenses\GPL-3.0.txt
SetupIconFile=flxxx3.ico
UninstallDisplayIcon={app}\flxxx3.ico
UninstallDisplayName=FLXXX3 {#AppVersion}
OutputDir={#OutputDir}
OutputBaseFilename=FLXXX3-v{#AppVersion}-windows-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; FLXXX3 must not run while it is updated.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; An update replaces the whole program folder: files of the old version that are gone in the
; new one must not stay behind.
Source: "{#StageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "flxxx3.ico"; DestDir: "{app}"; Flags: ignoreversion

; Only the folders and libraries FLXXX3 itself brings (never "{app}\*": the user may have
; chosen a folder with other files in it).
[InstallDelete]
Type: filesandordirs; Name: "{app}\Qt6"
Type: filesandordirs; Name: "{app}\qml"
Type: filesandordirs; Name: "{app}\controllers"
Type: filesandordirs; Name: "{app}\skins"
Type: files; Name: "{app}\*.dll"

[Icons]
Name: "{autoprograms}\FLXXX3"; Filename: "{app}\FLXXX3.exe"; WorkingDir: "{app}"; IconFilename: "{app}\flxxx3.ico"
Name: "{autodesktop}\FLXXX3"; Filename: "{app}\FLXXX3.exe"; WorkingDir: "{app}"; IconFilename: "{app}\flxxx3.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\FLXXX3.exe"; Description: "{cm:LaunchProgram,FLXXX3}"; Flags: nowait postinstall skipifsilent
