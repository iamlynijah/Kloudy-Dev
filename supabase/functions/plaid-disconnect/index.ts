import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  const auth = req.headers.get('Authorization')
  if (!auth) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { global: { headers: { Authorization: auth } } },
  )
  const { data: { user } } = await admin.auth.getUser()
  if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

  const { data: item } = await admin.from('plaid_items').select('access_token').eq('user_id', user.id).maybeSingle()
  if (item?.access_token) {
    const env = Deno.env.get('PLAID_ENV') ?? 'sandbox'
    await fetch(`https://${env}.plaid.com/item/remove`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: Deno.env.get('PLAID_CLIENT_ID'),
        secret: Deno.env.get('PLAID_SECRET'),
        access_token: item.access_token,
      }),
    })
  }
  await admin.from('plaid_items').delete().eq('user_id', user.id)
  return new Response(JSON.stringify({ disconnected: true }), { headers: { 'Content-Type': 'application/json' } })
})
