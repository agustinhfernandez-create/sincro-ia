# 0003 — Cobro y licencias con Lemon Squeezy + PayPal

Fecha: 2026-06-25
Estado: Superado por ADR-0004 (2026-06-25)

> NOTA: se descartó al intentar configurarlo — la moneda/setup no convenció y el payout por
> PayPal Argentina es engorroso. Se reemplazó por Mercado Pago + validador propio (ADR-0004).

## Contexto
Sincro IA necesita cobrar (venta única) y entregar una clave de licencia por compra, con
infra $0 y sin servidor de licencias propio. El vendedor está en Argentina, lo que complica
el cobro internacional: el cuello de botella no es la plataforma de venta sino el payout
(recibir el dinero). Tanto Gumroad como Lemon Squeezy dependen de PayPal/Payoneer/banco del
exterior para pagar a Argentina (Argentina no está entre los ~79 países con bank payout directo
de Lemon Squeezy).

## Decisión
Usar **Lemon Squeezy** como plataforma de venta + licencias, con **payout vía PayPal**.
El instalador valida la clave contra la API pública de Lemon Squeezy
(`POST https://api.lemonsqueezy.com/v1/licenses/validate`, solo con la license_key, sin token),
opcionalmente verificando el `store_id` para rechazar claves de otros productos.

## Alternativas consideradas
- **Gumroad**: válido y con licencias, pero fee mayor (~10% vs ~5%) y menor cobertura como
  Merchant of Record. Mismo problema de payout para Argentina.
- **Mercado Pago + validador propio (Cloudflare Worker + KV)**: permite cobrar en pesos directo,
  pero exige construir y mantener el sistema de licencias (más trabajo, más superficie de fallo).
  Queda como plan B si el cobro internacional resulta inviable.

## Consecuencias
- (+) Fee menor y Merchant of Record (Lemon Squeezy paga impuestos/IVA global por el vendedor).
- (+) Licencias nativas: cero servidor propio.
- (+) La validación en el bootstrap no requiere token (clave pública), simple de implementar.
- (−) El payout depende de PayPal Argentina (recibir comercial + retirar es restringido/lento).
- (−) Si PayPal Argentina no funciona para el vendedor, hay que migrar a Mercado Pago + Worker
  (plan B), lo que cambia el sistema de licencias.
