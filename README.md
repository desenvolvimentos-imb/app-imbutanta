# IM Butantã

App web (PWA) da Igreja Metodista no Butantã: escalas dos ministérios, informativos e área de
estudos. Tudo é escrito em português do Brasil. Regras do projeto: veja a
[constituição](.specify/memory/constitution.md) e o [guia de contribuição](CONTRIBUTING.md).

## Papéis e ministérios

O app tem dois papéis de conta: **administrador** e **membro**. A liderança é **por ministério**:
quem é líder do Louvor não é líder da Recepção. O administrador cria e desativa ministérios; o líder
gerencia os participantes e decide os pedidos de entrada do próprio ministério; qualquer pessoa
pode pedir para entrar em ministérios (inclusive no cadastro) e ver os seus em *Meus ministérios*.
Quando um líder aceita o pedido de uma conta nova, a conta é ativada. Detalhes em
[`specs/002-ministerios-participantes`](specs/002-ministerios-participantes/spec.md) e na
[ADR 0006](docs/decisions/0006-lideranca-por-ministerio.md).

## Escalas dos ministérios

O líder (ou o administrador) cadastra as **funções** do ministério (vocal, violão...) e as
**aptidões** de cada participante, monta a **escala** de cada evento com as vagas (a mesma pessoa
pode ocupar mais de uma), publica e acompanha as respostas. Quem está escalado vê tudo em
*Minhas escalas*, confirma ou recusa, e pode **pedir troca** de uma vaga: a pessoa indicada aceita e
o líder aprova (veja *Pedidos de troca*). O app avisa o líder, sem bloquear, quando alguém já
confirmou outra escala no mesmo dia em outro ministério ou não é apto para a função. Não há
notificações: cada pessoa vê a versão atual ao abrir o app. Detalhes em
[`specs/003-escalas-ministerios`](specs/003-escalas-ministerios/spec.md) e na
[ADR 0007](docs/decisions/0007-escalas-tempo-e-leitura.md).

## Tecnologias

- Next.js 16 (App Router) + TypeScript + Tailwind CSS, hospedado na Vercel
- Supabase: autenticação (Google e email/senha) e banco Postgres com RLS
- Testes: Vitest (unitários e, em `npm run test:integracao`, concorrência com duas sessões reais), pgTAP (banco) e Playwright (ponta a ponta)

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
npm run test:integracao # concorrência das escalas com duas sessões reais (exige supabase start)
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
feature usam o ambiente de desenvolvimento (Vercel Preview + projeto Supabase de
desenvolvimento). As migrações do banco vão para cada projeto por um workflow do GitHub Actions
ao fazer merge na branch acompanhada ([ADR 0005](docs/decisions/0005-migracoes-automatizadas.md);
a integração nativa citada na [ADR 0003](docs/decisions/0003-implantacao-de-migracoes.md) não
funcionou no plano gratuito).
Checklist de configuração dos ambientes online em
[`specs/001-login-papeis-acesso/quickstart.md`](specs/001-login-papeis-acesso/quickstart.md).

**Criando uma migração nova:** `npx supabase migration new nome_curto` (gera o arquivo com data e
hora) e teste com `npx supabase db reset && npm run test:db`. Nunca edite uma migração já aplicada
em ambiente online; crie uma nova.

## Problemas comuns nos ambientes online

- **Cadastro por email mostra "Algo deu errado":** quase sempre é o SMTP (envio do email de
  confirmação). O motivo real está em *Supabase → Logs → Auth* e no log da Vercel
  (`[auth] erro sem tradução`). Passo a passo em
  [`quickstart.md`](specs/001-login-papeis-acesso/quickstart.md#se-o-cadastro-por-email-falhar-com-algo-deu-errado).
- **Google mostra `redirect_uri_mismatch`:** falta a URL de retorno do projeto Supabase em uso nas
  *URIs de redirecionamento autorizadas* do Google Cloud (cada ambiente tem a sua).
- **Tela "Não foi possível carregar a sua conta":** o perfil não pôde ser lido, em geral porque as
  migrações não foram aplicadas naquele projeto Supabase.
