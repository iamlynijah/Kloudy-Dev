import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  const authorization = request.headers.get('Authorization');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!authorization || !supabaseUrl || !anonKey) {
    return jsonResponse({ error: 'Sign in to talk with Kloudy.' }, 401);
  }

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: authError } = await supabase.auth.getUser();
  if (authError || !userData.user) {
    return jsonResponse({ error: 'Your session has expired. Sign in again.' }, 401);
  }

  const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY');
  if (!anthropicKey) {
    console.error('ANTHROPIC_API_KEY is not configured for kloudy-ai.');
    return jsonResponse({ error: 'Kloudy is not available right now.' }, 503);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'The request could not be read.' }, 400);
  }

  const system = typeof body.system === 'string' ? body.system : '';
  const rawMessages = body.messages;
  if (!system || system.length > 20_000 || !Array.isArray(rawMessages) ||
      rawMessages.length < 1 || rawMessages.length > 40) {
    return jsonResponse({ error: 'The request is missing conversation details.' }, 400);
  }

  const messages: Array<{
    role: 'user' | 'assistant';
    content: string | Array<Record<string, unknown>>;
  }> = [];
  for (const item of rawMessages) {
    if (typeof item !== 'object' || item === null) {
      return jsonResponse({ error: 'The conversation contains an invalid message.' }, 400);
    }
    const role = (item as Record<string, unknown>).role;
    const content = (item as Record<string, unknown>).content;
    if (role !== 'user' && role !== 'assistant') {
      return jsonResponse({ error: 'The conversation contains an invalid message.' }, 400);
    }
    if (typeof content === 'string') {
      if (!content.length || content.length > 6_000) {
        return jsonResponse({ error: 'The conversation contains an invalid message.' }, 400);
      }
      messages.push({ role, content });
      continue;
    }
    if (role !== 'user' || !Array.isArray(content) || content.length < 1 || content.length > 3) {
      return jsonResponse({ error: 'The conversation contains an invalid message.' }, 400);
    }
    const blocks: Array<Record<string, unknown>> = [];
    for (const rawBlock of content) {
      if (typeof rawBlock !== 'object' || rawBlock === null) {
        return jsonResponse({ error: 'The conversation contains an invalid message.' }, 400);
      }
      const block = rawBlock as Record<string, unknown>;
      if (block.type === 'text' && typeof block.text === 'string' && block.text.length <= 6_000) {
        blocks.push({ type: 'text', text: block.text });
        continue;
      }
      const source = block.source;
      if (block.type === 'image' && typeof source === 'object' && source !== null) {
        const imageSource = source as Record<string, unknown>;
        const mediaType = imageSource.media_type;
        const imageData = imageSource.data;
        if (imageSource.type === 'base64' &&
            ['image/jpeg', 'image/png', 'image/gif', 'image/webp'].includes(String(mediaType)) &&
            typeof imageData === 'string' && imageData.length <= 7_000_000 &&
            /^[A-Za-z0-9+/]+={0,2}$/.test(imageData)) {
          blocks.push({
            type: 'image',
            source: { type: 'base64', media_type: mediaType, data: imageData },
          });
          continue;
        }
      }
      return jsonResponse({ error: 'The conversation contains an invalid message.' }, 400);
    }
    messages.push({ role, content: blocks });
  }

  const requestedTokens = typeof body.max_tokens === 'number' ? body.max_tokens : 512;
  const maxTokens = Math.max(32, Math.min(Math.floor(requestedTokens), 1_400));
  const model = body.model === 'claude-haiku-4-5-20251001'
    ? 'claude-haiku-4-5-20251001'
    : 'claude-sonnet-4-6';

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      signal: AbortSignal.timeout(30_000),
      headers: {
        'x-api-key': anthropicKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model,
        max_tokens: maxTokens,
        system,
        messages,
      }),
    });

    if (!response.ok) {
      // Do not log request bodies or provider response content; these can contain
      // sensitive personal health, financial, and journal information.
      console.error(`AI provider returned status ${response.status}.`);
      return jsonResponse({ error: 'Kloudy could not reply right now.' }, 502);
    }

    const result = await response.json();
    const text = result?.content?.find((part: { type?: string }) => part.type === 'text')?.text;
    if (typeof text !== 'string' || !text.trim()) {
      return jsonResponse({ error: 'Kloudy could not reply right now.' }, 502);
    }
    return jsonResponse({ text });
  } catch (error) {
    console.error('AI provider request failed.', error instanceof Error ? error.name : 'unknown');
    return jsonResponse({ error: 'Kloudy could not reply right now.' }, 502);
  }
});
