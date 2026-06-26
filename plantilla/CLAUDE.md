# Sincro IA — Entorno de Orquestación con Claude

> Claude es el **orquestador** de tu trabajo. Se apoya en cinco herramientas
> (Ruflo, Graphify, Gemini, NotebookLM, GSD/skills) y en la memoria de tus proyectos.
> Este archivo es el manual que Claude lee al arrancar **cada** sesión. No hace falta
> que lo edites a mano: se va completando solo a medida que creás proyectos.

---

## 🚦 REGLAS NO NEGOCIABLES — LEER PRIMERO

> Se cumplen SIEMPRE, sin excepción y sin que el usuario lo pida.

### Requisito base
- **Internet obligatorio.** El razonamiento (Claude, Gemini, NotebookLM) ocurre en la nube.
  Sin conexión, el entorno no funciona.
- **Login (Opción A).** Al abrir la consola, ejecutar `claude` e iniciar sesión con tu
  **cuenta de Anthropic** (suscripción Claude). Cada usuario usa su propia cuenta.

### Arranque obligatorio (en CADA sesión, antes de hacer nada)
1. **Preguntar el proyecto** (mostrar la lista de proyectos activos de la tabla de abajo).
2. **Ruflo** → `claude-flow memory retrieve --key "project-status" --namespace <proyecto>`.
   Si `Key not found` → protocolo proyecto nuevo (skill `/nuevo-proyecto`).
3. **Graphify** → leer `Workspace/Proyectos/<proyecto>/graphify-out/GRAPH_REPORT.md`.
   Si NO existe → generarlo. Todos los proyectos deben tener grafo.
4. **Gemini (auxiliar de tokens)** → ante cualquier análisis amplio o lectura pesada,
   consultar a Gemini ANTES de gastar tokens leyendo archivos.
5. **NotebookLM** → solo si se van a consultar documentos externos.
6. **Confirmar contexto cargado** con el resumen ✓ y recién ahí trabajar.

### Durante el trabajo (skills obligatorias)
- **`/grill-with-docs` ANTES de implementar cualquier cambio no trivial.** Es BLOQUEANTE.
- **`/tdd`** al escribir código nuevo o corregir bugs (prueba que falla primero).
- **`/diagnose`** para bugs — seguir el bucle, no debug ad-hoc.
- **`/zoom-out`** antes de tocar un módulo que no se tocó en la sesión.

### Cierre obligatorio (antes de terminar o con poco cupo)
1. Actualizar `hitos.md` del proyecto.
2. `claude-flow memory store --key "project-status" --namespace <proyecto>`
   (si la key existe, `memory delete` y luego `store` — no hay `update`).
3. Asegurar que `MEMORY_PROYECTO.md` / `errores.md` reflejen la realidad.

### Reglas de oro
- **Ruflo CLI:** usar `claude-flow` (instalado global). NUNCA `npx claude-flow`.
- **Hacer lo pedido, nada más.** No crear archivos ni docs salvo necesidad real. Nada en la raíz.
- **Nunca** commitear secretos ni `.env`.

---

## 🗂️ Tus proyectos

> Esta tabla arranca vacía. Cada vez que usás `/nuevo-proyecto`, se agrega una fila acá,
> se crea su carpeta en `Workspace/Proyectos/` y se registra su namespace en Ruflo.

| Proyecto | Path | Namespace Ruflo | Stack |
|----------|------|-----------------|-------|
| _(sin proyectos todavía — usá `/nuevo-proyecto` para crear el primero)_ | | | |

### Notebooks NotebookLM por proyecto

> Se completa a medida que conectás cuadernos de NotebookLM a tus proyectos.

| Proyecto | Notebook ID | Para qué usarlo |
|----------|-------------|-----------------|
| _(ninguno todavía)_ | | |

---

## 🧰 Las cinco herramientas

