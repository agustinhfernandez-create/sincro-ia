<#
=====================================================================
 Sincro IA - bootstrap.ps1
 Instalador del entorno (sin IA). Ejecuta las FASES 0 a 5.
 La inteligencia (Claude) recien arranca DESPUES, ya instalado.

 Lo llama el wizard de Inno Setup pasando la licencia y la Gemini key.
 Uso manual (pruebas):
   powershell -ExecutionPolicy Bypass -File bootstrap.ps1 `
     -LicenseKey "XXXX-XXXX" -GeminiKey "AIza..." -TemplateDir ".\plantilla"
=====================================================================
#>

param(
    [Parameter(Mandatory = $true)]  [string] $LicenseKey,
    [Parameter(Mandatory = $false)] [string] $GeminiKey  = "",
    # Carpeta donde Inno Setup descomprimio la plantilla Capa B
    [Parameter(Mandatory = $false)] [string] $TemplateDir = "$PSScriptRoot\plantilla",
    # Destino del entorno (carpeta del usuario, sin admin)
    [Parameter(Mandatory = $false)] [string] $InstallDir  = "$env:USERPROFILE\SincroIA",
    # URL del Worker de licencias (Cloudflare). Se completa al desplegar el Worker.
    [Parameter(Mandatory = $false)] [string] $LicenseApi  = "https://sincro-ia-licencias.agustinhfernandez.workers.dev"
)

# Continue: ningun hipo de un prerrequisito debe abortar todo el instalador.
# Los errores criticos se manejan explicitamente con Die.
$ErrorActionPreference = "Continue"
$LogFile = "$env:TEMP\sincro-ia-install.log"

# --------------------------------------------------------------------
# Helpers de log
# --------------------------------------------------------------------
function Write-Step($msg)  { Write-Host "`n=== $msg ===" -ForegroundColor Cyan;  Add-Content $LogFile "=== $msg ===" }
function Write-Ok($msg)    { Write-Host "  [OK] $msg"   -ForegroundColor Green;  Add-Content $LogFile "[OK] $msg" }
function Write-Info($msg)  { Write-Host "  $msg";                                Add-Content $LogFile $msg }
function Write-Warn2($msg) { Write-Host "  [!] $msg"    -ForegroundColor Yellow; Add-Content $LogFile "[!] $msg" }
function Die($msg) {
    Write-Host "`n  [X] $msg" -ForegroundColor Red
    Add-Content $LogFile "[X] $msg"
    Write-Host "`nLog completo en: $LogFile" -ForegroundColor Red
    exit 1
}

# Refresca el PATH de la sesion combinando Maquina + Usuario (ve lo recien instalado)
function Update-Path {
    $m = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    $u = [System.Environment]::GetEnvironmentVariable("Path","User")
    $env:Path = (@($m,$u) | Where-Object { $_ }) -join ";"
}

# Comando REAL ignorando los stubs de Microsoft Store (solo se usa para Python)
function Get-RealCmd($name) {
    $cmds = Get-Command $name -All -ErrorAction SilentlyContinue
    foreach ($c in $cmds) {
        $src = $c.Source
        if ($src -and ($src -notlike "*WindowsApps*")) { return $c }
    }
    return $null
}

