Visão Geral

O FoodBridge é uma plataforma open source de redistribuição de alimentos que conecta doadores (restaurantes, supermercados, produtores rurais) com ONGs e instituições sociais. O objetivo é reduzir o desperdício de alimentos e ampliar o impacto social, utilizando uma arquitetura de baixo custo, escalável globalmente e baseada em serviços serverless.

Este repositório contém a implementação do backend e da infraestrutura utilizando o Supabase, uma alternativa open source ao Firebase, que oferece PostgreSQL, Autenticação, Armazenamento e Edge Functions.

Arquitetura

A arquitetura do FoodBridge no Supabase é projetada para ser eficiente, escalável e de baixo custo, aproveitando os recursos nativos da plataforma:

•
Supabase Auth: Gerenciamento de usuários, registro, login e controle de acesso.

•
PostgreSQL com PostGIS: Banco de dados relacional robusto com capacidades geoespaciais avançadas para buscas por localização e raio de distância.

•
Supabase Storage: Armazenamento seguro de documentos de verificação (CNPJ, licenças) e outras mídias relacionadas às doações.

•
Edge Functions (Deno): Funções de backend para lógica de negócio complexa, como registro de usuários com upload de documentos e aprovação administrativa, executadas em ambientes de borda para baixa latência.

•
Row Level Security (RLS): Políticas de segurança implementadas diretamente no banco de dados para controlar o acesso aos dados com base no perfil do usuário autenticado.

Requisitos Funcionais (MVP)

Módulos Implementados:

1.
Autenticação: Registro, login, recuperação de senha para Doadores e ONGs.

2.
Verificação de Usuários: Processo de aprovação administrativa para usuários (Doador/ONG) após o cadastro e upload de documentos.

3.
Publicação de Doação: Doadores podem publicar detalhes de doações, incluindo tipo de alimento, quantidade, validade e localização.

4.
Listagem de Doações: ONGs podem visualizar doações disponíveis, com busca por localização e raio de distância.

Estrutura do Repositório

Plain Text


foodbridge-supabase/
├── supabase/                  # Configurações e código do Supabase
│   ├── migrations/            # Scripts SQL para o banco de dados (tabelas, RLS, funções)
│   │   └── 20240315_foodbridge_core.sql # Migração principal com toda a estrutura
│   ├── functions/             # Edge Functions (TypeScript/Deno)
│   │   ├── registrar-usuario/ # Função para registro de novos usuários com upload de documentos
│   │   │   └── index.ts
│   │   └── aprovar-usuario/   # Função para aprovação/reprovação de usuários por administradores
│   │       └── index.ts
│   └── supabase.toml          # Configuração do CLI do Supabase
├── frontend/                  # Código-fonte da aplicação React (a ser desenvolvida)
├── .github/                   # Configurações do GitHub Actions para CI/CD
│   └── workflows/
│       └── deploy-functions.yml # Workflow para deploy automático das Edge Functions
└── README.md                  # Este arquivo



Configuração e Instalação

Pré-requisitos

•
Conta Supabase ativa.

•
Supabase CLI instalado e configurado.

•
Node.js (v18.x ou superior) e npm/yarn.

•
Deno (para desenvolvimento local de Edge Functions).

1. Configuração do Projeto Supabase

1.
Inicializar Projeto Local:

Bash


supabase init
supabase link --project-ref [SEU_PROJECT_REF]



Substitua [SEU_PROJECT_REF] pelo ID do seu projeto Supabase, encontrado no painel do Supabase.



2.
Aplicar Migrações do Banco de Dados:
As migrações SQL já estão configuradas para criar as tabelas, RLS e funções necessárias.

Bash


supabase migration up



Alternativa: Você pode copiar e colar o conteúdo de supabase/migrations/20240315_foodbridge_core.sql diretamente no SQL Editor do seu painel Supabase e executá-lo.



3.
Configurar Variáveis de Ambiente para Edge Functions:
As Edge Functions precisam de chaves de API para interagir com o Supabase. No seu painel Supabase, vá em Project Settings > API e copie a anon key e a service_role key.

Crie um arquivo .env.local na raiz do seu projeto (ou configure diretamente no painel Supabase para produção):

Plain Text


SUPABASE_URL="https://[SEU_PROJECT_REF].supabase.co"
SUPABASE_ANON_KEY="[SUA_ANON_KEY]"
SUPABASE_SERVICE_ROLE_KEY="[SUA_SERVICE_ROLE_KEY]"





4.
Deploy das Edge Functions:

Bash


supabase functions deploy registrar-usuario
supabase functions deploy aprovar-usuario





2. Configuração do Storage (Documentos de Verificação )

1.
No painel Supabase, vá em Storage.

2.
Crie um novo bucket com o nome documentos-verificacao.

3.
Verifique se as políticas de RLS para este bucket, conforme definidas na migração SQL, estão ativas.

3. Configuração do Frontend (React)

O frontend (a ser desenvolvido na pasta frontend/) precisará do SUPABASE_URL e SUPABASE_ANON_KEY para interagir com o Supabase. Utilize o SDK @supabase/supabase-js.

JavaScript


// Exemplo de inicialização no frontend
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.REACT_APP_SUPABASE_URL
const supabaseAnonKey = process.env.REACT_APP_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseAnonKey)



Implementação Automática (GitHub Actions)

Para facilitar o deploy contínuo das Edge Functions, você pode configurar o GitHub Actions. O arquivo .github/workflows/deploy-functions.yml (a ser criado) automatizará o deploy sempre que houver push para a branch main.

Variáveis de Ambiente do GitHub Secrets

No seu repositório GitHub, vá em Settings > Secrets and variables > Actions e adicione os seguintes segredos:

•
SUPABASE_ACCESS_TOKEN: Token de acesso pessoal do Supabase CLI (gerado via supabase login).

•
SUPABASE_PROJECT_ID: O ID do seu projeto Supabase.

