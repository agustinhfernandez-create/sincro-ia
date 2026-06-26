# CONTEXT — Sincro IA

Glosario del proyecto. Solo lenguaje, sin detalles de implementación.

## Términos

### Entorno
El conjunto completo que el usuario obtiene tras instalar: Claude Code como orquestador + las 4 herramientas + el andamiaje propio, todo configurado y funcionando junto. Requiere internet (la inferencia es en la nube).

### Capa A
Las herramientas de terceros que se instalan con su comando oficial: Ruflo, Graphify, GSD, Matt Pocock skills y notebooklm-py. No se distribuyen ni se editan a mano; el instalador corre sus instaladores. No son propiedad de Sincro IA.

### Regla anti-duplicación
En la Capa B va SOLO lo que ningún instalador de Capa A genera. Todo lo que crean Ruflo/GSD/matpocock/notebooklm-py se deja que lo creen ellos en la instalación; no se empaqueta. Lo dudoso (settings.json, .mcp.json, helpers) se resuelve instalando la herramienta limpia y comparando, no adivinando.

### Capa B
El andamiaje propio de Sincro IA: la plantilla que se empaqueta en el instalador y se despliega encima de la Capa A. Es lo que se comercializa. Incluye configuración (CLAUDE.md, .mcp.json, settings), scripts de integración (Gemini, NotebookLM, automatización) y skills propias.

### Valor / Combo
Lo que realmente se vende: el combo curado y pre-configurado que hace que todo funcione junto, más la licencia y los updates. NO es un secreto de texto. El protocolo de orquestación es texto que Claude lee en claro, por lo tanto es copiable; se acepta. Lo único protegible de verdad son las integraciones (código de los scripts) y la curaduría del conjunto.

### Protocolo de orquestación
El flujo de trabajo que sigue Claude como orquestador (arranque, orden de consulta de herramientas, reglas, skills obligatorias). Vive como texto en CLAUDE.md. Es copiable por diseño; no se protege.

### BYOK (Bring Your Own Keys)
Cada usuario aporta sus propias credenciales: cuenta Anthropic (login Opción A, OAuth con suscripción), API key de Gemini, sesión de NotebookLM (login por browser vía notebooklm-py). Sincro IA no provee ni embebe claves.

### Login Opción A
El cliente se autentica en Claude Code con su cuenta Anthropic (OAuth, suscripción Claude Pro/Max), no con API key. El wizard solo lo guía a ejecutar `claude` y loguearse. Es nativo de Claude Code; no se construye.

### NotebookLM (en el producto)
Se integra vía la herramienta oficial notebooklm-py (github.com/teng-lin/notebooklm-py): login por browser (Playwright) con `notebooklm login`, keepalive con `notebooklm auth refresh`, MCP server para Claude Code. Reemplaza los scripts caseros nlm_query.py/refresh_nlm.ps1. Es la pieza más frágil (cookies, no oficial) pero manejable. Va en el MVP.

### Bootstrap
El script PowerShell (`bootstrap.ps1`) que ejecuta la instalación sin IA: detecta prerrequisitos por comandos del sistema, instala lo que falta, corre los instaladores de Capa A, despliega la Capa B y escribe el `.env`. Es lógica mecánica; Claude (la IA) recién arranca después, ya instalado.

### Wizard
La parte interactiva del instalador (Inno Setup) que pide al usuario solo datos de texto: la clave de licencia y la API key de Gemini. Escribe el `.env`. NO hace los logins (Claude, NotebookLM) porque requieren browser.

### Primer arranque guiado
El paso posterior a la instalación donde el usuario hace los logins que no se pueden automatizar: `claude` (OAuth con cuenta) y `notebooklm login` (browser). Guiado por instrucciones paso a paso.

### Worker de licencias
El backend propio (Cloudflare Workers + KV) que maneja el cobro y las licencias. Reemplaza a la plataforma de venta de terceros. Cobra con Mercado Pago (pago único), genera la clave al confirmarse el pago, la entrega (email + página de gracias) y la valida cuando el instalador pregunta. Carpeta `licencias-worker/`.

### Licencia (clave)
Cadena única (formato `SINC-XXXX-XXXX-XXXX`) generada al aprobarse un pago. Se guarda en KV con su email, payment_id y estado. Se ata a una sola PC en la primera validación (machine_id = UUID de la máquina). Una licencia = una PC.

### machine_id
Identificador estable de la PC del cliente (UUID de Win32_ComputerSystemProduct) que el instalador envía al validar. Ata la licencia a esa máquina para evitar que se copie la carpeta a otra PC.
