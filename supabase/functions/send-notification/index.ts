// Stub: deploy with Supabase CLI. Wire FCM HTTP v1 + service account secret.
// See plan/03_database_roadmap.md — reads users.fcm_token, sends push, updates notifications.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const _body = await req.json().catch(() => ({}));
    // TODO: createClient(SUPABASE_URL, SERVICE_ROLE_KEY), load tokens, call FCM v1 API
    return new Response(
      JSON.stringify({ success: true, stub: true, message: "Implement FCM send" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
