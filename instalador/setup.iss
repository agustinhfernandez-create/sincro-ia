; =====================================================================
;  Sincro IA - setup.iss  (Inno Setup)
;  Wizard que pide licencia + Gemini key, empaqueta la plantilla (Capa B)
;  y el bootstrap, y al final corre bootstrap.ps1.
;
;  COMPILAR: abrir este archivo con Inno Setup Compiler (en tu PC) y Build.
;  Descarga Inno Setup: https://jrsoftware.org/isinfo.php
;
;  ANTES DE COMPILAR, completar los 3 placeholders marcados con  <<<:
;    1) MyLicenseApi  -> URL del Worker (wrangler deploy)
;    2) AppPublisher  -> tu nombre/empresa
;    3) (opcional) SetupIconFile -> tu .ico cuando tengas logo
; =====================================================================

#define MyAppName    "Sincro IA"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Sincro IA"          ; <<< 2) cambiar por tu nombre/empresa
#define MyLicenseApi "https://sincro-ia-licencias.TU-SUBDOMINIO.workers.dev"  ; <<< 1) URL del Worker

[Setup]
AppId={{B7E3B1C0-5A2D-4E9A-9C11-SINCROIA0001}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
; Instala en la carpeta del usuario (sin admin)
DefaultDirName={userpf}\SincroIA
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputBaseFilename=SincroIA-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; SetupIconFile=logo.ico                    ; <<< 3) descomentar cuando tengas el .ico

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Files]
; El motor del instalador
Source: "bootstrap.ps1"; DestDir: "{tmp}"; Flags: dontcopy
; La plantilla Capa B completa (se empaqueta y se descomprime al instalar)
Source: "..\plantilla\*"; DestDir: "{tmp}\plantilla"; Flags: recursesubdirs dontcopy

[Code]
var
  PageCreds: TInputQueryWizardPage;

procedure InitializeWizard;
begin
  // Pagina custom: pide licencia y Gemini key (solo texto; los logins van al primer arranque)
  PageCreds := CreateInputQueryPage(wpWelcome,
    'Credenciales', 'Cargá tus datos para activar Sincro IA',
    'La clave de licencia la recibiste al comprar. La API key de Gemini la sacás de ' +
    'Google AI Studio. Los inicios de sesión de Claude y NotebookLM se hacen después de instalar.');
  PageCreds.Add('Clave de licencia:', False);
  PageCreds.Add('API key de Gemini (opcional ahora):', False);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = PageCreds.ID then
  begin
    if Trim(PageCreds.Values[0]) = '' then
    begin
      MsgBox('Ingresá tu clave de licencia para continuar.', mbError, MB_OK);
      Result := False;
    end;
  end;
end;

// Extrae a {tmp} los archivos marcados dontcopy, antes de ejecutar el bootstrap
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  PsCmd: String;
begin
  if CurStep = ssPostInstall then
  begin
    ExtractTemporaryFile('bootstrap.ps1');
    ExtractTemporaryFiles('plantilla\*');

    // Llama al bootstrap con los datos del wizard
    PsCmd :=
      '-ExecutionPolicy Bypass -NoProfile -File "' + ExpandConstant('{tmp}\bootstrap.ps1') + '"' +
      ' -LicenseKey "'  + PageCreds.Values[0] + '"' +
      ' -GeminiKey "'   + PageCreds.Values[1] + '"' +
      ' -TemplateDir "' + ExpandConstant('{tmp}\plantilla') + '"' +
      ' -InstallDir "'  + ExpandConstant('{app}') + '"' +
      ' -LicenseApi "'  + '{#MyLicenseApi}' + '"';

    if not Exec('powershell.exe', PsCmd, '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then
      MsgBox('No se pudo iniciar la instalación del entorno.', mbError, MB_OK)
    else if ResultCode <> 0 then
      MsgBox('La instalación del entorno terminó con errores (código ' +
             IntToStr(ResultCode) + '). Revisá el log en %TEMP%\sincro-ia-install.log',
             mbError, MB_OK);
  end;
end;

[Run]
; Abre la carpeta del entorno al terminar
Filename: "{app}"; Description: "Abrir la carpeta de Sincro IA"; Flags: postinstall shellexec skipifsilent
