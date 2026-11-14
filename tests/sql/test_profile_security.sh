#!/usr/bin/env bash
set -euo pipefail
# Executar apenas no PostgreSQL efêmero preparado no job rls-security.
PSQL=(psql -X -qAt -v ON_ERROR_STOP=1)
id_self="00000000-0000-0000-0000-000000000010"
id_other="00000000-0000-0000-0000-000000000020"
id_admin="00000000-0000-0000-0000-000000000030"

"${PSQL[@]}" <<'SQL'
INSERT INTO auth.users (id,email,raw_user_meta_data,raw_app_meta_data) VALUES
('00000000-0000-0000-0000-000000000010','a@test.invalid',
 '{"nome_completo":"Pessoa A","tipo_usuario":"ADMIN"}'::jsonb,'{}'::jsonb),
('00000000-0000-0000-0000-000000000020','b@test.invalid',
 '{"nome_completo":"Pessoa B","tipo_usuario":"ADMIN"}'::jsonb,'{}'::jsonb),
('00000000-0000-0000-0000-000000000030','admin@test.invalid',
 '{"nome_completo":"Administrador"}'::jsonb,'{"tipo_usuario":"ADMIN"}'::jsonb);
SQL

# Uma conta com user_metadata=ADMIN não pode ser criada como perfil ADMIN.
role_self=$("${PSQL[@]}" -c "SELECT funcao FROM public.perfis WHERE id = '${id_self}'")
[[ "$role_self" == "DONOR" ]] || { echo "::error::Escalação via user_metadata"; exit 1; }
role_admin=$("${PSQL[@]}" -c "SELECT funcao FROM public.perfis WHERE id = '${id_admin}'")
[[ "$role_admin" == "ADMIN" ]] || { echo "::error::Admin confiável não foi reconhecido"; exit 1; }

# O usuário vê apenas seu perfil, apesar do SELECT concedido no nível de tabela.
visible=$("${PSQL[@]}" -c "BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub = '${id_self}'; SELECT count(*) FROM public.perfis; COMMIT;" | tr -d '[:space:]')
[[ "$visible" == "1" ]] || { echo "::error::RLS SELECT permitiu outros perfis"; exit 1; }

# Edição de campo comum do próprio perfil deve funcionar.
"${PSQL[@]}" -c "BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub = '${id_self}'; UPDATE public.perfis SET nome = 'Atualizado pelo titular' WHERE id = '${id_self}'; COMMIT;"
name=$("${PSQL[@]}" -c "SELECT nome FROM public.perfis WHERE id = '${id_self}'")
[[ "$name" == "Atualizado pelo titular" ]] || { echo "::error::Edição legítima bloqueada"; exit 1; }

# Não pode editar linha de outro titular mesmo quando só toca o campo nome.
"${PSQL[@]}" -c "BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub = '${id_self}'; UPDATE public.perfis SET nome='Ataque' WHERE id='${id_other}'; COMMIT;"
other_name=$("${PSQL[@]}" -c "SELECT nome FROM public.perfis WHERE id = '${id_other}'")
[[ "$other_name" == "Pessoa B" ]] || { echo "::error::RLS UPDATE cross-user"; exit 1; }

# UPDATE de função/status/email deve falhar por grant de coluna, mesmo em linha própria.
for field in funcao status email; do
  case "$field" in
    funcao) attempted="funcao='ADMIN'";;
    status) attempted="status='VERIFIED'";;
    email) attempted="email='ataque@test.invalid'";;
  esac
  if "${PSQL[@]}" -c "BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub = '${id_self}'; UPDATE public.perfis SET ${attempted} WHERE id='${id_self}'; COMMIT;" >/dev/null 2>&1; then
    echo "::error::Campo privilegiado editável: ${field}"; exit 1
  fi
done

# Não pode inserir ou excluir perfis via chave pública.
if "${PSQL[@]}" -c "BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub = '${id_self}'; DELETE FROM public.perfis WHERE id='${id_self}'; COMMIT;" >/dev/null 2>&1; then
  echo "::error::DELETE de perfil disponível a authenticated"; exit 1
fi

echo "PASS: trigger lê app_metadata; RLS restringe linha; grants impedem escalação."
