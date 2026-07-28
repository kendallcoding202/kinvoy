// Supabase Edge Function: suggest-activites
// Calls the Claude API server-side so the Anthropic key never ships in the app.
// Deploy:  supabase functions deploy suggest-activites
// Secret:  supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

import Anthropic from "npm:@anthropic-ai/sdk";

const anthropic = new Anthropic({ apiKey: Deno.env.get("ANTHROPIC_API_KEY") });

interface RequestBody {
  destination: string;
  start_date: string;
  end_date: string;
  focus?: string | null;
  notes?: string | null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid JSON" }), { status: 400 });
  }
  if (!body.destination || !body.start_date || !body.end_date) {
    return new Response(JSON.stringify({ error: "missing fields" }), { status: 400 });
  }

  const focusLine = body.focus ? `The family specifically wants: ${body.focus}.` : "";
  const notesLine = body.notes ? `Extra context from the family: ${body.notes}` : "";

  const prompt = `You are a local travel expert helping a family on vacation in ${body.destination} from ${body.start_date} to ${body.end_date}.
${focusLine}
${notesLine}

Suggest 6 specific, real things this family could do there. Prefer well-known, currently-operating places and activities; mix price levels; include at least one food suggestion and one backup option for bad weather unless the family asked for something specific.

Respond with ONLY a JSON object in exactly this shape, no other text:
{"suggestions":[{"title":"...","description":"1-2 sentences, concrete and family-oriented","category":"Outdoors|Food|Indoors|Rainy day|Free","emoji":"one emoji","cost_level":"Free|$|$$|$$$"}]}`;

  try {
    const message = await anthropic.messages.create({
      model: "claude-sonnet-5",
      max_tokens: 1500,
      messages: [{ role: "user", content: prompt }],
    });

    const text = message.content
      .filter((block) => block.type === "text")
      .map((block) => (block as { text: string }).text)
      .join("");

    // Tolerate stray prose around the JSON.
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");
    const parsed = JSON.parse(text.slice(start, end + 1));

    return new Response(JSON.stringify(parsed), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("suggest-activites failed:", error);
    return new Response(JSON.stringify({ error: "suggestion generation failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
