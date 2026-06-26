# Worker de licencias — Sincro IA

Sistema propio de pago único (Mercado Pago) + licencias, sobre Cloudflare Workers + KV. Infra $0.
Reemplaza a Lemon Squeezy (ver ADR-0004).

## Flujo
```
Web de venta -> POST /crear-pago -> init_point (URL de Checkout Pro de MP)
Cliente paga en MP
MP -> POST /webhook -> verifica el pago contra la API de MP -> genera clave -> KV -> email (Resend)
Cliente vuelve a /gracias?pago=<id> -> ve su clave en pantalla
Instalador -> POST /validate {license_key, machine_id} -> KV -> valid:true/false
```

## Endpoints
- `POST /crear-pago` — body `{ email? }` → `{ init_point, preference_id }`.
- `POST /webhook` — lo llama Mercado Pago. Verifica `status=approved`, genera y guarda la clave. Idempotente por `payment_id`.
- `GET /gracias?pago=<payment_id>` — página HTML que muestra la clave.
- `POST /validate` — body `{ license_key, machine_id }` → `{ valid, reason? }`. Ata la licencia a 1 PC.

## Modelo de datos (KV `LICENCIAS`)
- `lic:<CLAVE>` → `{ clave, email, payment_id, status, activaciones, max_activaciones:1, machine_id, creado }`
- `pago:<payment_id>` → `<CLAVE>` (índice para /gracias e idempotencia)

## Deploy (vos, una vez)
```bash
npm i -g wrangler
wrangler kv namespace create LICENCIAS      # pegar el id en wrangler.toml
wrangler secret put MP_ACCESS_TOKEN          # access token de Mercado Pago
wrangler secret put RESEND_API_KEY           # opcional (email)
# Editar wrangler.toml: PRICE_ARS, APP_ORIGIN (URL del worker), EMAIL_FROM
wrangler deploy
```
Después: en Mercado Pago, configurar el webhook apuntando a `<APP_ORIGIN>/webhook` (o lo setea /crear-pago via notification_url).
Y en el instalador, pasar `-LicenseApi <APP_ORIGIN>`.

## Pendiente / mejoras
- Email: usa Resend (free 100/día, requiere dominio verificado para `from` propio; sin eso usa `onboarding@resend.dev`).
- Validación de firma del webhook de MP (x-signature) — recomendado antes de producción.
- Página de gracias y web de venta pueden moverse a CF Pages (este Worker ya sirve /gracias mínima).
