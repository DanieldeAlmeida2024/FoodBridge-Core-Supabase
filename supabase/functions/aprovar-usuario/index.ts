import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req ) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Verificação de permissão administrativa
    const { data: { user } } = await supabaseClient.auth.getUser()
    const { data: perfilAdmin } = await supabaseAdmin
      .from('perfis')
      .select('tipo_usuario')
      .eq('id', user?.id)
      .single()

    if (perfilAdmin?.tipo_usuario !== 'Admin') {
      throw new Error('Acesso negado. Permissão administrativa necessária.')
    }

    const { usuario_id, aprovar } = await req.json()

    // 2. Atualização do status de verificação
    const { error: updateError } = await supabaseAdmin
      .from('perfis')
      .update({ esta_verificado: aprovar })
      .eq('id', usuario_id)

    if (updateError) throw updateError

    // 3. Registro em log de auditoria
    await supabaseAdmin.from('audit_logs').insert({
      user_id: user?.id,
      action: aprovar ? 'APROVACAO_USUARIO' : 'REPROVACAO_USUARIO',
      target_id: usuario_id,
      details: { timestamp: new Date().toISOString() }
    })

    return new Response(
      JSON.stringify({ mensagem: `Usuário ${aprovar ? 'aprovado' : 'reprovado'} com sucesso.` }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ erro: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
