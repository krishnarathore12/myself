[Setup]
AppName=myself
AppVersion=1.0.0
DefaultDirName={autopf}\myself
DefaultGroupName=myself
OutputDir=.\Output
OutputBaseFilename=myself-setup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\myself"; Filename: "{app}\myself.exe"
Name: "{autodesktop}\myself"; Filename: "{app}\myself.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"
