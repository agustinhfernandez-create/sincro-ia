# 0001 — Modelo de dos capas (herramientas oficiales + andamiaje propio)

Fecha: 2026-06-24
Estado: Aceptado

## Contexto
Sincro IA empaqueta y comercializa un entorno de orquestación con IA que el usuario ya
conocía como un workspace propio. La intuición inicial era "el instalador clona los repos
y copia los archivos". Al inspeccionar los 5 repos (Ruflo, Graphify, GSD, Matt Pocock,
notebooklm-py) se vio que la mayoría prohíbe o desaconseja copiar archivos a mano y exige
correr su instalador oficial (GSD lo dice explícitamente). Además, "que funcione como este
entorno" no se logra solo instalando las herramientas: hace falta el andamiaje propio
(CLAUDE.md, scripts de integración, skills) que no sale de ningún repo.

## Decisión
El producto se estructura en dos capas:
- **Capa A** — las herramientas de terceros, instaladas con su comando oficial. No se
  distribuyen ni se editan a mano. No son propiedad de Sincro IA.
- **Capa B** — el andamiaje propio (configuración, scripts de integración, skills curadas).
  Es lo que se empaqueta en el instalador y lo que realmente se vende.

El instalador corre los instaladores oficiales de Capa A y luego despliega la Capa B encima.

## Alternativas consideradas
- **Clonar y copiar los repos**: rechazado. GSD y matpocock lo prohíben; quedaría frágil y
  desactualizado, y no respeta las licencias/forma de distribución de terceros.
- **Sólo instalar las herramientas, sin capa propia**: rechazado. No reproduce "este entorno";
  el valor está en la curaduría y las integraciones propias.

## Consecuencias
- (+) Respeta la forma oficial de instalar cada herramienta y sus updates.
- (+) Aísla el valor propio (Capa B) de lo que no controlamos.
- (−) La Capa A no es nuestra: si un repo cambia, el instalador hereda el cambio (riesgo a monitorear).
- (−) Obliga a una regla de no-duplicación entre lo que generan los instaladores y lo que
  empaquetamos (ver ADR-0002).
