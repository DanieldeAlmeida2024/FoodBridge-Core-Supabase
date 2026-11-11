import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { isTrustedAdminUser } from "../_shared/role-policy.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req ) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authorization = req.headers.get('Authorization')
    if (!authorization?.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ erro: 'Autenticação obrigatória.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 401
      })
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authorization } } }
    )

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Uma função em public.perfis não é suficiente: essa coluna era editável por RLS.
    // Requer autorização independente em app_metadata, controlada pelo administrador.
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ erro: 'Sessão inválida.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 401
      })
    }

    if (!isTrustedAdminUser(user)) {
      return new Response(JSON.stringify({ erro: 'Acesso negado.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403
      })
    }

    const { data: perfilAdmin, error: perfilError } = await supabaseAdmin
      .from('perfis')
      .select('funcao,status')
      .eq('id', user.id)
      .single()

    if (perfilError || perfilAdmin?.funcao !== 'ADMIN' || perfilAdmin.status !== 'VERIFIED') {
      return new Response(JSON.stringify({ erro: 'Administrador não habilitado.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 403
      })
    }

    const { usuario_id, aprovar } = await req.json()
    if (typeof usuario_id !== 'string' || typeof aprovar !== 'boolean') {
      return new Response(JSON.stringify({ erro: 'Dados de aprovação inválidos.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400
      })
    }

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
