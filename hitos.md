# Hitos — Sincro IA

## 2026-06-24 — Proyecto creado
- Brief de descubrimiento completado vía `/nuevo-proyecto`.
- Definido: instalador Windows BYOK, venta única con licencia, infra $0.
- Stack elegido: Inno Setup + PowerShell · Gumroad · Cloudflare Pages.
- Identidad: Sincro IA, paleta azul #2D9CDB + naranja #FF8A3D.
- Estructura de memoria creada y registrada en Ruflo (namespace `sincro-ia`).
- Definidos 4 repos Capa A: ruflo, graphify (PyPI `graphifyy`), GSD (mudó a open-gsd/gsd-core), matpocock skills.
- Inspeccionados los 4: NO se clonan — se corren sus instaladores oficiales (npx/uv). GSD prohíbe copiar files a mano.
- **Modelo confirmado: 2 capas.** Capa A = 4 herramientas oficiales (auto-instalan). Capa B = andamiaje propio (CLAUDE.md plantilla + .mcp.json + settings/hooks + scripts gemini/notebooklm/automation + skills nuevo-proyecto/asesor-web/zoom-out). Capa B = lo que se vende.
- Orden de instalación FASE 0→5 definido en MEMORY_PROYECTO.
- Próximo: extraer Capa B a plantilla limpia (sin proyectos/.env/db del usuario). Requiere /grill-with-docs antes de implementar.

## 2026-06-24 (cont.) — Grilling + Plantilla Capa B construida
- Sesión /grill-with-docs completa (7 decisiones). CONTEXT.md + ADR-0001 (2 capas) + ADR-0002 (anti-duplicación) creados.
- 5º repo Capa A sumado: **notebooklm-py** (teng-lin) → login browser + auth refresh + MCP. NotebookLM entra al MVP. Reemplaza scripts nlm caseros.
- Verificación Ruflo limpio hecha (`npx ruflo init` en carpeta de prueba, ya borrada): Ruflo genera agents/commands/skills(30)/helpers/settings.json/.claude-flow/CLAUDE.md base. NO genera `.mcp.json`. NO trae skills propias.
- **Plantilla Capa B construida** en `Sincro-IA/plantilla/`:
  - CLAUDE.md genérico desde cero (tablas vacías, 5 herramientas, protocolo completo, login Opción A, requiere internet).
  - .mcp.json (3 MCP servers).
  - scripts/gemini/gemini-client.js (generalizado: SINCRO_ROOT/cwd en vez de C:/AsesorWeb).
  - scripts/automation/ (init-project, hitos-manager, error-logger).
  - .claude/skills/ propias: nuevo-proyecto (generalizada), asesor-web (genérica), zoom-out (tal cual).
- Próximo (otra sesión): construir el INSTALADOR (Inno Setup + PowerShell) que corre FASE 0→5. Requiere su propio grilling.

