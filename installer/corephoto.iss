; CorePhoto-Setup — Inno Setup 6. Single Setup.exe berisi:
;   CorePhoto.exe (Flutter) + core_service.exe (Python frozen) + data/
; Build dahulu (lihat BUILD.md), lalu: iscc installer\corephoto.iss
#define AppName "Core Photo"
#define AppVersion "0.1.0"
#define AppExe "CorePhoto.exe"
#define SidecarExe "core_service.exe"

[Setup]
AppId={{3F2A1B9C-7D4E-4A6B-9C1D-5E8F0A2B4C6D}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\CorePhoto
DefaultGroupName={#AppName}
OutputDir=..\installer\Output
OutputBaseFilename=CorePhoto-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#AppName}
; Runtime tanpa admin: DB/log/token/foto di %LOCALAPPDATA% + Documents (dibuat aplikasi).

[Files]
Source: "apps\\flutter_app\\build\\windows\\x64\\runner\\Release\\core_photo.exe"; DestDir: "{app}"; DestName: "{#AppExe}"; Flags: ignoreversion
Source: "apps\\flutter_app\\build\\windows\\x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "core_photo.exe"
Source: "dist\\core_service.exe"; DestDir: "{app}"; DestName: "{#SidecarExe}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Buat ikon Desktop"; Flags: unchecked

[Run]
Filename: "{app}\{#AppExe}"; Description: "Jalankan {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Data pengguna (DB/foto/log) SENGAJA tidak dihapus — anti kehilangan data (PRD §17).
