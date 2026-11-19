# Guia de Execução e Validação: Login e Papéis de Acesso

Como preparar o ambiente e provar que a funcionalidade funciona de ponta a ponta. Detalhes de
dados e contratos: [data-model.md](data-model.md), [contracts/](contracts/). Os comandos
exatos serão ajustados quando o projeto for criado na implementação (`/speckit-implement`).

## Pré-requisitos

- Node.js 22 LTS e npm
- Docker Desktop (o Supabase local roda em contêineres)
- Supabase CLI (já vem como dependência do projeto: use `npx supabase`)
- Conta gratuita no Supabase, na Vercel e no Google Cloud (só para os ambientes online)

## 1. Rodar localmente

```bash
npm install
npx supabase start     # sobe Postgres, Auth e Mailpit locais
npx supabase db reset  # aplica migrações e seed.sql (contas de teste)
cp .env.example .env.local   # preencher com a URL e a chave pública exibidas pelo supabase start
npm run dev             # http://localhost:3000
```

Emails locais (confirmação, recuperação) aparecem no Mailpit (endereço mostrado pelo
`supabase start`), sem enviar nada de verdade.

Crie também `supabase/.env` (fora do git) com `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` e `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` (valores quaisquer bastam sem Google real).

Contas de teste do `seed.sql` (senha `Senha1234`) (apenas ambiente local): um administrador, um líder, um membro
aprovado, um pendente e um recusado. Credenciais ficam no próprio `seed.sql`, que é exclusivo
do ambiente local.

## 2. Testes automatizados

```bash
npm run lint
npm run typecheck
npm test                # Vitest: validação, mensagens de erro, redirecionamento seguro
npx supabase test db   # pgTAP: RLS, funções RPC, último administrador, exclusão
npm run test:e2e        # Playwright em tela de celular, usando email/senha
```

Resultado esperado: tudo verde. O CI roda o mesmo conjunto a cada PR.

## 3. Cenários de validação (mapeados aos critérios de sucesso)

| # | Cenário | Resultado esperado | Critério |
|---|---------|--------------------|----------|
| 1 | Cadastrar com email/senha, confirmar o email no Mailpit, entrar | cai em `/aguardando-aprovacao`; tempo < 2 min | CS-001 |
| 2 | Pendente abre `/inicio`, `/aprovacoes`, `/usuarios` pela barra de endereço | redirecionado para `/aguardando-aprovacao` | CS-004 |
| 3 | Líder aprova o pendente em ≤ 3 toques a partir de `/inicio` | pendente sai da fila; ao reabrir o app entra como membro | CS-003 |
| 4 | Líder recusa outro pendente | pessoa vê `/cadastro-recusado` | RF-010 |
| 5 | Dois aprovadores na mesma pessoa; o segundo age depois do primeiro | segundo recebe aviso de conflito | RF-013 |
| 6 | Membro abre `/aprovacoes` e `/usuarios` | acesso negado | CS-004 |
| 7 | Líder abre `/usuarios` | acesso negado | CS-004 |
| 8 | Administrador promove membro a líder (< 1 min); o líder, já conectado, atualiza a página | passa a ver "Aprovar cadastros" sem novo login | CS-007, RF-026 |
| 9 | Administrador único tenta rebaixar a si mesmo, remover o próprio acesso e excluir a própria conta | os três são impedidos com a mensagem explicativa | CS-008 |
| 10 | Pedir recuperação de senha (email existente e inexistente) | mesma mensagem neutra nos dois casos | RF-007 |
| 11 | Abrir o link de recuperação, definir nova senha, entrar com ela; tentar a antiga | nova funciona, antiga falha; reabrir o mesmo link mostra "expirou" | RF-027 |
| 12 | Senha errada repetidas vezes | mensagem genérica, depois aviso de limite | RF-032 |
| 13 | Sair do app e abrir uma rota protegida | pede login e volta à rota após entrar (`voltar`) | RF-029 |
| 14 | Excluir a própria conta (membro de teste) com confirmação; tentar entrar de novo | login falha; criar conta de novo começa como pendente | CS-006 |
| 15 | Chamada direta à API do Supabase (chave pública) por membro tentando ler perfis alheios ou chamar `decidir_cadastro` | zero linhas / erro `sem_permissao` | RF-020 |

## 4. Roteiro manual: Google (não automatizável)

Executar no ambiente online de desenvolvimento (Vercel Preview + Supabase dev), pois exige
Google real:

1. "Continuar com Google" com uma conta Google de teste → cai em `/aguardando-aprovacao`.
2. Aprovar pelo outro perfil; entrar de novo → `/inicio` de membro.
3. Com o **mesmo email**, criar conta por email/senha (e confirmar o email) → deve abrir a
   **mesma** conta e o mesmo papel, sem duplicidade (RF-005).
4. Entrar com o email do dono do projeto (cadastrado em `administradores_iniciais`) → abre
   direto como administrador, sem fila (RF-014).

## 5. Checklist de preparação dos ambientes online

Ordem recomendada (detalhes e o porquê em [ADR 0003](../../docs/decisions/0003-implantacao-de-migracoes.md)).
Repita o que for "por ambiente" para **desenvolvimento** e **produção**.

- [ ] Por ambiente: projeto Supabase criado (`imbutanta-dev` e `imbutanta-prod`, plano gratuito).
- [ ] Vercel: projeto ligado ao GitHub (`main` = produção); Node 22.x; variáveis
  `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_ANON_KEY` com o projeto **prod** no escopo
  Production e o projeto **dev** nos escopos Preview e Development; domínio fixo para `develop`.
- [ ] Por projeto, em *Authentication → URL Configuration*: Site URL (URL fixa do ambiente) e
  Redirect URLs (`/auth/callback` e `/auth/confirmar`; no dev, também o curinga dos previews).
- [ ] Por projeto, em *Authentication*: confirmação de email ligada; senha mínima 8 com letras e
  números; templates de email em português (`supabase/templates/`).
- [ ] Vercel: variável `EMAIL_CONTATO` (email da igreja para pedidos sobre dados) em Production e Preview;
  aparece em `/privacidade` e `/termos`. Redeploy depois de criar.
- [ ] Google Cloud: tela de consentimento **"Em produção"**, escopos básicos; um client OAuth Web
  com as duas URIs de retorno `https://<ref>.supabase.co/auth/v1/callback`; Client ID e Secret
  colocados no painel de cada projeto (não no git).
- [ ] SMTP próprio nos dois projetos (Gmail com senha de app, ou Resend se houver domínio; ver
  [research.md](research.md#decisao-4)). Sem SMTP próprio o Supabase não deixa editar os templates.
- [ ] Por projeto, integração Supabase + GitHub (*Project Settings → Integrations → GitHub*):
  repositório conectado, *Deploy to production* ligado, branch `develop` no dev e `main` no prod.
  A primeira implantação aplica as migrações existentes. (Alternativa: `supabase link` +
  `supabase db push` à mão.)
- [ ] Email do dono inserido em `administradores_iniciais` em cada projeto (ADR 0002).
- [ ] Branch protection em `main` e `develop` exigindo o check `verificar` (e o check do Supabase,
  se a integração o criar).
- [ ] Verificação de acessibilidade/mobile registrada no PR (CS-009).