## 2026-06-24 (cont.) — Instalador: bootstrap.ps1
- Grilling instalador (5 decisiones): instala en `C:\Users\<user>\SincroIA\` (sin admin) · prereqs por detección de comandos + winget/fallback (sin IA) · licencia validada SOLO al instalar (MVP) · wizard pide solo texto (licencia+Gemini key), logins van al primer arranque guiado · hoy se construye solo bootstrap.ps1 (el .iss después).
- CONTEXT.md: agregados términos Bootstrap, Wizard, Primer arranque guiado.
- **`instalador/bootstrap.ps1` construido y validado (parse OK).** Hace: gate licencia Gumroad → FASE 0 prereqs (Node/Python/git/VSCode/uv/Claude CLI) → FASE 1 graphify+notebooklm-py (uv) → FASE 2 Ruflo → FASE 3 GSD → FASE 4 matpocock → FASE 5 despliega Capa B + escribe .env → instrucciones primer arranque.
- `instalador/README.md` con cómo probarlo y lo que falta.
- PENDIENTE instalador: `setup.iss` (Inno Setup, requiere compilar en tu PC), GumroadProductId real, prueba en PC limpia.
- ESTADO PRODUCTO: 2 de 5 piezas (Capa B ✓, bootstrap del instalador ✓). Faltan: .iss/wizard, licencias-web, web de venta, prueba PC limpia.

## 2026-06-25 — Pago: Lemon Squeezy + PayPal
- Evaluado para Argentina: el cuello no es la plataforma sino el payout. LS soporta Argentina vía PayPal (no bank directo). Elegido **Lemon Squeezy + PayPal** (fee ~5%, Merchant of Record). Plan B si PayPal AR no sirve: Mercado Pago + Worker propio.
- ADR-0003 creado.
- bootstrap.ps1 actualizado: validación cambiada de Gumroad a **Lemon Squeezy** (`POST api.lemonsqueezy.com/v1/licenses/validate`, sin token, opcional verificar store_id). Param `LemonStoreId` reemplaza `GumroadProductId`. Parse OK.
- Docs actualizadas (MEMORY_PROYECTO, instalador/README).

## 2026-06-25 (cont.) — CAMBIO de pago: Lemon → Mercado Pago + Worker propio
- Lemon Squeezy descartado al configurarlo (moneda ARS no pasaba a USD cómodo; payout PayPal AR engorroso). ADR-0003 marcado Superado.
- **Decisión: Mercado Pago + validador propio** (ADR-0004). Cobro en pesos directo, infra $0.
- **Worker de licencias construido** en `licencias-worker/` (JS OK):
  - `src/index.js`: /crear-pago (preferencia Checkout Pro), /webhook (verifica pago contra API MP, genera clave SINC-XXXX-XXXX-XXXX, guarda en KV, email Resend opcional, idempotente por payment_id), /gracias (HTML muestra clave), /validate (ata licencia a 1 PC por machine_id).
  - `wrangler.toml` (KV LICENCIAS, vars, secrets MP_ACCESS_TOKEN/RESEND_API_KEY).
  - `README.md` con deploy.
- bootstrap.ps1 actualizado: valida contra Worker propio (`POST $LicenseApi/validate` con machine_id = UUID de la PC), ya no Lemon. Parse OK.
- Grilling licencias: entrega = email + página de gracias; 1 licencia = 1 PC (machine_id); Checkout Pro.
- ESTADO PRODUCTO: ~3 de 5 piezas (Capa B ✓, bootstrap ✓, Worker licencias ✓). Faltan: setup.iss Inno Setup + deploy Worker (KV/secrets/MP), web de venta, prueba PC limpia. Pendiente seguridad: validar firma webhook MP.

## 2026-06-25 (cont.) — setup.iss (Inno Setup) construido
- **`instalador/setup.iss` construido.** Wizard: página custom pide licencia + Gemini key (valida que la licencia no esté vacía); empaqueta bootstrap.ps1 + plantilla/ (dontcopy + ExtractTemporaryFiles); en ssPostInstall corre bootstrap.ps1 con LicenseKey/GeminiKey/TemplateDir/InstallDir/LicenseApi. Instala en {userpf}\SincroIA (PrivilegesRequired=lowest, sin admin). Idioma español.
- NO compilable en este entorno (sin Inno Setup) → se compila en la PC del usuario. Placeholders `<<<`: MyLicenseApi (URL Worker), MyAppPublisher, SetupIconFile (opcional).
- instalador/README actualizado con pasos de compilación.
- ESTADO: piezas de código del MVP completas (Capa B + bootstrap + Worker + .iss). Falta EJECUTAR: deploy Worker (KV/secrets/MP), compilar .exe, web de venta, prueba PC limpia. Seguridad pendiente: firma webhook MP.

## 2026-06-26 — Repo GitHub
- Repo privado creado y pusheado: **github.com/agustinhfernandez-create/sincro-ia** (cuenta gh: agustinhfernandez-create).
- .gitignore protege secretos (.env, *.db, node_modules, .wrangler, *.exe). ruvector.db excluido.
- Commit inicial: 27 archivos (plantilla + instalador + licencias-worker + docs/adr). Sin secretos.
- MP: elegido **Checkout Pro** (coincide con /crear-pago del Worker).
- PENDIENTE usuario: gh OK ✓; falta deploy Worker (token MP via wrangler secret, NO compartir), compilar .exe (Inno Setup), prueba PC limpia.

## 2026-06-26 (cont.) — Seguridad webhook MP
- **Firma del webhook MP implementada** en el Worker: HMAC-SHA256 sobre `id:<data.id>;request-id:<x-request-id>;ts:<ts>;` vs `v1` del header `x-signature`. Comparación de longitud constante. Fail-closed (sin MP_WEBHOOK_SECRET → 401). Worker JS OK. Commit+push.
- Nuevo secret: `MP_WEBHOOK_SECRET` (sacar del panel de webhooks de MP). Documentado en wrangler.toml + README.
- ESTADO: Worker listo para producción (queda solo configurar secrets + deploy). Falta: web de venta, deploy, compilar .exe, prueba PC limpia.

## 2026-06-26 (cont.) — Worker EN PRODUCCIÓN
- Worker deployado: `https://sincro-ia-licencias.agustinhfernandez.workers.dev` (cuenta CF agustinhfernandez, account 03be8cee...).
- KV LICENCIAS id `f25a26729e9049a4a10af9a51c6f9f57` en wrangler.toml.
- Secrets cargados (vía wrangler, NO en repo): MP_ACCESS_TOKEN + MP_WEBHOOK_SECRET.
- PRICE_ARS = 20000.
- Webhook MP configurado (Modo productivo, evento Pagos) → URL/webhook.
- **PROBADO**: GET / responde ok; POST /crear-pago devuelve init_point real de MP (preferencia creada). Cobro funciona de punta a punta.
- PENDIENTE: probar flujo completo con pago real (webhook → genera licencia en KV → email/gracias), web de venta, compilar .exe (Inno Setup), prueba PC limpia. Email Resend sin configurar (entrega = página /gracias por ahora).
