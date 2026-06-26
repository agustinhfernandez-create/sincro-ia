# Instalador — Sincro IA

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
