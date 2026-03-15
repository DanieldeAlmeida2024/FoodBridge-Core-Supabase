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
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { email, senha, tipo_usuario, cnpj, documento_base64, nome_arquivo, nome_completo, telefone } = await req.json()

    const cnpjLimpo = cnpj.replace(/\D/g, "")

    // 1. Criação no Auth com metadados alinhados ao Trigger SQL
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: senha,
      email_confirm: true,
      user_metadata: { 
        tipo_usuario, // Deve ser: 'DONOR', 'PRODUCER', 'DISTRIBUTOR', 'NGO', 'ADMIN'
        cnpj: cnpjLimpo, 
        nome_completo,
        telefone
      }
    })

    if (authError) throw authError
    const usuarioId = authData.user.id

    // 2. Upload para o bucket 'documentos-verificacao'
    const buffer = Uint8Array.from(atob(documento_base64), c => c.charCodeAt(0))
    
    const { error: storageError } = await supabaseAdmin.storage
      .from('documentos-verificacao')
      .upload(`${cnpjLimpo}/${nome_arquivo}`, buffer, {
        contentType: 'application/pdf',
        upsert: true
      })

    if (storageError) throw storageError

    return new Response(
      JSON.stringify({ mensagem: "Registro concluído. Perfil em análise.", usuarioId }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 201 }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ erro: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
