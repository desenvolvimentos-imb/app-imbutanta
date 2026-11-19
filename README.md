# Imbutanta

App web (PWA) da Igreja Metodista no Butantã: escalas dos ministérios, informativos e área de
estudos. Tudo é escrito em português do Brasil. Regras do projeto: veja a
[constituição](.specify/memory/constitution.md) e o [guia de contribuição](CONTRIBUTING.md).

## Tecnologias

- Next.js 16 (App Router) + TypeScript + Tailwind CSS, hospedado na Vercel
- Supabase: autenticação (Google e email/senha) e banco Postgres com RLS
- Testes: Vitest (unitários), pgTAP (banco) e Playwright (ponta a ponta)

Decisões e o porquê delas ficam em [`docs/decisions/`](docs/decisions/).

## Como rodar localmente

Pré-requisitos: Node.js 22 ou superior, Docker Desktop aberto e npm.

```bash
npm install
cp .env.example .env.local        # depois preencha a chave exibida pelo comando abaixo
npx supabase start                # sobe banco, autenticação e caixa de emails de teste
npx supabase db reset             # aplica as migrações e as contas de teste (seed)
npm run dev                       # abre em http://localhost:3000
```

O `supabase start` mostra a URL do projeto local e a chave pública (`anon`/`publishable`):
copie-a para `NEXT_PUBLIC_SUPABASE_ANON_KEY` em `.env.local`. Também crie
`supabase/.env` com `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` e
`SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` (valores quaisquer bastam para rodar sem Google real).

Os emails de confirmação e de recuperação de senha **não são enviados de verdade** localmente:
abra a caixa de emails de teste (Mailpit) no endereço que o `supabase start` mostra.

## Testes

```bash
npm run lint         # estilo do código
npm run typecheck    # tipos TypeScript
npm test             # testes unitários (Vitest)
npm run test:db      # testes das regras do banco (pgTAP)
npm run test:e2e     # testes ponta a ponta (Playwright, celular emulado)
```

## Estrutura

```text
src/app/          telas e rotas (grupos: (publico), (situacao), (app))
src/lib/          clientes Supabase e regras de autenticação/permissões
src/components/   componentes de interface reutilizáveis
supabase/         configuração, migrações SQL, dados de teste e testes de banco
tests/            testes unitários e ponta a ponta
specs/            especificações, planos e tarefas (Spec Kit)
docs/decisions/   registros de decisão (ADR)
```

## Primeiro administrador

Ninguém vira administrador sozinho. O email do dono do projeto é inserido em
`administradores_iniciais` em cada ambiente (ver
[ADR 0002](docs/decisions/0002-administrador-inicial.md)); ao confirmar esse email, a conta
nasce aprovada como administradora.

## Publicação

`main` é produção (Vercel Production + projeto Supabase de produção); `develop` e as branches de
feature usam o ambiente de desenvolvimento. Checklist de configuração dos ambientes online em
[`specs/001-login-papeis-acesso/quickstart.md`](specs/001-login-papeis-acesso/quickstart.md).
