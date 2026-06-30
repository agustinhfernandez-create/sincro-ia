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

## 2026-06-29 · Instalador: el reintento sin flag de winget NO alcanzó (winget roto)
- **Update:** el reintento sin flag NO alcanzó (winget roto/desactualizado del todo en esa máquina, o se corrió el .exe viejo). Solución definitiva: **fallback de descarga directa sin winget** en `bootstrap.ps1` — `Install-NodeDirect` (MSI oficial nodejs.org v20.18.1, msiexec /qn, con TLS1.2 forzado) e `Install-GitDirect` (Git for Windows silencioso). Se llaman si `Install-Pkg` (winget) falla. .exe recompilado. Links manuales: Node `https://nodejs.org/dist/v20.18.1/node-v20.18.1-x64.msi`, Git `https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe`.
