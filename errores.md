# Errores Aprendidos — Sincro IA

Registro de errores y sus soluciones. Formato: fecha · síntoma · causa · solución.

---

## 2026-06-25 · Ruflo: store falla con UNIQUE constraint pero delete/retrieve dicen "Key not found"
- **Síntoma:** `claude-flow memory store --key project-status --namespace sincro-ia` → `[ERROR] UNIQUE constraint failed: memory_entries.namespace, memory_entries.key`, mientras `delete` y `retrieve` de la misma key responden `Key not found`.
- **Contexto:** ocurrió tras desconectarse el MCP de claude-flow (sesión resume). La entry existe físicamente pero los lectores no la ven (índice/db sql.js en estado inconsistente).
- **Workaround usado:** guardar con key fechada `project-status-20260625`.
- **Prevención:** la fuente de verdad es siempre los archivos del proyecto (MEMORY_PROYECTO.md, hitos.md, CONTEXT.md, ADRs), no Ruflo. Ruflo es secundario. Si vuelve a pasar, considerar limpiar/reindexar la db de Ruflo.

---

## 2026-06-29 · Instalador: winget falla en notebook vieja con código -1978335230
- **Síntoma:** en una notebook vieja, el instalador no instala Node/git/VSCode. winget devuelve `-1978335230` para los tres; npm queda ausente → Claude Code y Ruflo no se instalan. Python pasó porque ya estaba instalado.
- **Causa:** `-1978335230` = `0x8A150002` = winget `INVALID_CL_ARGUMENTS`. El flag `--disable-interactivity` solo existe en winget ≥ 1.4; el winget viejo del notebook lo rechaza y aborta TODO install. Python no lo instaló winget (re-verificación encontró el ya presente).
- **Solución:** en `bootstrap.ps1` (Install-Pkg), si `$LASTEXITCODE -eq -1978335230` reintentar el `winget install` sin `--disable-interactivity`. .exe recompilado con ISCC.
- **Arreglo manual del notebook afectado:** instalar Node LTS/git/VSCode a mano, reabrir terminal, `npm install -g @anthropic-ai/claude-code` y `npm install -g ruflo@latest`. El resto (Graphify, NotebookLM, GSD, Capa B) ya quedó instalado.
## 2026-06-29 · Instalador: `ruflo init` cuelga la instalación (espera stdin)
- **Síntoma:** FASE 2 se clava después de `npm install -g ruflo`; no avanza.
- **Causa:** `npx -y ruflo@latest init` espera entrada por stdin (a diferencia de GSD/Matt Pocock que ya usaban `<nul`). Sin stdin redirigido, queda colgado para siempre.
- **Solución:** en `bootstrap.ps1` FASE 2: `npm install` con `<nul`; `ruflo init` vía `Start-Process cmd /c "... <nul"` con `WaitForExit(120000)` — si se pasa de 120s lo mata y sigue (Ruflo es secundario). .exe recompilado.

---

## 2026-06-30 · Instalador Linux (install.sh): .mcp.json Windows-only + PATH en SSH
- **Contexto:** montar el entorno en notebook Linux Mint 22 para usarla de servidor (Remote-SSH / code tunnel).
- **Problema 1 — .mcp.json:** la plantilla trae `"command":"cmd","/c","npx",...` (Windows). En Linux/macOS los MCP (claude-flow, ruv-swarm, flow-nexus) no arrancan.
  - **Solución:** `install.sh` FASE 5 reescribe `.mcp.json` con `"command":"npx"` directo tras copiar la plantilla. La plantilla Windows queda intacta.
- **Problema 2 — PATH en sesiones SSH no-interactivas:** node/npm (nvm), `claude`, `claude-flow`, `uv`, `graphify` viven en `~/.nvm` y `~/.local/bin`; un shell SSH no-interactivo o el que spawnea `code tunnel`/MCP no los carga → "command not found".
  - **Solución:** FASE 6 nueva persiste un snippet PATH idempotente en `~/.bashrc` y `~/.profile` (nvm + `~/.local/bin` + `~/.cargo/bin`). FASE 7 verifica node/npm/claude/claude-flow/uv/graphify/notebooklm/code/git.
- **Ojo herramientas:** `claude-flow` NO se instala aparte — lo provee `ruflo` (igual que en Windows). `notebooklm-py[browser]` usa Playwright/Chromium: en Linux puede pedir libs del sistema y `notebooklm login` requiere GUI (Mint la tiene). Mint 22 = base Ubuntu 24.04 → `apt`, soportado por install.sh.
- **Problema 3 — plantilla no encontrada:** por `git clone` la plantilla está en `sincro-ia/plantilla` (hermana de `instalador/`), no en `instalador/plantilla`. FASE 5 abortaba. Fix: `TEMPLATE_DIR` ahora prueba `$SCRIPT_DIR/plantilla` y cae a `$SCRIPT_DIR/../plantilla`.
- **Problema 4 — EACCES en `npm install -g` (el más común en Linux):** si node viene de apt, el prefix global es `/usr` → sin sudo da `EACCES mkdir /usr/lib/node_modules`. Claude Code y el `ruflo` global fallaban silenciosos (el script imprimía OK igual). Fix: FASE 0 detecta prefix no-escribible y lo redirige a `~/.npm-global` + PATH. Manual: `npm config set prefix ~/.npm-global` y agregar `~/.npm-global/bin` al PATH.
- **Problema 5 — `claude-flow` no se instalaba:** el comando `claude-flow` que usa CLAUDE.md lo da el paquete npm `claude-flow@alpha`, NO `ruflo` (asunción vieja: ruflo no provee ese binario). Fix: FASE 0 instala `claude-flow@alpha` global aparte de ruflo. `~/.npm-global/bin` sumado al PATH persistente de FASE 6.
- **Verificado en Mint 22 (2026-07-01):** instalación OK salvo estos 5; tras los fixes las 9 herramientas verdes. `ruflo init` puede devolver código 1 (no crítico, Ruflo es secundario). VSCode/sshd/graphify/notebooklm/uv/code sin problemas por SSH; `notebooklm login` requiere GUI (no por SSH).

---

## 2026-06-29 · Instalador: el reintento sin flag de winget NO alcanzó (winget roto)
- **Update:** el reintento sin flag NO alcanzó (winget roto/desactualizado del todo en esa máquina, o se corrió el .exe viejo). Solución definitiva: **fallback de descarga directa sin winget** en `bootstrap.ps1` — `Install-NodeDirect` (MSI oficial nodejs.org v20.18.1, msiexec /qn, con TLS1.2 forzado) e `Install-GitDirect` (Git for Windows silencioso). Se llaman si `Install-Pkg` (winget) falla. .exe recompilado. Links manuales: Node `https://nodejs.org/dist/v20.18.1/node-v20.18.1-x64.msi`, Git `https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe`.
