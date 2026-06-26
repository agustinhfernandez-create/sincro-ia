# 0004 — Cobro con Mercado Pago + validador de licencias propio

Fecha: 2026-06-25
Estado: Aceptado (supera ADR-0003)

## Contexto
Lemon Squeezy (ADR-0003) se descartó en la práctica: configurar la tienda no convenció
(la moneda quedaba en ARS y el cambio a USD no era directo) y el payout depende de PayPal
Argentina, que es engorroso. El vendedor prefiere cobrar en pesos directo a su cuenta de
Mercado Pago, aun a costa de construir y mantener el sistema de licencias.

## Decisión
Construir un sistema propio de **pago único con Mercado Pago** + **validador de licencias**
sobre **Cloudflare Workers + KV** (infra $0):
- `POST /crear-pago` crea una preferencia de Checkout Pro.
- `POST /webhook` recibe el aviso de MP, verifica el pago contra la API de MP, genera la clave,
  la guarda en KV (idempotente por `payment_id`) y manda email (Resend, opcional).
- `GET /gracias` muestra la clave al cliente tras pagar.
- `POST /validate` valida la clave desde el instalador y la ata a una PC (`machine_id`).

## Alternativas consideradas
- **Lemon Squeezy / Gumroad**: licencias gratis listas, pero payout a Argentina engorroso y
  no se pudo configurar cómodo. Descartado.
- **Cobro manual (transferencia + clave a mano)**: cero código, pero no escala y es tedioso.

## Consecuencias
- (+) Cobro en pesos directo a Mercado Pago, sin intermediario de payout.
- (+) Control total del formato de clave, límites de activación y entrega.
- (+) Infra $0 (Workers + KV gratis).
- (−) Hay que construir y MANTENER el sistema (antes lo daba la plataforma).
- (−) Responsabilidad de seguridad propia: validar firma del webhook de MP, evitar fraude.
- (−) El email depende de un proveedor externo (Resend); la página de gracias es el respaldo.
