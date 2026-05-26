import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? ''
const FROM_EMAIL = 'TraderLogJournal <no-reply@traderlogjournal.com>'
const ADMIN_EMAIL = 'dominskipatryk@gmail.com'

serve(async (req) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': 'https://traderlogjournal.com',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Weryfikuj tożsamość użytkownika przez JWT
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response('Unauthorized', { status: 401, headers: corsHeaders })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response('Unauthorized', { status: 401, headers: corsHeaders })
    }

    const email = user.email
    if (!email) {
      return new Response('No email', { status: 400, headers: corsHeaders })
    }

    if (!RESEND_API_KEY) {
      // Resend nie skonfigurowany — zaloguj i zwróć sukces
      console.log(`[password-changed-notify] RESEND_API_KEY not set. Would notify: ${email}`)
      return new Response(JSON.stringify({ success: true, note: 'RESEND_API_KEY not configured' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const timestamp = new Date().toLocaleString('pl-PL', { timeZone: 'Europe/Warsaw' })

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: email,
        reply_to: ADMIN_EMAIL,
        subject: 'Twoje hasło zostało zmienione — TraderLogJournal',
        html: `
          <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:32px;background:#0f1117;color:#e0e0e0;border-radius:12px">
            <div style="text-align:center;margin-bottom:24px">
              <div style="font-size:48px">🔐</div>
              <h2 style="color:#00d4a1;margin:8px 0">Hasło zostało zmienione</h2>
            </div>
            <p>Twoje hasło do <strong>TraderLogJournal</strong> zostało pomyślnie zmienione.</p>
            <p style="color:#999;font-size:13px">Data i czas: ${timestamp}</p>
            <p style="margin-top:24px;padding:14px;background:#1a1d24;border-radius:8px;border-left:3px solid #ef4444;font-size:13px">
              Jeśli to nie byłeś Ty, natychmiast skontaktuj się z administratorem:<br>
              <a href="mailto:${ADMIN_EMAIL}" style="color:#00d4a1">${ADMIN_EMAIL}</a>
            </p>
            <div style="text-align:center;margin-top:28px">
              <a href="https://traderlogjournal.com" style="display:inline-block;padding:12px 28px;background:#00d4a1;color:#0f1117;border-radius:8px;font-weight:700;text-decoration:none">
                Zaloguj się do aplikacji
              </a>
            </div>
            <p style="margin-top:32px;font-size:11px;color:#555;text-align:center">
              TraderLogJournal · traderlogjournal.com
            </p>
          </div>
        `,
      }),
    })

    if (!res.ok) {
      const body = await res.text()
      console.error('Resend error:', res.status, body)
      return new Response(JSON.stringify({ error: 'Email send failed', detail: body }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    return new Response(JSON.stringify({ success: true, email }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (err) {
    console.error('Function error:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
