#!/usr/bin/env bash
set -euo pipefail
PSQL=(psql -X -qAt -v ON_ERROR_STOP=1)
self=00000000-0000-0000-0000-000000000010
other=00000000-0000-0000-0000-000000000020

# Os IDs foram criados por test_profile_security.sh, executado antes deste script.
"${PSQL[@]}" <<SQL
INSERT INTO public.organizacoes (nome,cnpj,endereco,email,responsavel_id) VALUES
 ('Uma','11111111111111','{}','org1@test.invalid','$self'),
 ('Outra','22222222222222','{}','org2@test.invalid','$other');
INSERT INTO public.documentos (usuario_id,url) VALUES ('$self','privado-a.pdf'),('$other','privado-b.pdf');
INSERT INTO public.doacoes (doador_id,quantidade,unidade,data_validade,localizacao)
 VALUES ('$self',10,'KG',now()+interval '1 day','{}'),
        ('$other',20,'KG',now()+interval '1 day','{}');
SQL

visible=$("${PSQL[@]}" -c "BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub='$self'; SELECT count(*) FROM public.organizacoes; COMMIT;" | tr -d '[:space:]')
[[ "$visible" == "1" ]] || { echo "Org RLS falhou: visibilidade $visible"; exit 1; }
docs=$("${PSQL[@]}" -c "BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub='$self'; SELECT count(*) FROM public.documentos; COMMIT;" | tr -d '[:space:]')
[[ "$docs" == "1" ]] || { echo "Documentos RLS falhou"; exit 1; }
donations=$("${PSQL[@]}" -c "BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub='$self'; SELECT count(*) FROM public.doacoes; COMMIT;" | tr -d '[:space:]')
[[ "$donations" == "1" ]] || { echo "Doações RLS falhou"; exit 1; }

# Status, auditoria e transferência de recursos não podem ser alterados pelo titular.
for command in \
 "UPDATE public.organizacoes SET status='VERIFIED' WHERE responsavel_id='$self'" \
 "UPDATE public.organizacoes SET responsavel_id='$other' WHERE responsavel_id='$self'" \
 "UPDATE public.documentos SET status='VERIFIED' WHERE usuario_id='$self'" \
 "UPDATE public.documentos SET verificado_por='$self' WHERE usuario_id='$self'" \
 "UPDATE public.doacoes SET status='AVAILABLE' WHERE doador_id='$self'" \
 "UPDATE public.doacoes SET ong_reivindicadora_id='$self' WHERE doador_id='$self'"; do
  if "${PSQL[@]}" -c "BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub='$self'; $command; COMMIT;" >/dev/null 2>&1; then
    echo "Acesso privilegiado indevido: $command"; exit 1
  fi
done

# Escrita legítima permanece disponível com campos de menor privilégio.
"${PSQL[@]}" -c "BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub='$self'; UPDATE public.organizacoes SET nome='Atualizada' WHERE responsavel_id='$self'; UPDATE public.doacoes SET descricao_alimento='Lote revisado' WHERE doador_id='$self'; COMMIT;"
# Novos registros não podem escolher status publicado, verificado ou o titular de outra conta.
if "${PSQL[@]}" -c "BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub='$self'; INSERT INTO public.organizacoes (nome,cnpj,endereco,email,responsavel_id,status) VALUES ('Fraude','33333333333333','{}','x@test.invalid','$self','VERIFIED'); COMMIT;" >/dev/null 2>&1; then
 echo "Organização criada como verificada"; exit 1
fi
if "${PSQL[@]}" -c "BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub='$self'; INSERT INTO public.doacoes (doador_id,quantidade,unidade,data_validade,localizacao,status) VALUES ('$self',2,'KG',now()+interval '1 day','{}','AVAILABLE'); COMMIT;" >/dev/null 2>&1; then
 echo "Doação criada como publicada"; exit 1
fi
# Verifica os defaults aplicados na migração.
d=$("${PSQL[@]}" -c "SELECT status FROM public.doacoes LIMIT 1")
o=$("${PSQL[@]}" -c "SELECT status FROM public.organizacoes LIMIT 1")
[[ "$d" == "DRAFT" && "$o" == "PENDING_DOCUMENTS" ]] || { echo "Defaults inseguros"; exit 1; }
echo "PASS: organização, documentos e doações protegidos por RLS e grants por coluna."
