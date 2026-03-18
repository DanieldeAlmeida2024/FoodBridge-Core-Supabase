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

    // 1. Validação de Admin
    const { data: { user } } = await supabaseClient.auth.getUser()
    const { data: perfilAdmin } = await supabaseAdmin
      .from('perfis')
      .select('funcao')
      .eq('id', user?.id)
      .single()

    if (perfilAdmin?.funcao !== 'ADMIN') {
      throw new Error('Acesso negado. Requer privilégios de ADMIN.')
    }

    const { usuario_id, aprovar } = await req.json()

    // 2. Atualização de Status (conforme ENUM status_usuario)
    const novoStatus = aprovar ? 'VERIFIED' : 'PENDING_VERIFICATION'
    
    const { error: updateError } = await supabaseAdmin
      .from('perfis')
      .update({ status: novoStatus })
      .eq('id', usuario_id)

    if (updateError) throw updateError

    // 3. Auditoria
    await supabaseAdmin.from('registros_auditoria').insert({
      usuario_id: user?.id,
      acao: aprovar ? 'APROVACAO_USUARIO' : 'REPROVACAO_USUARIO',
      id_alvo: usuario_id,
      detalhes: { status_final: novoStatus }
    })

    return new Response(
      JSON.stringify({ mensagem: `Status do usuário atualizado para: ${novoStatus}` }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ erro: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
