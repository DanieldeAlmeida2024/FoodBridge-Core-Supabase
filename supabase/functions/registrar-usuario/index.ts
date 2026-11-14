import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { InvalidRegistration, parseRegistration } from "../_shared/registration-policy.ts"

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Cache-Control': 'no-store',
  'Content-Type': 'application/json',
}
const json = (data: unknown, status: number) => new Response(JSON.stringify(data), { status, headers })

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers })
  if (req.method !== 'POST') return json({ erro: 'Método não permitido' }, 405)
  if (!req.headers.get('content-type')?.toLowerCase().includes('application/json')) return json({ erro: 'Envie JSON' }, 415)
  const url = Deno.env.get('SUPABASE_URL')
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!url || !key) return json({ erro: 'Cadastro indisponível' }, 503)

  // Limite antes do parse; o stream também é limitado, mesmo sem Content-Length.
  const maxBody = 3 * 1024 * 1024
  const length = Number(req.headers.get('content-length') || 0)
  if (length > maxBody || length < 0) return json({ erro: 'Requisição muito grande' }, 413)
  let size = 0
  const chunks: Uint8Array[] = []
  const reader = req.body?.getReader()
  if (!reader) return json({ erro: 'Corpo ausente' }, 400)
  try {
    while (true) {
      const { value, done } = await reader.read()
      if (done) break
      size += value.byteLength
      if (size > maxBody) { await reader.cancel(); return json({ erro: 'Requisição muito grande' }, 413) }
      chunks.push(value)
    }
  } catch { return json({ erro: 'Falha ao ler requisição' }, 400) }
  const body = new Uint8Array(size)
  let offset = 0
  for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.byteLength }

  let registration
  try { registration = parseRegistration(JSON.parse(new TextDecoder().decode(body))) }
  catch (error) {
    return json({ erro: error instanceof InvalidRegistration ? error.message : 'JSON inválido' }, 400)
  }

  const admin = createClient(url, key)
  let createdId: string | null = null
  try {
    const { data, error: createError } = await admin.auth.admin.createUser({
      email: registration.email,
      password: registration.senha,
      // Compatibilidade atual do onboarding: confirmação de e-mail requer
      // etapa própria antes do lançamento público. Não declarar identidade verificada.
      email_confirm: true,
      app_metadata: { tipo_usuario: registration.tipo_usuario },
      user_metadata: {
        nome_completo: registration.nome_completo,
        telefone: registration.telefone,
        cnpj: registration.cnpj,
      },
    })
    if (createError || !data.user?.id) return json({ erro: 'Não foi possível registrar a conta' }, 400)
    createdId = data.user.id
    // Não reutilizar caminho, CNPJ ou nome de arquivo fornecido pelo cliente.
    const { error: uploadError } = await admin.storage.from('documentos-verificacao')
      .upload(`${createdId}/verificacao.pdf`, registration.documentBytes, {
        contentType: 'application/pdf',
        upsert: false,
      })
    if (uploadError) throw new Error('STORAGE_UPLOAD_FAILURE')
    return json({ mensagem: 'Cadastro recebido. Perfil em análise.', usuarioId: createdId }, 201)
  } catch {
    // Cadastro de Auth e Storage não é uma transação distribuída.
    if (createdId) {
      const { error: rollbackError } = await admin.auth.admin.deleteUser(createdId)
      if (rollbackError) console.error('FoodBridge: compensação de cadastro falhou; intervenção operacional necessária')
    }
    return json({ erro: 'Cadastro não concluído' }, 503)
  }
})