| Herramienta | Qué responde | Cuándo usarla |
|-------------|-------------|---------------|
| **Ruflo** | Decisiones técnicas, hitos, errores de sesiones anteriores | SIEMPRE al inicio — es la memoria del proyecto |
| **Graphify** | Mapa de dependencias: qué tablas/endpoints/componentes se relacionan | ANTES de tocar código — leer `graphify-out/GRAPH_REPORT.md` |
| **Gemini** | Análisis amplios, resúmenes de arquitectura, validaciones | Para ahorrar tokens antes de leer muchos archivos |
| **NotebookLM** | Documentos externos: PDFs, specs, APIs de terceros | Cuando la respuesta no está en el código ni en Ruflo |
| **GSD + skills** | Flujos de trabajo (grill, tdd, diagnose, handoff, etc.) | Durante el desarrollo, según el disparador de cada skill |

### Configuración de credenciales (BYOK)

Tus claves viven en el archivo `.env` de la raíz (nunca se comparten, nunca se commitean):

```
ANTHROPIC_API_KEY=      # opcional si usás login con cuenta (Opción A)
GEMINI_API_KEY=         # tu API key de Google Gemini
```

- **Claude:** login con cuenta (`claude`) — Opción A.
- **Gemini:** API key en `.env`.
- **NotebookLM:** login por browser con `notebooklm login` (herramienta notebooklm-py).
  Refrescar la sesión con `notebooklm auth refresh` cuando expire.

### ⚙️ Ruflo CLI — REGLA GLOBAL

> **`claude-flow` está instalado globalmente. NUNCA usar `npx claude-flow`.**

```bash
claude-flow memory store --key "X" --value "Y" --namespace Z
claude-flow memory retrieve --key "X" --namespace Z
claude-flow memory search --query "X" --namespace Z
```

### 🗺️ Graphify — Mapa de dependencias

```bash
graphify query "qué tablas usa el módulo de ventas"   # búsqueda semántica
graphify path "tabla_ventas" "endpoint_reportes"      # camino entre nodos
graphify explain "ComponenteX"                         # explicar un componente
graphify update Workspace/Proyectos/<proyecto>         # actualizar grafo (sin costo de API)
```

> Nota: extraer SIEMPRE con `--no-cluster` (workaround de un bug conocido de dedup).
> En Windows usar `graphify .` (sin slash inicial). Los comandos query/path/explain se
> ejecutan DESDE el directorio del proyecto (buscan `./graphify-out/graph.json`).

### 🤖 Gemini — Auxiliar para ahorrar tokens

```bash
node scripts/gemini/gemini-client.js <Proyecto> "Resumen de arquitectura y errores recientes"
```

Delegale a Gemini análisis amplios y razonamiento sobre `MEMORY_PROYECTO.md` + `errores.md`
ANTES de gastar tokens de Claude leyendo muchos archivos.

### 📓 NotebookLM — Documentos externos

```bash
notebooklm login                 # iniciar sesión (browser)
notebooklm auth refresh          # renovar sesión cuando expire
# Consultar un cuaderno desde Claude vía el MCP server de notebooklm-py
```

---

## 🚀 PROTOCOLO DE INICIO — OBLIGATORIO EN CADA SESIÓN

Al comenzar CUALQUIER conversación, ejecutar esto SIN que el usuario lo pida:

**PASO 1 — Preguntar en qué proyecto trabajamos** (listar la tabla de proyectos).

**PASO 2 — Recuperar memoria de Ruflo:**
```bash
claude-flow memory retrieve --key "project-status" --namespace <namespace>
```
- Si devuelve datos → proyecto existente, usar ese contexto.
- Si devuelve `Key not found` → **proyecto nuevo** → `/nuevo-proyecto`.

**PASO 3 — Graphify** (leer `graphify-out/GRAPH_REPORT.md`; si no existe, generarlo).

**PASO 4 — Gemini** (resumen de arquitectura/errores para ahorrar tokens, si aplica).

**PASO 5 — NotebookLM** (solo si se consultan docs externos; verificar sesión activa).

