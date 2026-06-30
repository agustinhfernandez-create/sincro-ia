# Instalador — Sincro IA

> **Dos instaladores, mismas fases:**
> - **Windows** → `bootstrap.ps1` (empaquetado en `SincroIA-Setup.exe` vía Inno Setup).
> - **Linux/macOS** → `install.sh` (bash). Ver sección *Linux/macOS* abajo.
> La **Capa B** (plantilla: `CLAUDE.md`, `.mcp.json`, scripts `.js`, skills) es la misma en ambos: es portable.

## Qué hay acá
- **`bootstrap.ps1`** — el cerebro del instalador (sin IA). Ejecuta las fases:
  - Valida licencia (Lemon Squeezy) como GATE antes de instalar nada.
  - FASE 0: detecta + instala prerrequisitos (Node, Python, git, VSCode, uv, Claude Code CLI) vía winget, con descarga directa como fallback.
  - FASE 1: Graphify (`graphifyy`) + notebooklm-py (uv).
  - FASE 2: Ruflo (`npm i -g` + `npx ruflo init`).
  - FASE 3: GSD (`npx @opengsd/gsd-core`).
  - FASE 4: Matt Pocock skills (`npx skills add`).
  - FASE 5: despliega la Capa B (plantilla) + escribe `.env`.
  - Cierre: instrucciones de **primer arranque guiado** (logins Claude + NotebookLM).

## Decisiones (grilling 2026-06-24)
- Instala en `C:\Users\<user>\SincroIA\` (sin admin).
- Prerrequisitos por detección de comandos (no IA) + winget/fallback.
- Licencia se valida **solo al instalar** (MVP), contra la API de Lemon Squeezy (ADR-0003).
- Wizard pide solo texto (licencia + Gemini key); los logins (Claude OAuth, NotebookLM browser) van al primer arranque guiado.

## Probar el bootstrap a mano (sin Inno Setup)
```powershell
powershell -ExecutionPolicy Bypass -File bootstrap.ps1 `
  -LicenseKey "TU-CLAVE" -GeminiKey "AIza..." `
  -TemplateDir "..\plantilla" -InstallDir "$env:USERPROFILE\SincroIA-test"
```

## Linux/macOS — `install.sh`
Espejo de `bootstrap.ps1` (mismas 8 fases + barra de progreso `[##--] %`). Diferencias por plataforma:
- **Node** vía `nvm` (sin root, multi-distro). **Python/git** vía gestor del sistema (apt/dnf/pacman/zypper/brew) con `sudo` si hace falta.
- **uv** vía `curl https://astral.sh/uv/install.sh`. **Claude Code/Ruflo/GSD/skills** igual que en Windows (`npm -g` / `npx`).
- **VSCode automático** (repo MS por distro, fallback snap) → da el CLI `code` + extensión de Claude.
- **sshd** instalado y habilitado, y lanzador `iniciar-tunnel.sh` (`code tunnel`) → **usar este equipo como servidor VSCode** por Remote-SSH o por túnel (https://vscode.dev).
- `ruflo init` con `timeout 120` (no se cuelga).
- Instala en `~/SincroIA`. `.env` con `chmod 600`.

```bash
chmod +x install.sh
./install.sh --license "TU-CLAVE" --gemini "AIza..."
# o:  LICENSE_KEY=... GEMINI_KEY=... ./install.sh   (si faltan, los pide interactivo)
```
Distribución: empaquetar `install.sh` + `plantilla/` en un `.tar.gz` (el script espera `./plantilla` al lado, o pasar `--template`).

## setup.iss (Inno Setup) — HECHO, falta compilar
`setup.iss` ya está. Empaqueta `bootstrap.ps1` + la carpeta `plantilla/`, muestra un wizard
(pide licencia + Gemini key), y al terminar corre `bootstrap.ps1` con esos datos.

Para generar el `.exe` (en tu PC):
1. Instalar Inno Setup: https://jrsoftware.org/isinfo.php
2. Antes de compilar, completar en `setup.iss` los placeholders `<<<`:
   - `MyLicenseApi` → URL del Worker (tras `wrangler deploy`).
   - `MyAppPublisher` → tu nombre/empresa.
   - (opcional) `SetupIconFile` → tu `.ico` cuando tengas logo.
3. Abrir `setup.iss` con Inno Setup Compiler → Build. Sale `SincroIA-Setup.exe`.

## Lo que FALTA
- **Deploy del Worker de licencias** (`../licencias-worker/`): KV, secrets MP, `wrangler deploy`.
- **Compilar el `.exe`** con Inno Setup (arriba).
- **Web de venta** (puede ser el storefront mínimo del Worker `/gracias` + una landing, o CF Pages).
- **Prueba en PC limpia** (riesgo #1: bootstrap frágil).
- Seguridad: validar firma del webhook de Mercado Pago.

## Riesgos abiertos
- winget ausente en Windows viejos → cae al fallback manual.
- GSD/Ruflo pueden ser interactivos → verificar que `npx ... | Out-Null` no se trabe; si piden input, pasar flags no-interactivos.
- SmartScreen en el `.exe` sin firmar.
