// Este módulo não usa SDK Supabase para ser testável sem acessar produção.
const PUBLIC_REGISTRATION_ROLES = ["DONOR", "PRODUCER", "DISTRIBUTOR", "NGO"] as const
type PublicRegistrationRole = typeof PUBLIC_REGISTRATION_ROLES[number]

export function isAllowedRegistrationRole(value: unknown): value is PublicRegistrationRole {
  return typeof value === "string" && PUBLIC_REGISTRATION_ROLES.some(role => role === value)
}

export function isTrustedAdminUser(
  user: { app_metadata?: { tipo_usuario?: unknown } } | null | undefined
): boolean {
  // raw_user_meta_data / user_metadata são editáveis pelo usuário: nunca autorizar por eles.
  return user?.app_metadata?.tipo_usuario === "ADMIN"
}
