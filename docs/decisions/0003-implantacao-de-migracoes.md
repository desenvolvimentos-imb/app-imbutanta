# 0003 — Dois projetos Supabase e migrações pela integração com o GitHub

- **Data**: 2026-11-19
- **Situação**: Aceita
- **Origem**: plano de `001-login-papeis-acesso` (research, decisão 12)

## Contexto

O banco precisa de um ambiente de testes separado do de produção (dados reais de membros, LGPD),
e as migrações SQL do repositório precisam chegar a cada ambiente sem passos manuais frágeis. A
constituição exige custo zero (VI). O Supabase oferece (a) a integração com o GitHub, gratuita,
que implanta migrações ao fazer merge, e (b) o *Branching*, que cria um banco de preview por PR,
mas exige o plano Pro (pago).

## Decisão

- Dois projetos Supabase gratuitos: `imbutanta-dev` e `imbutanta-prod`.
- A integração Supabase + GitHub é ligada **nos dois projetos**, com "Deploy to production":
  o dev acompanha a branch `develop` e o prod acompanha a `main`. Merge na branch implanta as
  migrações do diretório `supabase/migrations/` no projeto correspondente.
- Migrações no formato `<data e hora>_<nome>.sql` (gerado por `supabase migration new`), para
  evitar colisão entre branches de feature.
- Branching (preview por PR) **não** é usado: exige plano pago.
- Configurações de Auth (URLs, Google, SMTP, senha, templates de email) **não** são levadas pela
  integração (ela implanta só migrações, funções e buckets); ficam no painel de cada projeto e
  na checklist do quickstart. `supabase/seed.sql` nunca é aplicado online.
- Fallback, se a integração não permitir o deploy no plano gratuito: workflow do GitHub Actions
  com `supabase db push` e segredos no GitHub.

## Alternativas consideradas

- **Um projeto só**: simples, mas previews e testes gravariam em dados reais e uma migração
  defeituosa derrubaria a produção. Rejeitada.
- **Supabase Branching**: ideal tecnicamente (banco por PR), porém pago. Reavaliar se o projeto
  um dia tiver orçamento (emenda à constituição).
- **`supabase db push` manual**: funciona e é grátis, mas depende de lembrar de rodar.

## Consequências

- (+) Migração implantada ao fazer merge, sem segredos extras no GitHub.
- (+) Dados de teste e reais separados.
- (−) Os previews da Vercel compartilham o banco do projeto dev (não há banco isolado por PR).
- (−) Configurações de Auth em duas telas de painel precisam ser mantidas iguais à mão.

## Atualização (2026-11-20)

No projeto de desenvolvimento, a integração com o GitHub **não aplicou as migrações sozinha** no
plano gratuito. Elas foram aplicadas colando os arquivos de `supabase/migrations/` (em ordem) no
*SQL Editor* do Supabase, e o histórico foi registrado à mão em `supabase_migrations.schema_migrations`
(criando o schema e a tabela se faltarem, com um registro por versão) para que a integração não
tente reaplicá-las. Esse é o procedimento de fallback aceito; vale também para o projeto de
produção. Migrações novas voltam a seguir a regra normal (arquivo novo, nunca editar o aplicado).

