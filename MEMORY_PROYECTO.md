# MEMORY_PROYECTO — Sincro IA

## Qué es
Producto comercializable: un **instalador para Windows** que despliega un entorno completo de orquestación con IA donde **Claude es el orquestador**, asistido por **Ruflo**, **Graphify**, **Gemini** y **NotebookLM**. El usuario instala un ejecutable, carga sus propias API keys (BYOK) y obtiene el mismo entorno que ya usamos internamente en AsesorWeb.

## Propuesta de valor
"Instalá un ejecutable, cargá tus APIs, y tenés un entorno de orquestación IA profesional listo en minutos."

- Lo que se **comercializa es el entorno/configuración**, NO las herramientas de terceros.
- Las herramientas (Claude Code, Ruflo, Graphify, Gemini, NotebookLM) corren por fuera y las provee/paga cada usuario con sus propias claves.
- Si el usuario no adquiere/configura esas APIs, el entorno no funciona.

## Usuarios
- Emprendedores, devs y no-devs.
- Entorno **mono-usuario**, corre **en local**, sobre **Windows**.
- Todos los usuarios tienen el mismo rol (sin jerarquías).

## Modelo de negocio
- **Venta única** (no suscripción).
- Acceso controlado por **clave de licencia**.
- Infra objetivo: **$0/mes**.
- Distribución: **web de venta** → descarga de **ejecutable** que instala todo.

## Stack recomendado
| Pieza | Tecnología | Por qué |
|---|---|---|
| Instalador | **Inno Setup** + bootstrap PowerShell | Gratis, nativo Windows. Instala Node/Python/git, clona repos, corre `npm i`. Más liviano que Electron |
| Configuración de APIs | Páginas custom del wizard Inno Setup → escriben `.env`/settings | El usuario pega Claude key, Gemini key y cookies NotebookLM sin app aparte |
| Pago + licencias | **Mercado Pago + Worker propio** (ver ADR-0004; ADR-0003 Lemon descartado) | Pago único en pesos a cuenta MP. Validador propio en Cloudflare Workers+KV (infra $0): /crear-pago, /webhook, /gracias, /validate. Carpeta `licencias-worker/` |
| Web de venta | **Cloudflare Pages** estática (Astro/HTML), responsive | $0, rápida, desktop + mobile |

Descartado: Electron (pesado, innecesario), servidor de licencias propio (Lemon Squeezy ya lo da gratis).

## Arquitectura del entorno — DOS CAPAS (confirmado 2026-06-24)

El producto NO es "instalar 4 herramientas". "Que funcione como este entorno" exige replicar
el andamiaje propio (Capa B) encima de las herramientas oficiales (Capa A).

### Capa A — Herramientas de terceros (se instalan solas con su comando oficial)
NO se distribuyen ni se clonan-y-copian. El .exe corre el instalador oficial de cada una.
Generan: `.claude/agents/`, `.claude/commands/`, MCP servers, y skills (grill-with-docs, tdd,
diagnose, handoff, caveman, etc.).

| Herramienta | Repo | Runtime | Comando oficial |
|---|---|---|---|
| Ruflo | github.com/ruvnet/ruflo | Node | `npm i -g ruflo@latest` -> `npx ruflo init wizard` -> `claude mcp add ruflo` |
| Graphify | github.com/safishamsi/graphify | Python 3.10+ | `uv tool install graphifyy` (CLI=`graphify`) — independiente, no toca .claude |
| GSD | mudo a github.com/open-gsd/gsd-core | Node | `npx @opengsd/gsd-core@latest` (runtime=Claude Code; NO copiar files a mano) |
| Matt Pocock | github.com/mattpocock/skills | Node | `npx skills@latest add mattpocock/skills` -> `/setup-matt-pocock-skills` |
| NotebookLM | github.com/teng-lin/notebooklm-py | Python (uv) | `uv tool install "notebooklm-py[browser]"` -> `notebooklm login` (browser) + `notebooklm auth refresh` (keepalive). MCP server para Claude Code. Reemplaza scripts caseros nlm. |

Condiciones Capa A: requiere Node + Python + git + internet ANTES. Varios son interactivos
(ruflo wizard, GSD pregunta runtime) -> el instalador debe responder por el usuario (no-interactivo).
RIESGO: Capa A no es nuestra; si un repo cambia, el instalador hereda el cambio.

### Capa B — Andamiaje propio (ESTO es lo que se vende y se empaqueta en el .exe)
No sale de ningun repo. Es lo que hace que funcione "como este entorno".
Se extrae de este workspace a una plantilla limpia (sin proyectos del usuario, sin .env real,
sin ruvector.db con datos).

```
CLAUDE.md              -> plantilla GENERICA del protocolo (arranque, herramientas, skills)
                          OJO: el actual tiene Appmaestro/BCG -> el producto va SIN proyectos
.mcp.json              -> 3 MCP servers (claude-flow, ruv-swarm, flow-nexus)
.claude/settings.json  -> hooks (hook-handler.cjs), permisos, env
.claude/helpers/       -> hook-handler.cjs
scripts/gemini/        -> gemini-client.js (integracion Gemini propia, generalizada)
scripts/automation/    -> init-project.js, hitos-manager.js, error-logger.js
skills propias         -> nuevo-proyecto, asesor-web, zoom-out (TODAS genericas, sin datos del usuario)
```
NOTA: los scripts caseros de notebooklm (nlm_query.py, refresh_nlm.ps1) NO van en Capa B:
los reemplaza notebooklm-py (Capa A). gemini_to_nlm.py se revisa (puede quedar como helper opcional).

