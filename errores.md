# Errores Aprendidos — Sincro IA

Registro de errores y sus soluciones. Formato: fecha · síntoma · causa · solución.

---

## 2026-06-25 · Ruflo: store falla con UNIQUE constraint pero delete/retrieve dicen "Key not found"
- **Síntoma:** `claude-flow memory store --key project-status --namespace sincro-ia` → `[ERROR] UNIQUE constraint failed: memory_entries.namespace, memory_entries.key`, mientras `delete` y `retrieve` de la misma key responden `Key not found`.
- **Contexto:** ocurrió tras desconectarse el MCP de claude-flow (sesión resume). La entry existe físicamente pero los lectores no la ven (índice/db sql.js en estado inconsistente).
- **Workaround usado:** guardar con key fechada `project-status-20260625`.
- **Prevención:** la fuente de verdad es siempre los archivos del proyecto (MEMORY_PROYECTO.md, hitos.md, CONTEXT.md, ADRs), no Ruflo. Ruflo es secundario. Si vuelve a pasar, considerar limpiar/reindexar la db de Ruflo.
