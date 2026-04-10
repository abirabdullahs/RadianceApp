import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
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
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
    const CRON_SECRET = Deno.env.get("DUES_CRON_SECRET")?.trim();

    const authHeader = req.headers.get("Authorization");
    const cronSecret = req.headers.get("x-cron-secret")?.trim();
    const hasValidCronSecret = !!CRON_SECRET && !!cronSecret && cronSecret === CRON_SECRET;

    const service = createClient(SUPABASE_URL, SERVICE_KEY);

    if (!hasValidCronSecret) {
      if (!authHeader?.startsWith("Bearer ")) {
        return new Response(JSON.stringify({ error: "Missing Authorization" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      const userClient = createClient(SUPABASE_URL, ANON_KEY, {
        global: { headers: { Authorization: authHeader } },
      });
      const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
      const { data: userData, error: userErr } = await userClient.auth.getUser(jwt);
      if (userErr || !userData.user) {
        return new Response(JSON.stringify({ error: "Invalid session" }), {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
      const { data: roleRow, error: roleErr } = await service
        .from("users")
        .select("role")
        .eq("id", userData.user.id)
        .maybeSingle();
      if (roleErr || roleRow?.role !== "admin") {
        return new Response(JSON.stringify({ error: "Forbidden: admin only" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const body = await req.json().catch(() => ({}));
    const month = typeof body.month === "string" ? body.month : null;
    const courseId = typeof body.course_id === "string" ? body.course_id : null;
    const force = !!body.force;

    const { data, error } = await service.rpc("generate_monthly_dues", {
      p_month: month,
      p_course_id: courseId,
      p_force: force,
    });
    if (error) throw error;

    return new Response(
      JSON.stringify({
        success: true,
        result: data,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