# ¿Existe un comando? (incluye winget, que vive en WindowsApps)
function Test-Cmd($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# Devuelve la version mayor de un comando tipo "node --version" -> 20 (-1 si no existe)
function Get-MajorVersion($cmd, $arg = "--version") {
    if (-not (Test-Cmd $cmd)) { return -1 }
    try {
        $out = & $cmd $arg 2>$null
        if ($out -match "(\d+)\.(\d+)") { return [int]$Matches[1] }
    } catch {}
    return -1
}

# Instala via winget si esta disponible; refresca PATH y RE-VERIFICA con $checkCmd.
# winget devuelve codigos != 0 aunque el paquete ya este instalado ("no update"),
# por eso confiamos en la re-verificacion del comando, no en el exit code.
function Install-Pkg($wingetId, $nombre, $checkCmd, $urlFallback) {
    if (Test-Cmd "winget") {
        Write-Info "Instalando $nombre via winget ($wingetId)..."
        cmd /c "winget install --id $wingetId --silent --accept-package-agreements --accept-source-agreements --disable-interactivity" 2>&1 | Out-Null
        Update-Path
        if (Test-Cmd $checkCmd) { Write-Ok "$nombre disponible"; return $true }
        Write-Warn2 "winget no dejo $nombre disponible (codigo $LASTEXITCODE)."
    } else {
        Write-Warn2 "winget no disponible."
    }
    Write-Warn2 "Instala $nombre manualmente desde: $urlFallback"
    return $false
}

# --------------------------------------------------------------------
Set-Content $LogFile "Sincro IA - instalacion $(Get-Date)"
Write-Host "`n###############################################" -ForegroundColor White
Write-Host "#         Sincro IA - Instalador              #" -ForegroundColor White
Write-Host "###############################################"

# ====================================================================
# FASE -1 : Validar licencia con nuestro Worker (GATE - antes de instalar)
# ====================================================================
Write-Step "Validando licencia"
# machine_id estable por PC (ata la licencia a esta maquina)
$MachineId = (Get-CimInstance Win32_ComputerSystemProduct).UUID
try {
    $headers = @{ "Content-Type" = "application/json" }
    $body    = @{ license_key = $LicenseKey; machine_id = $MachineId } | ConvertTo-Json
    $resp = Invoke-RestMethod -Uri "$LicenseApi/validate" `
                              -Method Post -Headers $headers -Body $body -ErrorAction Stop
    if (-not $resp.valid) {
        Die "Licencia invalida ($($resp.reason)). Verifica tu clave de compra."
    }
    Write-Ok "Licencia valida"
} catch {
    Die "No se pudo validar la licencia (revisa tu conexion a internet). Detalle: $($_.Exception.Message)"
}

# ====================================================================
# FASE 0 : Prerrequisitos (detectar + instalar lo que falte)
# ====================================================================
Write-Step "FASE 0 - Prerrequisitos"

# Refrescar PATH primero: algo puede estar ya instalado pero fuera del PATH heredado
Update-Path

# Detecta Python valido (>=3.10) ignorando el stub de Microsoft Store. Prueba 'python' y 'py'.
function Test-Python {
    foreach ($name in @("python","py")) {
        $real = Get-RealCmd $name
        if ($real) {
            try {
                $v = & $real.Source --version 2>&1
                if ($v -match "Python 3\.(\d+)" -and [int]$Matches[1] -ge 10) { return $true }
            } catch {}
        }
    }
    return $false
}

# Node.js >= 18
if ((Get-MajorVersion "node") -ge 18) { Write-Ok "Node.js presente" }
else { Install-Pkg "OpenJS.NodeJS.LTS" "Node.js LTS" "node" "https://nodejs.org" | Out-Null }

# Python >= 3.10
if (Test-Python) { Write-Ok "Python presente" }
else {
    if (Install-Pkg "Python.Python.3.12" "Python 3.12" "python" "https://www.python.org/downloads/") {}
    elseif (Test-Python) { Write-Ok "Python presente" }
}

# git
if (Test-Cmd "git") { Write-Ok "git presente" }
else { Install-Pkg "Git.Git" "git" "git" "https://git-scm.com/download/win" | Out-Null }

# VSCode
if (Test-Cmd "code") { Write-Ok "VSCode presente" }
else { Install-Pkg "Microsoft.VisualStudioCode" "VSCode" "code" "https://code.visualstudio.com" | Out-Null }

Update-Path

# Extension de Claude Code para VSCode (deja la IA integrada en el editor)
if (Test-Cmd "code") {
    Write-Info "Instalando extension de Claude en VSCode..."
    cmd /c "code --install-extension anthropic.claude-code --force" 2>&1 | Out-Null
    Write-Ok "Extension de Claude en VSCode"
}

# uv (gestor de paquetes Python, para graphify y notebooklm-py)
if (Test-Cmd "uv") { Write-Ok "uv presente" }
else {
    Write-Info "Instalando uv..."
    try { Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression; Update-Path } catch {}
    if (Test-Cmd "uv") { Write-Ok "uv instalado" } else { Write-Warn2 "No se pudo instalar uv: https://docs.astral.sh/uv/" }
}

# Claude Code CLI (npm global)
if (Test-Cmd "claude") { Write-Ok "Claude Code presente" }
else {
    Write-Info "Instalando Claude Code CLI..."
    if (Test-Cmd "npm") {
        cmd /c "npm install -g @anthropic-ai/claude-code" 2>&1 | Out-Null; Update-Path
        if (Test-Cmd "claude") { Write-Ok "Claude Code instalado" } else { Write-Warn2 "No se pudo instalar Claude Code CLI." }
    } else { Write-Warn2 "npm no disponible (falta Node). Claude Code no instalado." }
}

Update-Path

# ====================================================================
# FASE 1 : Graphify + NotebookLM (Python / uv) - independientes
# ====================================================================
Write-Step "FASE 1 - Graphify + NotebookLM"
try { uv tool install graphifyy            | Out-Null; Write-Ok "Graphify instalado" }
catch { Write-Warn2 "Graphify fallo: $($_.Exception.Message)" }
try { uv tool install "notebooklm-py[browser]" | Out-Null; Write-Ok "notebooklm-py instalado" }
catch { Write-Warn2 "notebooklm-py fallo: $($_.Exception.Message)" }

# ====================================================================
# FASE 2 : Ruflo (genera base .claude/ + MCP)
# ====================================================================
Write-Step "FASE 2 - Ruflo"
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null }
Push-Location $InstallDir
try {
    npm install -g ruflo@latest | Out-Null
    npx -y ruflo@latest init    | Out-Null
    Write-Ok "Ruflo instalado e inicializado en $InstallDir"
} catch { Write-Warn2 "Ruflo fallo: $($_.Exception.Message)" }
Pop-Location

# ====================================================================
# FASE 3 : GSD (open-gsd) - runtime Claude Code, no-interactivo
#   Flags: --claude (runtime) --local (instala en el dir actual)
# ====================================================================
Write-Step "FASE 3 - GSD"
Push-Location $InstallDir
try { cmd /c "npx -y @opengsd/gsd-core@latest --claude --local <nul" 2>&1 | Out-Null; Write-Ok "GSD instalado" }
catch { Write-Warn2 "GSD fallo: $($_.Exception.Message)" }
Pop-Location

# ====================================================================
# FASE 4 : Matt Pocock skills
# ====================================================================
Write-Step "FASE 4 - Matt Pocock skills"
Push-Location $InstallDir
# -y (sin prompts) -a * (todos los agentes) -s * (todas las skills)
try { cmd /c "npx -y skills@latest add mattpocock/skills -y -a * -s * <nul" 2>&1 | Out-Null; Write-Ok "Skills de Matt Pocock instaladas" }
catch { Write-Warn2 "matpocock skills fallo: $($_.Exception.Message)" }
Pop-Location

# ====================================================================
# FASE 5 : Desplegar Capa B + escribir .env
# ====================================================================
Write-Step "FASE 5 - Andamiaje Sincro IA (Capa B)"
if (-not (Test-Path $TemplateDir)) { Die "No se encontro la plantilla Capa B en $TemplateDir" }

# Copiar la plantilla encima (CLAUDE.md de Sincro manda; sobreescribe el de Ruflo)
Copy-Item -Path "$TemplateDir\*" -Destination $InstallDir -Recurse -Force
Write-Ok "Capa B desplegada (CLAUDE.md, .mcp.json, scripts, skills propias)"

# Limpiar la carpeta temporal de la plantilla si quedo dentro del InstallDir
if ($TemplateDir -like "$InstallDir*" -and (Test-Path $TemplateDir)) {
    Remove-Item -Path $TemplateDir -Recurse -Force -ErrorAction SilentlyContinue
}

# Carpeta de proyectos del usuario
$proyectos = Join-Path $InstallDir "Workspace\Proyectos"
if (-not (Test-Path $proyectos)) { New-Item -ItemType Directory -Force -Path $proyectos | Out-Null }

# Escribir .env (Gemini key; la licencia queda registrada)
$envPath = Join-Path $InstallDir ".env"
$envLines = @(
    "# Sincro IA - credenciales locales (NO compartir, NO commitear)",
    "GEMINI_API_KEY=$GeminiKey",
    "LICENSE_KEY=$LicenseKey"
)
Set-Content -Path $envPath -Value $envLines -Encoding UTF8
Write-Ok ".env escrito en $envPath"

# ====================================================================
# Cierre : instrucciones de primer arranque guiado
# ====================================================================
Write-Step "Instalacion completa"
Write-Host @"

  Sincro IA quedo instalado en:
    $InstallDir

  PRIMER ARRANQUE (pasos que requieren tu navegador):
    1) Abri una consola en esa carpeta (o abri VSCode ahi).
    2) Ejecuta:  claude          -> inicia sesion con tu cuenta de Anthropic.
    3) Ejecuta:  notebooklm login -> inicia sesion en NotebookLM (se abre el navegador).
    4) Listo. Escribi en Claude:  "lee CLAUDE.md y arranca".

  Tu API key de Gemini ya quedo guardada. Internet es obligatorio para usar el entorno.
  Log de instalacion: $LogFile
"@ -ForegroundColor White

exit 0
