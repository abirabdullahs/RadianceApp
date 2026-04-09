// Admin-only: creates auth.users + public.users (no public signup).
// Deploy: supabase functions deploy create-student
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY (auto on Supabase).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const DOMAIN = "student.radiance.local";

function passwordFromPhoneDigits(digits11: string): string {
  if (digits11.length < 9) throw new Error("phone too short");
  return digits11.slice(-9);
}

function normalizeBdPhone(raw: string): string {
  const d = raw.replace(/\D/g, "");
  if (d.length === 11 && d.startsWith("01")) return d;
  throw new Error("মোবাইল ১১ সংখ্যা, ০১ দিয়ে শুরু হতে হবে");
}

const DUPLICATE_PHONE_MSG =
  "এই মোবাইল নম্বরে ইতিমধ্যে একজন শিক্ষার্থী নিবন্ধিত আছে। অন্য নম্বর দিন বা বিদ্যমান প্রোফাইল সম্পাদনা করুন।";

function isDuplicateKeyError(err: { code?: string; message?: string } | null): boolean {
  const m = (err?.message ?? "").toLowerCase();
  return err?.code === "23505" ||
    m.includes("duplicate key") ||
    m.includes("unique constraint") ||
    m.includes("users_phone_key");
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

  // Pass JWT explicitly — getUser() without args can ignore the global header in some runtimes.
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
      JSON.stringify({
        error: userErr?.message ?? "Invalid session",
        hint: "Try logging out and logging in again as admin.",
      }),
      {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);
  const { data: adminRow, error: roleErr } = await admin
    .from("users")
    .select("role")
    .eq("id", userData.user.id)
    .maybeSingle();

  if (roleErr || adminRow?.role !== "admin") {
    return new Response(JSON.stringify({ error: "Forbidden: admin only" }), {
      status: 403,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let digits: string;
  try {
    digits = normalizeBdPhone(String(body.phone ?? ""));
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const email = `${digits}@${DOMAIN}`;
  const password = passwordFromPhoneDigits(digits);

  const fullNameBn = String(body.full_name_bn ?? "").trim();
  if (!fullNameBn) {
    return new Response(JSON.stringify({ error: "full_name_bn required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const fullNameEn = body.full_name_en != null
    ? String(body.full_name_en).trim() || null
    : null;
  const guardianPhone = body.guardian_phone != null
    ? String(body.guardian_phone).trim() || null
    : null;
  const address = body.address != null
    ? String(body.address).trim() || null
    : null;
  const college = body.college != null
    ? String(body.college).trim() || null
    : null;
  const classLevel = body.class_level != null
    ? String(body.class_level).trim() || null
    : null;
  const dateOfBirth = body.date_of_birth != null
    ? String(body.date_of_birth).trim() || null
    : null;

  if (guardianPhone) {
    try {
      normalizeBdPhone(guardianPhone);
    } catch {
      return new Response(JSON.stringify({ error: "অভিভাবকের মোবাইল সঠিক নয়" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  }

  const { data: existingByPhone } = await admin
    .from("users")
    .select("id, student_id")
    .eq("phone", digits)
    .maybeSingle();

  if (existingByPhone) {
    return new Response(
      JSON.stringify({ error: DUPLICATE_PHONE_MSG, code: "DUPLICATE_PHONE" }),
      {
        status: 409,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { role: "student" },
    app_metadata: { role: "student" },
  });

  if (createErr || !created.user) {
    const raw = createErr?.message ?? "createUser failed";
    const lower = raw.toLowerCase();
    const dupAuth =
      lower.includes("already") ||
      lower.includes("registered") ||
      lower.includes("exists") ||
      lower.includes("duplicate");
    const msg = dupAuth ? DUPLICATE_PHONE_MSG : raw;
    return new Response(JSON.stringify({ error: msg }), {
      status: dupAuth ? 409 : 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const uid = created.user.id;
  const now = new Date().toISOString();

  const insertRow: Record<string, unknown> = {
    id: uid,
    phone: digits,
    email,
    full_name_bn: fullNameBn,
    full_name_en: fullNameEn,
    role: "student",
    guardian_phone: guardianPhone,
    address,
    college,
    class_level: classLevel,
    is_active: true,
    created_at: now,
    updated_at: now,
  };
  if (dateOfBirth) insertRow.date_of_birth = dateOfBirth;

  const { data: inserted, error: insErr } = await admin
    .from("users")
    .insert(insertRow)
    .select()
    .single();

  if (insErr) {
    await admin.auth.admin.deleteUser(uid);
    const msg = isDuplicateKeyError(insErr)
      ? DUPLICATE_PHONE_MSG
      : (insErr.message ?? "users insert failed");
    return new Response(JSON.stringify({ error: msg }), {
      status: isDuplicateKeyError(insErr) ? 409 : 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({
      id: uid,
      student_id: inserted.student_id,
      email,
      row: inserted,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
});
