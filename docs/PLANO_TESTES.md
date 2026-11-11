# Plano de testes — FoodBridge-Core-Supabase

- CT-01 Estrutural: documentos e UML encontrados (teste Python abaixo).
- CT-02 Build/teste nativo: `supabase functions serve`, com ambiente configurado.
- CT-03 Negativo: entradas inválidas e indisponibilidade de dependências.
- CT-04 Integração: validar acessos externos, autenticação e persistência conforme a stack.
- CT-05 Segurança: confirmar ausência de dados sensíveis em logs e artefatos.

Teste **somente documental**: `python -m unittest discover -s tests -p test_documentacao.py -v`.

CT-02 a CT-05 não são aprovados pelo teste de documentos. Não presumir integração ativa com a API Kotlin. Evitar executar reset/migrations em banco compartilhado; revisar RLS e políticas antes de produção.