### Regla anti-duplicacion (adoptada) — VERIFICADA 2026-06-24
Se instalo Ruflo limpio (`npx ruflo@latest init`) en carpeta de prueba. Resultado:
- Ruflo GENERA (NO van en Capa B): `.claude/agents/`, `.claude/commands/`, `.claude/skills/` (30 skills:
  agentdb-*, github-*, browser, swarm, etc.), `.claude/helpers/` (hook-handler.cjs y ~40 mas),
  `.claude/settings.json`, `.claude-flow/`, y un `CLAUDE.md` base.
- Ruflo NO genera: `.mcp.json` -> ese SI va en Capa B.
- Ruflo NO trae las skills propias (zoom-out, nuevo-proyecto, asesor-web) -> van en Capa B.

### Capa B FINAL (definida)
```
plantilla/
├── CLAUDE.md                    (generico desde cero; sobreescribe el de Ruflo al final)
├── .mcp.json                    (Ruflo no lo genera; 3 MCP servers)
├── scripts/
│   ├── gemini/gemini-client.js  (generalizado)
│   └── automation/              (init-project.js, hitos-manager.js, error-logger.js)
└── .claude/skills/
    ├── nuevo-proyecto/          (generalizada)
    ├── asesor-web/              (ya casi generica)
    └── zoom-out/                (tal cual)
```
NO van (los genera Ruflo): settings.json, helpers/, agents/, commands/, skills de Ruflo.
NO va: scripts/notebooklm caseros (los reemplaza notebooklm-py de Capa A).

### Decisiones del grilling (2026-06-24)
1. Valor = el combo curado (c). El protocolo de orquestacion es texto que Claude lee en claro -> copiable, se acepta. No hay encriptacion posible (Claude no desencripta; lo que Claude lee, el usuario lo lee).
2. Proteccion real: integraciones en codigo (scripts/MCP) + licencia + marca + updates. NO por secreto.
3. Plantilla Capa B = snapshot manual (la arma Claude una vez), no extractor automatico (sobre-ingenieria para MVP).
4. Skills propias quedan GENERICAS: nuevo-proyecto reescrita sin referencias a AsesorWeb/BCG/Appmaestro; debe agendar cada proyecto nuevo igual que aca (tabla CLAUDE.md + Ruflo namespace + archivos memoria). asesor-web generalizada. zoom-out va tal cual.
5. CLAUDE.md generico = protocolo COMPLETO parametrizado (no capado), legible para no-devs. Arranca con tablas VACIAS (sin proyectos/notebooks del usuario) y se llena solo con el uso. Datos del usuario reemplazan a los mios.
6. Login Opcion A (cuenta Anthropic OAuth, no API key). Nativo de Claude Code.
7. Sin internet NO funciona (la inferencia es en la nube). Requisito duro.

### Prerrequisitos a instalar antes (FASE 0)
VSCode + Claude Code CLI + Node.js LTS + Python 3.10+ + uv + git (silent install / winget).

### Orden de instalacion del .exe
```
FASE 0  Prerrequisitos (Node + Python + uv + git + VSCode + Claude Code CLI)
FASE 1  Graphify        (uv tool install graphifyy) — independiente
FASE 2  Ruflo           (genera base .claude/ + CLAUDE.md + MCP)
FASE 3  GSD             (npx, runtime=Claude Code)
FASE 4  Matt Pocock     (npx skills add — ultimo que toca CLAUDE.md/CONTEXT.md)
FASE 5  Capa B Sincro   (copia plantilla propia; Sincro escribe el CLAUDE.md maestro al final)
        + wizard APIs (.env: Claude/Gemini/cookies NotebookLM) + validacion licencia Lemon Squeezy
```

## Funcionalidades — prioridad
### MVP
1. Instalador (Inno Setup) que deja el entorno funcionando: VSCode + Claude Code + Node + Python + repos clonados + dependencias.
2. Wizard que pide las APIs del usuario y escribe la configuración (.env / settings).
3. Validación de **clave de licencia** (Lemon Squeezy) al instalar/arrancar.

### V2
- Web de venta pulida.
- Auto-update del entorno.

### Backlog
- (nada pendiente — el usuario pidió todo en MVP)

## Decisiones de arquitectura
- BYOK: las claves nunca se embeben; las carga el usuario en su máquina.
- Bundle legal: el instalador **descarga/clona desde las fuentes oficiales**, no redistribuye binarios de terceros.
- Entorno 100% local; no hay backend que procese datos del usuario.

## Riesgos abiertos
1. **Bootstrap frágil** — instalar Python/Node/git/clonar/`npm i` falla en PCs heterogéneas. Mitigar: detectar lo ya instalado, logs claros, instaladores embebidos offline.
2. **SmartScreen** — .exe sin firmar alerta "editor desconocido". Mitigar futuro: certificado de firma de código.
3. **Cookies NotebookLM expiran** — fuente #1 de soporte. Mitigar: documentar re-login y que el entorno avise cuando la sesión venció.

## Estado
2026-06-24 — Brief completado vía /nuevo-proyecto. Listo para desarrollo del MVP.
