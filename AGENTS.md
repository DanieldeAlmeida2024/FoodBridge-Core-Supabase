# Guia de colaboração e IA — FoodBridge-Core-Supabase

Backend alternativo do FoodBridge com banco relacional, RLS e Edge Functions.

## Ler primeiro
- `supabase/migrations`
- `supabase/functions`
- `.github/workflows`

## Invariantes
- Preservar stack e contratos existentes; não reescrever módulos por preferência de linguagem.
- Usar identificadores em português em componentes novos somente se compatível com o projeto.
- Distinguir funcionalidade real, hipótese, código de exemplo e teste simulado.
- Não divulgar segredos ou dados privados em logs, testes, commits ou documentação.
- Não alterar produção nem apagar bancos e execuções sem escopo e plano de recuperação.
- Antes de merge: revisar diff e executar teste nativo (supabase functions serve).

**Risco conhecido:** Não presumir integração ativa com a API Kotlin. Evitar executar reset/migrations em banco compartilhado; revisar RLS e políticas antes de produção.
