/**
 * Sincro IA - Worker de licencias (Cloudflare)
 * Pago unico con Mercado Pago + generacion/validacion de licencias en KV.
 *
 * Endpoints:
 *   POST /crear-pago     -> crea preferencia de Checkout Pro, devuelve init_point (URL de pago)
 *   POST /webhook        -> Mercado Pago avisa el pago; genera la clave, guarda en KV, manda email
 *   GET  /gracias?pago=  -> pagina post-pago: muestra la clave asociada a ese payment_id
 *   POST /validate       -> el instalador valida una clave (y la ata a una PC)
 *
 * Secrets (wrangler secret put):
 *   MP_ACCESS_TOKEN   -> access token de Mercado Pago
 *   RESEND_API_KEY    -> (opcional) para enviar email; si falta, se omite el email
 * Vars (wrangler.toml):
 *   PRICE_ARS, PRODUCT_NAME, APP_ORIGIN, EMAIL_FROM
 * KV:
 *   LICENCIAS  -> namespace binding
 */

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  });

// Genera una clave tipo SINC-XXXX-XXXX-XXXX
function generarClave() {
  const abc = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sin caracteres ambiguos
  const bloque = () =>
    Array.from({ length: 4 }, () => abc[Math.floor(Math.random() * abc.length)]).join("");
  return `SINC-${bloque()}-${bloque()}-${bloque()}`;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const { pathname } = url;

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    try {
      if (pathname === "/crear-pago" && request.method === "POST")
        return await crearPago(request, env);
      if (pathname === "/webhook" && request.method === "POST")
        return await webhook(request, env);
      if (pathname === "/gracias" && request.method === "GET")
        return await gracias(url, env);
      if (pathname === "/validate" && request.method === "POST")
        return await validate(request, env);

      return json({ ok: true, service: "sincro-ia-licencias" });
    } catch (e) {
      return json({ error: e.message }, 500);
    }
  },
};

// --------------------------------------------------------------------
// 1) Crear preferencia de pago (Checkout Pro)
// --------------------------------------------------------------------
async function crearPago(request, env) {
  const body = await request.json().catch(() => ({}));
  const email = (body.email || "").trim();

  const pref = {
    items: [
      {
        title: env.PRODUCT_NAME || "Sincro IA",
        quantity: 1,
        currency_id: "ARS",
        unit_price: Number(env.PRICE_ARS || 0),
      },
    ],
    payer: email ? { email } : undefined,
    back_urls: {
      success: `${env.APP_ORIGIN}/gracias`,
      pending: `${env.APP_ORIGIN}/gracias`,
      failure: `${env.APP_ORIGIN}/gracias`,
    },
    auto_return: "approved",
    notification_url: `${env.APP_ORIGIN}/webhook`,
  };

  const resp = await fetch("https://api.mercadopago.com/checkout/preferences", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.MP_ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(pref),
  });
  const data = await resp.json();
  if (!resp.ok) return json({ error: "MP error", detail: data }, 502);

  return json({ init_point: data.init_point, preference_id: data.id });
}

// --------------------------------------------------------------------
// Verifica la firma del webhook de Mercado Pago (x-signature).
// Manifest: id:<data.id>;request-id:<x-request-id>;ts:<ts>;
// HMAC-SHA256 con MP_WEBHOOK_SECRET, comparado con v1.
// --------------------------------------------------------------------
async function firmaValida(request, env, dataId) {
  const secret = env.MP_WEBHOOK_SECRET;
  if (!secret) return false; // fail-closed: sin secret no se confia en nadie

  const xSignature = request.headers.get("x-signature") || "";
  const xRequestId = request.headers.get("x-request-id") || "";

  // x-signature: "ts=123456,v1=abcdef..."
  let ts = "", v1 = "";
  for (const parte of xSignature.split(",")) {
    const [k, val] = parte.split("=");
    if (k?.trim() === "ts") ts = (val || "").trim();
    if (k?.trim() === "v1") v1 = (val || "").trim();
  }
  if (!ts || !v1 || !dataId) return false;

  // data.id alfanumerico va en minusculas segun la doc de MP
  const id = String(dataId).toLowerCase();
  const manifest = `id:${id};request-id:${xRequestId};ts:${ts};`;

  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const sigBuf = await crypto.subtle.sign("HMAC", key, enc.encode(manifest));
  const hex = [...new Uint8Array(sigBuf)].map((b) => b.toString(16).padStart(2, "0")).join("");

  // comparacion de longitud constante
  if (hex.length !== v1.length) return false;
  let diff = 0;
  for (let i = 0; i < hex.length; i++) diff |= hex.charCodeAt(i) ^ v1.charCodeAt(i);
  return diff === 0;
}

