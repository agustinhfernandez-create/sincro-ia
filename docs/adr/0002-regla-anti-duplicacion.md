# 0002 — Regla anti-duplicación de la Capa B

Fecha: 2026-06-24
Estado: Aceptado

## Contexto
Parte del `.claude/` del workspace original (settings.json, helpers/hook-handler.cjs, agents/,
commands/) fue generada por Ruflo, no escrita a mano. Al armar la plantilla Capa B existe el
riesgo de empaquetar archivos que los instaladores de Capa A vuelven a crear, produciendo
duplicación o conflictos (pisar config, archivos a medio mezclar).

## Decisión
En la Capa B va **solo lo que ningún instalador de Capa A genera**. Todo lo que crean
Ruflo / GSD / Matt Pocock / notebooklm-py se deja que lo creen ellos durante la instalación.
Los archivos dudosos (settings.json, .mcp.json, helpers) se resuelven **instalando la
herramienta limpia en una carpeta de prueba y comparando**, no adivinando.

## Alternativas consideradas
- **Empaquetar todo el `.claude/` actual**: rechazado. Mezcla lo propio con lo generado por
  Ruflo; produce duplicación y se desincroniza con futuras versiones de las herramientas.
- **Asumir a ojo qué es de quién**: rechazado. Lleva a errores silenciosos; mejor verificar
  con una instalación limpia.

## Consecuencias
- (+) La plantilla Capa B queda mínima y sin colisiones con los instaladores.
- (+) Las herramientas de Capa A mantienen su propia config y se actualizan sin que la
  empaquetemos.
- (−) Requiere un paso de verificación (instalar Ruflo limpio) antes de cerrar la plantilla.
- (−) Si una herramienta deja de generar algo que dábamos por suyo, hay que moverlo a Capa B.
