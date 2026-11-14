import assert from "node:assert/strict"
import test from "node:test"
import { isAllowedRegistrationRole, isTrustedAdminUser } from "../supabase/functions/_shared/role-policy.ts"

test("cadastros públicos só aceitam funções não administrativas", () => {
  for (const role of ["DONOR", "PRODUCER", "DISTRIBUTOR", "NGO"]) {
    assert.equal(isAllowedRegistrationRole(role), true)
  }
  for (const value of ["ADMIN", "admin", "", null, undefined, {}, 123]) {
    assert.equal(isAllowedRegistrationRole(value), false)
  }
})

test("usuário não eleva privilégios por metadados editáveis", () => {
  assert.equal(isTrustedAdminUser({ user_metadata: { tipo_usuario: "ADMIN" } } as never), false)
  assert.equal(isTrustedAdminUser({ app_metadata: { tipo_usuario: "DONOR" } }), false)
  assert.equal(isTrustedAdminUser({ app_metadata: {} }), false)
  assert.equal(isTrustedAdminUser(null), false)
})

test("função administrativa só é aceita em app_metadata confiável", () => {
  assert.equal(isTrustedAdminUser({ app_metadata: { tipo_usuario: "ADMIN" } }), true)
})

import { parseRegistration, InvalidRegistration } from "../supabase/functions/_shared/registration-policy.ts"

const good = () => ({
 email: 'Pessoa@Example.org', senha: 'senha-forte-de-teste-123', tipo_usuario: 'NGO',
 cnpj: '11.222.333/0001-81', nome_completo: 'Pessoa Exemplo', telefone: '+55 62 99999-9999',
 documento_base64: Buffer.from('%PDF-1.4\n%%EOF\n').toString('base64'),
})
test('cadastro normaliza campos, valida CNPJ e aceita PDF pequeno', () => {
 const p = parseRegistration(good())
 assert.equal(p.cnpj, '11222333000181')
 assert.equal(p.email, 'pessoa@example.org')
 assert.equal(p.documentBytes.length > 8, true)
})
test('cadastro público nega ADMIN, CNPJ adulterado e senhas fracas', () => {
 for (const change of [{tipo_usuario:'ADMIN'}, {cnpj:'11.222.333/0001-82'}, {senha:'123'}]) {
  assert.throws(() => parseRegistration({...good(), ...change}), InvalidRegistration)
 }
})
test('não aceita PDF adulterado, base64 inválido ou entrada enorme', () => {
 for (const documento_base64 of ['!', Buffer.from('not-pdf').toString('base64'), 'A'.repeat(3*1024*1024)]) {
  assert.throws(() => parseRegistration({...good(), documento_base64}), InvalidRegistration)
 }
})
test('não confia em nome de arquivo enviado pelo cliente', () => {
 const p = parseRegistration({...good(), nome_arquivo:'../../outro.pdf'})
 assert.equal(Object.prototype.hasOwnProperty.call(p,'nome_arquivo'), false)
})
