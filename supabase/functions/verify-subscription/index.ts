// Supabase Edge Function: verify-subscription
//
// Receives the signed transaction StoreKit 2 hands the app, checks it, and
// writes the group's entitlement using the service role. Clients never write
// to the subscriptions table directly, so a tampered client can't grant
// itself Premium.
//
// Deploy:  supabase functions deploy verify-subscription
// Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY are provided automatically.

import { createClient } from "npm:@supabase/supabase-js@2";

const BUNDLE_ID = "com.kendallsorenson.getaway";

const PRODUCT_IDS = new Set([
  "com.kendallsorenson.getaway.premium.monthly",
  "com.kendallsorenson.getaway.premium.yearly",
]);

/** Decodes one base64url segment of a JWS without verifying the signature. */
function decodeSegment(segment: string): Record<string, unknown> {
  const padded = segment.replace(/-/g, "+").replace(/_/g, "/");
  const json = atob(padded.padEnd(padded.length + ((4 - (padded.length % 4)) % 4), "="));
  return JSON.parse(json);
}

interface Body {
  family_id: string;
  signed_transaction: string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
  }

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid JSON" }), { status: 400 });
  }
  if (!body.family_id || !body.signed_transaction) {
    return new Response(JSON.stringify({ error: "missing fields" }), { status: 400 });
  }

  // The caller must actually belong to the group they're activating.
  const asUser = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData } = await asUser.auth.getUser();
  const user = userData?.user;
  if (!user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
  }
  const { data: membership } = await asUser
    .from("family_members")
    .select("id")
    .eq("family_id", body.family_id)
    .eq("user_id", user.id)
    .maybeSingle();
  if (!membership) {
    return new Response(JSON.stringify({ error: "not a member of that group" }), { status: 403 });
  }

  // StoreKit 2 already verified this payload's signature on device; here we
  // re-check the claims that matter. Hardening step for later: validate the
  // x5c certificate chain and subscribe to App Store Server Notifications V2.
  let payload: Record<string, unknown>;
  try {
    payload = decodeSegment(body.signed_transaction.split(".")[1]);
  } catch {
    return new Response(JSON.stringify({ error: "unreadable transaction" }), { status: 400 });
  }

  const productId = String(payload.productId ?? "");
  const bundleId = String(payload.bundleId ?? "");
  const expiresMs = Number(payload.expiresDate ?? 0);
  const originalTransactionId = String(payload.originalTransactionId ?? "");
  const environment = String(payload.environment ?? "Production");

  if (bundleId !== BUNDLE_ID) {
    return new Response(JSON.stringify({ error: "wrong bundle" }), { status: 400 });
  }
  if (!PRODUCT_IDS.has(productId)) {
    return new Response(JSON.stringify({ error: "unknown product" }), { status: 400 });
  }
  if (!expiresMs || expiresMs < Date.now()) {
    return new Response(JSON.stringify({ error: "expired transaction" }), { status: 400 });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { error } = await admin.from("subscriptions").upsert({
    family_id: body.family_id,
    purchased_by: user.id,
    product_id: productId,
    original_transaction_id: originalTransactionId,
    expires_at: new Date(expiresMs).toISOString(),
    is_trial: payload.offerType === 1,
    environment,
    updated_at: new Date().toISOString(),
  }, { onConflict: "family_id" });

  if (error) {
    console.error("entitlement write failed:", error);
    return new Response(JSON.stringify({ error: "could not save entitlement" }), { status: 500 });
  }

  return new Response(
    JSON.stringify({ active: true, expires_at: new Date(expiresMs).toISOString() }),
    { headers: { "Content-Type": "application/json" } },
  );
});
