# Requisitos iniciais — FoodBridge-Core-Supabase

## Escopo observado
Backend alternativo do FoodBridge com banco relacional, RLS e Edge Functions.

## Requisitos propostos para validação
- RF-01: Disponibilizar entrada e configuração dos componentes existentes.
- RF-02: Processar as operações documentadas mantendo interfaces atuais.
- RF-03: Tratar erros de validação e falhas de infraestrutura.
- RNF-01: Evitar segredos versionados e logs sensíveis.
- RNF-02: Garantir separação de responsabilidades, rastreabilidade e testes.
- RNF-03: Validar fluxo real antes de declarar funcionamento ou deploy.

**Pendente confirmar:** detalhes de rotas, permissões e integrações a partir do código/ambiente.

**Alerta:** Não presumir integração ativa com a API Kotlin. Evitar executar reset/migrations em banco compartilhado; revisar RLS e políticas antes de produção.