// --------------------------------------------------------------------
// 2) Webhook de Mercado Pago -> generar licencia
// --------------------------------------------------------------------
async function webhook(request, env) {
  const url = new URL(request.url);
  const body = await request.json().catch(() => ({}));

  // MP puede avisar por query (?type=payment&data.id=) o por body {type,data:{id}}
  const tipo = body.type || url.searchParams.get("type");
  const pagoId = body?.data?.id || url.searchParams.get("data.id");

  if (tipo !== "payment" || !pagoId) return json({ ok: true, ignored: true });

  // SEGURIDAD: rechazar webhooks sin firma valida (evita que cualquiera genere licencias)
  if (!(await firmaValida(request, env, pagoId)))
    return json({ error: "firma invalida" }, 401);

  // Verificar el pago real contra la API de MP (no confiar en el webhook a ciegas)
  const r = await fetch(`https://api.mercadopago.com/v1/payments/${pagoId}`, {
    headers: { Authorization: `Bearer ${env.MP_ACCESS_TOKEN}` },
  });
  const pago = await r.json();
  if (!r.ok) return json({ error: "no se pudo leer el pago" }, 502);
  if (pago.status !== "approved") return json({ ok: true, status: pago.status });

  // Idempotencia: si ya generamos clave para este pago, no duplicar
  const yaKey = await env.LICENCIAS.get(`pago:${pagoId}`);
  if (yaKey) return json({ ok: true, key: yaKey, dup: true });

  // Generar y guardar la licencia
  const clave = generarClave();
  const email = pago.payer?.email || "";
  const registro = {
    clave,
    email,
    payment_id: String(pagoId),
    status: "active",
    activaciones: 0,
    max_activaciones: 1, // una licencia = una PC
    machine_id: null,
    creado: new Date().toISOString(),
  };
  await env.LICENCIAS.put(`lic:${clave}`, JSON.stringify(registro));
  await env.LICENCIAS.put(`pago:${pagoId}`, clave); // index para /gracias + idempotencia

  // Email (opcional, si hay RESEND_API_KEY)
  if (env.RESEND_API_KEY && email) {
    await enviarEmail(env, email, clave).catch(() => {});
  }

  return json({ ok: true, key: clave });
}

// --------------------------------------------------------------------
// 3) Pagina de gracias -> muestra la clave por payment_id
// --------------------------------------------------------------------
async function gracias(url, env) {
  const pagoId =
    url.searchParams.get("pago") ||
    url.searchParams.get("payment_id") ||
    url.searchParams.get("collection_id");

  let clave = null;
  if (pagoId) clave = await env.LICENCIAS.get(`pago:${pagoId}`);

  const cuerpo = clave
    ? `<p>¡Gracias por tu compra! Esta es tu clave de licencia:</p>
       <p class="clave">${clave}</p>
       <p>Tambien te la enviamos por email. Guardala: la vas a pegar en el instalador de Sincro IA.</p>`
    : `<p>¡Gracias por tu compra!</p>
       <p>Tu clave de licencia se esta generando. Si no aparece, revisa tu email en unos minutos.</p>`;

  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Gracias — Sincro IA</title>
    <style>
      body{font-family:Inter,system-ui,sans-serif;background:#F5F7FA;color:#1E293B;
           display:flex;min-height:100vh;align-items:center;justify-content:center;margin:0}
      .card{background:#fff;border-radius:12px;padding:32px;max-width:480px;
            box-shadow:0 10px 30px rgba(0,0,0,.08);text-align:center}
      h1{color:#2D9CDB}
      .clave{font-size:1.4rem;font-weight:700;letter-spacing:2px;background:#F5F7FA;
             border:2px dashed #2D9CDB;border-radius:8px;padding:14px;margin:18px 0}
    </style></head><body>
    <div class="card"><h1>Sincro IA</h1>${cuerpo}</div></body></html>`;

  return new Response(html, { headers: { "Content-Type": "text/html; charset=utf-8" } });
}

// --------------------------------------------------------------------
// 4) Validar licencia (lo llama el instalador)
// --------------------------------------------------------------------
async function validate(request, env) {
  const body = await request.json().catch(() => ({}));
  const clave = (body.license_key || "").trim().toUpperCase();
  const machineId = (body.machine_id || "").trim();

  if (!clave) return json({ valid: false, reason: "falta license_key" }, 400);

  const raw = await env.LICENCIAS.get(`lic:${clave}`);
  if (!raw) return json({ valid: false, reason: "clave inexistente" });

  const reg = JSON.parse(raw);
  if (reg.status !== "active") return json({ valid: false, reason: "licencia inactiva" });

  // Si ya esta atada a una PC distinta -> rechazar (1 licencia = 1 PC)
  if (reg.machine_id && machineId && reg.machine_id !== machineId)
    return json({ valid: false, reason: "licencia ya usada en otra PC" });

  // Primera activacion: atar a esta PC
  if (!reg.machine_id) {
    if (reg.activaciones >= reg.max_activaciones)
      return json({ valid: false, reason: "limite de activaciones alcanzado" });
    reg.machine_id = machineId || null;
    reg.activaciones += 1;
    reg.activado = new Date().toISOString();
    await env.LICENCIAS.put(`lic:${clave}`, JSON.stringify(reg));
  }

  return json({ valid: true, status: reg.status });
}

// --------------------------------------------------------------------
// Email via Resend (opcional)
// --------------------------------------------------------------------
async function enviarEmail(env, to, clave) {
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: env.EMAIL_FROM || "Sincro IA <onboarding@resend.dev>",
      to,
      subject: "Tu licencia de Sincro IA",
      html: `<p>¡Gracias por tu compra!</p>
             <p>Tu clave de licencia es:</p>
             <p style="font-size:20px;font-weight:bold;letter-spacing:2px">${clave}</p>
             <p>Pegala en el instalador de Sincro IA para activar el entorno.</p>`,
    }),
  });
}
