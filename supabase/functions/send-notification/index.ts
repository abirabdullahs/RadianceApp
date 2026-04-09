// Sends FCM (HTTP v1) for queued / explicit targets. Deploy: supabase functions deploy send-notification
//
// Secrets (Dashboard → Edge Functions → send-notification → Secrets, or CLI):
//   FCM_SERVICE_ACCOUNT_JSON — full Firebase service account JSON (same project as Flutter app).
//
// Auto env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";
import { GoogleAuth } from "npm:google-auth-library@9.14.2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Body = {
  user_ids?: string[];
  title?: string;
  body?: string;
  action_route?: string;
  type?: string;
};

async function getFcmAccessToken(serviceAccount: Record<string, unknown>): Promise<string> {
  const auth = new GoogleAuth({
    credentials: serviceAccount,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const client = await auth.getClient();
  const tokenResponse = await client.getAccessToken();
  const token = typeof tokenResponse === "string"
    ? tokenResponse
    : tokenResponse?.token;
  if (!token) throw new Error("GoogleAuth returned no access token");
  return token;
}

async function sendFcmV1(
  projectId: string,
  accessToken: string,
  deviceToken: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<{ ok: boolean; status: number; detail: string }> {
  const url =
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token: deviceToken,
        notification: { title, body },
        data,
        android: { priority: "HIGH" },
        apns: {
          headers: { "apns-priority": "10" },
        },
      },
    }),
  });
  const text = await res.text();
  if (!res.ok) {
    return { ok: false, status: res.status, detail: text };
  }
  return { ok: true, status: res.status, detail: text };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const rawJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!rawJson || rawJson.trim().length === 0) {
    return new Response(
      JSON.stringify({
        error: "FCM_SERVICE_ACCOUNT_JSON is not set",
        hint:
          "Add your Firebase service account JSON as a Supabase secret (same GCP project as FCM).",
      }),
      {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  let serviceAccount: Record<string, unknown>;
  try {
    serviceAccount = JSON.parse(rawJson) as Record<string, unknown>;
  } catch {
    return new Response(
      JSON.stringify({ error: "FCM_SERVICE_ACCOUNT_JSON is not valid JSON" }),
      {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const projectId = serviceAccount.project_id as string | undefined;
  if (!projectId || typeof projectId !== "string") {
    return new Response(
      JSON.stringify({
        error: "Service account JSON missing project_id",
      }),
      {
        status: 503,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
  const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "Missing Authorization" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!jwt) {
    return new Response(JSON.stringify({ error: "Empty bearer token" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser(jwt);
  if (userErr || !userData.user) {
    return new Response(
      JSON.stringify({ error: userErr?.message ?? "Invalid session" }),
      {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: callerRow, error: callerErr } = await admin
    .from("users")
    .select("role")
    .eq("id", userData.user.id)
    .maybeSingle();

  if (callerErr) {
    return new Response(JSON.stringify({ error: callerErr.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const role = (callerRow as { role?: string } | null)?.role;
  if (role !== "admin" && role !== "teacher") {
    return new Response(
      JSON.stringify({ error: "Only admin or teacher can send push" }),
      {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  let bodyJson: Body;
  try {
    bodyJson = (await req.json()) as Body;
  } catch {
    bodyJson = {};
  }

  const userIds = bodyJson.user_ids?.filter((id) =>
    typeof id === "string" && id.length > 0
  ) ?? [];
  const title = (bodyJson.title ?? "").trim();
  const bodyText = (bodyJson.body ?? "").trim();
  const actionRoute = (bodyJson.action_route ?? "").trim();
  const type = (bodyJson.type ?? "announcement").trim();

  if (userIds.length === 0) {
    return new Response(
      JSON.stringify({ error: "user_ids is required and must be non-empty" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
  if (!title || !bodyText) {
    return new Response(
      JSON.stringify({ error: "title and body are required" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  let accessToken: string;
  try {
    accessToken = await getFcmAccessToken(serviceAccount);
  } catch (e) {
    return new Response(
      JSON.stringify({
        error: "Failed to obtain Google access token",
        detail: String(e),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const { data: userRows, error: fetchErr } = await admin
    .from("users")
    .select("id, fcm_token")
    .in("id", userIds);

  if (fetchErr) {
    return new Response(JSON.stringify({ error: fetchErr.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const rows = (userRows ?? []) as { id: string; fcm_token: string | null }[];

  const dataPayload: Record<string, string> = {
    action_route: actionRoute,
    type,
    title,
    body: bodyText,
  };

  const results: {
    user_id: string;
    sent: boolean;
    skip?: string;
    error?: string;
  }[] = [];

  for (const row of rows) {
    const token = row.fcm_token?.trim();
    if (!token) {
      results.push({ user_id: row.id, sent: false, skip: "no_fcm_token" });
      continue;
    }

    const r = await sendFcmV1(
      projectId,
      accessToken,
      token,
      title,
      bodyText,
      dataPayload,
    );

    if (r.ok) {
      results.push({ user_id: row.id, sent: true });
    } else {
      results.push({
        user_id: row.id,
        sent: false,
        error: `${r.status}: ${r.detail}`,
      });
    }
  }

  const sentUserIds = results.filter((x) => x.sent).map((x) => x.user_id);
  if (sentUserIds.length > 0) {
    const { error: upErr } = await admin
      .from("notifications")
      .update({ fcm_sent: true })
      .in("user_id", sentUserIds)
      .eq("title", title)
      .eq("body", bodyText)
      .eq("fcm_sent", false);

    if (upErr) {
      console.error("notifications fcm_sent update:", upErr.message);
    }
  }

  return new Response(
    JSON.stringify({
      success: true,
      project_id: projectId,
      attempted: rows.length,
      sent: sentUserIds.length,
      results,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
});
