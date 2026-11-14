/** Regras puras para cadastro público de organização. Nenhuma credencial deve depender da requisição. */
import { isAllowedRegistrationRole } from './role-policy.ts'

export class InvalidRegistration extends Error {}
export type Registration = {
  email: string
  senha: string
  tipo_usuario: 'DONOR' | 'PRODUCER' | 'DISTRIBUTOR' | 'NGO'
  cnpj: string
  nome_completo: string
  telefone: string
  documentBytes: Uint8Array
}
const MAX_PDF_BYTES = 2 * 1024 * 1024
function validCnpj(cnpj: string): boolean {
  if (!/^\d{14}$/.test(cnpj) || /^(\d)\1+$/.test(cnpj)) return false
  const digits = [...cnpj].map(Number)
  const check = (n: number, weights: number[]) => {
    const rest = weights.reduce((sum, weight, i) => sum + digits[i] * weight, 0) % 11
    return digits[n] === (rest < 2 ? 0 : 11 - rest)
  }
  return check(12, [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) &&
    check(13, [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])
}
export function parseRegistration(value: unknown): Registration {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new InvalidRegistration('JSON de cadastro inválido')
  const p = value as Record<string, unknown>
  if (!isAllowedRegistrationRole(p.tipo_usuario)) throw new InvalidRegistration('Tipo de usuário inválido')
  if (typeof p.email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(p.email.trim()) || p.email.length > 254)
    throw new InvalidRegistration('E-mail inválido')
  if (typeof p.senha !== 'string' || p.senha.length < 12 || p.senha.length > 128)
    throw new InvalidRegistration('Senha precisa de 12 a 128 caracteres')
  if (typeof p.cnpj !== 'string' || !validCnpj(p.cnpj.replace(/\D/g, '')))
    throw new InvalidRegistration('CNPJ inválido')
  if (typeof p.nome_completo !== 'string' || p.nome_completo.trim().length < 2 || p.nome_completo.length > 120)
    throw new InvalidRegistration('Nome inválido')
  if (p.telefone !== undefined && (typeof p.telefone !== 'string' || p.telefone.length > 24))
    throw new InvalidRegistration('Telefone inválido')
  if (typeof p.documento_base64 !== 'string' ||
      p.documento_base64.length < 12 || p.documento_base64.length > Math.ceil(MAX_PDF_BYTES / 3) * 4 ||
      !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(p.documento_base64))
    throw new InvalidRegistration('Documento inválido ou acima de 2 MiB')
  let bytes: Uint8Array
  try { bytes = Uint8Array.from(atob(p.documento_base64), char => char.charCodeAt(0)) }
  catch { throw new InvalidRegistration('Documento base64 inválido') }
  if (bytes.length > MAX_PDF_BYTES || bytes.length < 8 || String.fromCharCode(...bytes.slice(0, 5)) !== '%PDF-')
    throw new InvalidRegistration('Envie um PDF válido de até 2 MiB')
  return {
    email: p.email.trim().toLowerCase(),
    senha: p.senha,
    tipo_usuario: p.tipo_usuario,
    cnpj: p.cnpj.replace(/\D/g, ''),
    nome_completo: p.nome_completo.trim(),
    telefone: typeof p.telefone === 'string' ? p.telefone.trim() : '',
    documentBytes: bytes,
  }
}
