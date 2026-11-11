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
