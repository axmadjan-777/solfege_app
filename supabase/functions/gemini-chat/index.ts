import { MASTER_PROMPT } from "./master_prompt.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const jsonHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json; charset=utf-8",
};

type ChatRole = "user" | "model";

interface ChatMessage {
  role: ChatRole;
  text: string;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function getSupabasePublishableKey(): string | null {
  const rawKeys = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (rawKeys) {
    try {
      const keys = JSON.parse(rawKeys);
      if (typeof keys?.default === "string") return keys.default;
    } catch (error) {
      console.error("Invalid SUPABASE_PUBLISHABLE_KEYS", error);
    }
  }
  return Deno.env.get("SUPABASE_ANON_KEY") || null;
}

async function isAuthenticated(request: Request): Promise<boolean> {
  const authorization = request.headers.get("Authorization");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = getSupabasePublishableKey();
  if (
    !authorization?.startsWith("Bearer ") || !supabaseUrl || !publishableKey
  ) {
    return false;
  }

  try {
    const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {
        Authorization: authorization,
        apikey: publishableKey,
      },
    });
    return response.ok;
  } catch (error) {
    console.error("Supabase Auth validation failed", error);
    return false;
  }
}

function parseMessages(value: unknown): ChatMessage[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new Error("Отправьте хотя бы один вопрос.");
  }

  const messages = value.slice(-12).map((item) => {
    if (typeof item !== "object" || item === null) {
      throw new Error("Некорректная история чата.");
    }
    const role = (item as Record<string, unknown>).role;
    const text = (item as Record<string, unknown>).text;
    if ((role !== "user" && role !== "model") || typeof text !== "string") {
      throw new Error("Некорректная история чата.");
    }
    const normalized = text.trim();
    if (normalized.length === 0 || normalized.length > 4000) {
      throw new Error("Сообщение должно содержать от 1 до 4000 символов.");
    }
    return { role: role as ChatRole, text: normalized };
  });

  if (messages.at(-1)?.role !== "user") {
    throw new Error("Последнее сообщение должно быть вопросом пользователя.");
  }
  return messages;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Метод не поддерживается." }, 405);
  }
  if (!await isAuthenticated(request)) {
    return jsonResponse({ error: "Требуется авторизация." }, 401);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    console.error("GEMINI_API_KEY is not configured");
    return jsonResponse({ error: "Gemini пока не настроен." }, 503);
  }

  let messages: ChatMessage[];
  try {
    const payload = await request.json();
    messages = parseMessages(payload?.messages);
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "Некорректный запрос.";
    return jsonResponse({ error: message }, 400);
  }

  const model = Deno.env.get("GEMINI_MODEL") || "gemini-3.1-flash-lite";
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent`;

  try {
    const geminiResponse = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        systemInstruction: {
          parts: [{ text: MASTER_PROMPT }],
        },
        contents: messages.map((message) => ({
          role: message.role,
          parts: [{ text: message.text }],
        })),
        generationConfig: {
          temperature: 0.35,
          maxOutputTokens: 1200,
          thinkingConfig: {
            thinkingLevel: "minimal",
          },
        },
      }),
    });

    if (!geminiResponse.ok) {
      const errorBody = await geminiResponse.text();
      console.error(
        `Gemini request failed (${geminiResponse.status}): ${errorBody}`,
      );
      const status = geminiResponse.status === 429 ? 429 : 502;
      return jsonResponse(
        {
          error: status === 429
            ? "Достигнут лимит Gemini. Попробуйте немного позже."
            : "Gemini временно недоступен.",
        },
        status,
      );
    }

    const data = await geminiResponse.json();
    const parts = data?.candidates?.[0]?.content?.parts;
    const answer = Array.isArray(parts)
      ? parts
        .map((part: Record<string, unknown>) => part.text)
        .filter((text: unknown): text is string => typeof text === "string")
        .join("")
        .trim()
      : "";

    if (!answer) {
      console.error("Gemini returned no text candidate", data);
      return jsonResponse({ error: "Gemini не вернул текст ответа." }, 502);
    }
    return jsonResponse({ answer, model });
  } catch (error) {
    console.error("Gemini Edge Function failed", error);
    return jsonResponse({ error: "Gemini временно недоступен." }, 502);
  }
});
