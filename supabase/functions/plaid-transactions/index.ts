import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function mapCategory(primary: string): string {
  switch (primary) {
    case 'FOOD_AND_DRINK':       return 'Food & Drink'
    case 'GENERAL_MERCHANDISE':  return 'Shopping'
    case 'TRANSPORTATION':       return 'Transport'
    case 'ENTERTAINMENT':        return 'Entertainment'
    case 'PERSONAL_CARE':        return 'Personal Care'
    case 'MEDICAL':              return 'Health'
    case 'TRAVEL':               return 'Travel'
    case 'HOME_IMPROVEMENT':     return 'Home'
    case 'RENT_AND_UTILITIES':   return 'Utilities'
    default:                     return 'Other'
  }
}

function getTransferType(primary: string): string | null {
  if (primary === 'LOAN_PAYMENTS') return 'loan_payment'
  if (primary === 'TRANSFER_OUT' || primary === 'TRANSFER_IN') return 'transfer'
  return null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } },
    )

    const { data: { user }, error } = await supabase.auth.getUser()
    if (error || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data: item } = await admin
      .from('plaid_items')
      .select('access_token, institution_name')
      .eq('user_id', user.id)
      .single()

    if (!item) {
      return new Response(JSON.stringify({ connected: false }), {
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    const env = Deno.env.get('PLAID_ENV') ?? 'sandbox'
    const now = new Date()
    const startDate = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
    const endDate = now.toISOString().split('T')[0]

    const txnRes = await fetch(`https://${env}.plaid.com/transactions/get`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        client_id: Deno.env.get('PLAID_CLIENT_ID'),
        secret: Deno.env.get('PLAID_SECRET'),
        access_token: item.access_token,
        start_date: startDate,
        end_date: endDate,
        options: { count: 100, include_personal_finance_category: true },
      }),
    })

    const txnData = await txnRes.json()

    const transactions = (txnData.transactions ?? [])
      .filter((t: any) => t.amount > 0) // exclude refunds / credits
      .map((t: any) => {
        const primary = t.personal_finance_category?.primary ?? ''
        const transferType = getTransferType(primary)
        return {
          id: t.transaction_id as string,
          merchantName: (t.merchant_name ?? t.name) as string,
          amount: t.amount as number,
          date: t.date as string,
          category: mapCategory(primary),
          accountId: t.account_id as string,
          isTransfer: transferType !== null,
          transferType,
        }
      })

    const accounts = (txnData.accounts ?? []).map((a: any) => ({
      id: a.account_id as string,
      name: (a.name ?? a.official_name) as string,
      type: a.subtype as string, // checking, savings, credit card, etc.
    }))

    return new Response(
      JSON.stringify({ connected: true, institution_name: item.institution_name, transactions, accounts }),
      { headers: { ...cors, 'Content-Type': 'application/json' } },
    )
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }
})