**PASO 6 — Confirmar contexto cargado:**
```
🧠 Contexto de [PROYECTO] cargado.
   Ruflo       ✓ — project-status recuperado
   Graphify    ✓ / ⚠️  — [grafo leído | proyecto sin grafo]
   Gemini      ✓ — validación de stack (si aplica)
   NotebookLM  ✓ / ⚠️  — [activa | sesión expirada]
Listo para trabajar. ¿Qué hacemos?
```

---

## 🆕 PROTOCOLO PARA PROYECTO NUEVO

Si Ruflo devuelve `Key not found`, es un proyecto nuevo. Usar la skill `/nuevo-proyecto`,
que hace la entrevista completa y al final:

1. Crea `Workspace/Proyectos/<NOMBRE>/` con `MEMORY_PROYECTO.md`, `errores.md`, `hitos.md`, `DISEÑO.md`.
2. Registra en Ruflo: `claude-flow memory store --key "project-status" --namespace <nombre>`.
3. Agrega la fila a la tabla de proyectos de este CLAUDE.md.
4. Crea `.env.example` si hay APIs externas.

---

## 🛠️ Skills obligatorias

Parte del flujo de trabajo estándar, no opcionales. Usar automáticamente según el disparador.

| Skill | Disparador obligatorio | Qué hace |
|-------|----------------------|----------|
| `/grill-with-docs` | ANTES de implementar cualquier feature o cambio de arquitectura | Interroga el plan, construye vocabulario compartido, actualiza ADRs |
| `/grill-me` | Cuando el pedido del usuario es vago o ambiguo | Entrevista profunda hasta resolver las decisiones |
| `/tdd` | Al escribir código nuevo o corregir bugs | Ciclo rojo-verde-refactor; primero la prueba que falla |
| `/diagnose` | Ante cualquier error difícil de reproducir o regresión | Bucle: reproducir → minimizar → hipótesis → instrumentar → corregir |
| `/zoom-out` | Antes de tocar un módulo desconocido o complejo | Explica el componente en el contexto del sistema completo |
| `/nuevo-proyecto` | Cuando el usuario quiere crear un proyecto nuevo | Entrevista de descubrimiento + crea estructura + actualiza CLAUDE.md |
| `/handoff` | Al acercarse al límite de contexto o cambiar de sesión | Condensa la conversación en un documento de traspaso |

- **`/grill-with-docs` es BLOQUEANTE** — no se escribe código hasta completar el interrogatorio.
- **`/tdd` es el modo por defecto** para toda escritura de código.
- **`/diagnose`** reemplaza al debug ad-hoc.
- **`/zoom-out`** es obligatorio antes de modificar un módulo no tocado en la sesión.

---

## Behavioral Rules (Always Enforced)

- Do what has been asked; nothing more, nothing less.
- NEVER create files unless they're absolutely necessary for achieving your goal.
- ALWAYS prefer editing an existing file to creating a new one.
- NEVER proactively create documentation files (*.md) unless explicitly requested.
- NEVER save working files or tests to the root folder.
- ALWAYS read a file before editing it.
- NEVER commit secrets, credentials, or .env files.
- ALWAYS use `/grill-with-docs` or `/grill-me` before implementing.
- ALWAYS use `/tdd` when writing new code.
- ALWAYS use `/diagnose` for bugs.

## File Organization

- NEVER save to root folder.
- `/src` código fuente · `/tests` pruebas · `/docs` documentación · `/config` configuración ·
  `/scripts` utilidades · `Workspace/Proyectos/` tus proyectos.

## Cierre de sesión

Antes de terminar o al detectar poco cupo de mensajes:
1. Actualizar `hitos.md` del proyecto.
2. `claude-flow memory store --key "project-status" --value "Resumen al YYYY-MM-DD: ..." --namespace <proyecto>`.
3. Asegurar que `MEMORY_PROYECTO.md` refleje la realidad del código.
