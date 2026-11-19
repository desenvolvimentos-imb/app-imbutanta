# Pesquisa e Decisões: Login e Papéis de Acesso

Todas as incógnitas do Contexto Técnico foram resolvidas abaixo. Valores de planos gratuitos
mudam com frequência: **reconfirmar nas páginas de preços antes de ir para produção**
(constitution VI).

## Decisão 1: Stack base

- **Decisão**: Next.js 16 (App Router) + TypeScript + Tailwind CSS, hospedado na Vercel;
  Supabase como autenticação e banco.
- **Justificativa**: escolha do dono do projeto (Supabase + Vercel). Combina com os princípios
  II e VI: autenticação e banco prontos, deploy automático por branch, tudo no plano gratuito.
  Next.js tem suporte oficial à Vercel e guia oficial do Supabase para cookies de sessão
  (`@supabase/ssr`).
- **Alternativas**: Vite + React puro (mais simples, mas sem servidor para proteger rotas e
  guardar a sessão em cookie; exigiria mais código para a mesma segurança); SvelteKit/Nuxt
  (boas, mas menos material e menos familiar para quem for manter).
- **Nota**: no Next.js 16 o antigo `middleware.ts` se chama `proxy.ts`.

## Decisão 2: Onde ficam as regras de acesso

- **Decisão**: RLS no Postgres + funções SQL `security definer` para as operações sensíveis
  (aprovar/recusar, alterar papel/situação, excluir conta). A interface só esconde opções por
  conveniência.
- **Justificativa**: RF-020 e constitution V exigem regra no servidor/banco. Com RLS, mesmo
  chamadas diretas à API do Supabase com a chave pública respeitam as regras. Funções SQL
  tornam cada operação **atômica** (constitution III) e permitem a checagem de conflito
  (RF-013) e do "último administrador" (RF-022) num só lugar.
- **Alternativas**: checar permissões só em Server Actions do Next (frágil: a chave pública do
  Supabase permite falar com o banco sem passar pelo Next); Edge Functions (mais uma peça
  para manter, sem ganho aqui).

## Decisão 3: Papel e situação lidos do banco, não do token

- **Decisão**: não usar *custom claims* no JWT. O servidor consulta `perfis` a cada requisição
  protegida; as políticas RLS usam uma função auxiliar (`situacao_e_papel_atual()`) que lê a
  tabela.
- **Justificativa**: RF-026 pede que mudança de papel valha sem novo login. Claims no token só
  atualizam quando o token é renovado (até ~1 hora). A consulta extra é uma leitura por chave
  primária, insignificante na nossa escala.
- **Alternativas**: custom access token hook (mais rápido em escala grande, porém com atraso
  e mais complexidade; viola YAGNI hoje).

## Decisão 4: Email transacional (confirmação e recuperação) {#decisao-4}

- **Decisão (revista em 2026-11-19)**: usar **SMTP próprio no Supabase com uma conta Gmail e
  "senha de app"** (guia oficial: *Using Google SMTP with Supabase Custom SMTP*). Em
  desenvolvimento local, continua o Mailpit que vem com o Supabase CLI. O Resend (plano
  gratuito) fica como alternativa para quando houver um domínio.
- **Justificativa**: o SMTP padrão do Supabase só entrega para membros da equipe do projeto e,
  desde as mudanças recentes do painel, **nem permite editar os templates de email** sem SMTP
  próprio. O Gmail com senha de app é gratuito, **não exige domínio** e o Supabase documenta o uso.
  A conta precisa de verificação em duas etapas ligada (requisito para criar a senha de app).
- **Limites e cuidados**: o Gmail tem cotas diárias de envio próprias (confira a cota atual no
  Google; para os poucos emails de confirmação de uma igreja, costuma bastar), o remetente
  aparece como o endereço Gmail (o nome exibido pode ser "IM Butantã") e o Google pode bloquear a
  conta se detectar envio suspeito. Com SMTP próprio o Supabase limita a 30 emails/hora por
  padrão (ajustável em *Authentication → Rate Limits*). Use uma conta dedicada ao app, não a
  pessoal, e guarde a senha de app só no painel do Supabase.
- **Resend**: o plano gratuito (~3.000 emails/mês, 100/dia, 1 domínio) só envia para qualquer
  destinatário depois de **verificar um domínio** por DNS; sem domínio, só permite testes para o
  próprio dono da conta. Vira a melhor opção se a igreja passar a ter um domínio.
- **Alternativas**: Brevo (300/dia grátis, também pede validação de remetente); depender do SMTP
  padrão (inviável: sem templates e sem entrega a terceiros).

## Decisão 5: Login com Google e vinculação de contas

- **Decisão**: provedor Google no Supabase Auth com fluxo PKCE; tela de consentimento do
  Google Cloud publicada "Em produção" pedindo apenas os escopos básicos (`openid`, `email`,
  `profile`).
- **Justificativa**: escopos básicos não exigem verificação do Google. Em modo "Teste" a
  tela limita a 100 usuários e expira a autorização em 7 dias; por isso deve ser publicada.
- **Vinculação (RF-005)**: o Supabase vincula identidades que compartilham o **mesmo email
  verificado** em uma única conta. Isso cobre "Google e depois senha" desde que o email do
  cadastro por senha seja confirmado. Ponto de atenção documentado no teste ponta a ponta:
  cadastro por senha **sem** confirmar e depois Google com o mesmo email; o comportamento do
  Supabase nesse caso deve ser verificado no ambiente local e coberto por teste.
- **Alternativas**: login só por Google (contraria RF-002 e exclui quem não tem conta Google).

## Decisão 6: Criação do perfil e primeiro administrador

- **Decisão**: um gatilho no Postgres, ao inserir em `auth.users`, cria o `perfil`
  (`situacao = pendente`, `papel = membro`) lendo o nome de `raw_user_meta_data`. Outro
  gatilho, ao confirmar o email (`email_confirmed_at`), sincroniza `email_verificado` e
  aplica o **administrador inicial**: se o email estiver na tabela
  `administradores_iniciais`, o perfil vira `aprovado` + `administrador`.
- **Justificativa**: RF-014 (dono do projeto como primeiro admin, sem fila) e premissa de
  "configuração prévia do ambiente". Exigir email **verificado** evita que um terceiro crie
  conta com o email do Arthur e vire administrador.
- **Como se configura**: o email do Arthur é inserido em `administradores_iniciais` por
  comando SQL no painel do Supabase de cada ambiente (não vai no repositório, pois é dado
  pessoal e específico do ambiente). A migração cria só a tabela vazia.
- **Alternativas**: variável de ambiente lida pelo app (o app não deve decidir papéis; e o
  gatilho do banco é mais difícil de burlar); promover na mão pelo painel (funciona, mas não
  é reproduzível nem testável).

## Decisão 7: Operações como funções SQL (RPC)

- **Decisão**: o app chama `decidir_cadastro`, `alterar_papel`, `alterar_situacao` e
  `excluir_minha_conta` via `supabase.rpc(...)`. Contratos em
  [contracts/banco-rpc.md](contracts/banco-rpc.md).
- **Justificativa**: atomicidade, verificação de conflito por `situacao_esperada` (RF-013),
  e um único lugar para a regra do último administrador (RF-022). A **proteção do último
  administrador também existe como gatilho em `perfis`**, para valer mesmo contra alteração
  direta.
- **Exclusão sem `service_role`**: `excluir_minha_conta` é `security definer` e apaga a linha
  em `auth.users` da própria pessoa (`auth.uid()`); `perfis` some por `on delete cascade`. Isso
  evita colocar a chave `service_role` (poderosíssima) no servidor do app (constitution V).
  Se um teste mostrar que o Supabase não permite apagar `auth.users` dessa forma, o plano B é
  uma rota de servidor com `service_role` protegida, registrada em ADR.

## Decisão 8: Limite de tentativas de login (RF-032)

- **Decisão**: usar os limites nativos do Supabase Auth e traduzir a resposta de excesso
  (HTTP 429 / `over_request_rate_limit`) para uma mensagem em pt-BR.
- **Justificativa**: zero código próprio e custo zero. A limitação nativa é **por IP**, não
  por conta; para a escala de uma igreja é aceitável.
- **Limitação aceita**: um atacante distribuído em vários IPs não é contido por conta. Se
  isso virar problema real, o próximo passo é CAPTCHA (Cloudflare Turnstile, gratuito, com
  suporte no Supabase). Registrado como possível evolução, não implementado (YAGNI).

## Decisão 9: Política de senha

- **Decisão**: mínimo de 8 caracteres exigindo letras e números, definido em
  `supabase/config.toml` (e igual no painel de produção), com a mesma regra repetida em
  `validacao.ts` para dar mensagem imediata na tela.
- **Justificativa**: RF-006. A verificação de senhas vazadas é recurso de plano pago e não
  será usada.
- **Atenção**: a regra no painel do Supabase de cada ambiente precisa ser configurada à mão
  (ou via `supabase config push`); listada na checklist do quickstart.

## Decisão 10: PWA

- **Decisão**: `app/manifest.ts` (nome, ícones, `display: standalone`, `lang: pt-BR`, cor do
  tema) + `public/sw.js` mínimo apenas para habilitar a instalação. **Sem cache offline** de
  páginas autenticadas.
- **Justificativa**: constitution I exige PWA instalável; o app exige internet (premissa). Cache
  agressivo de telas logadas arriscaria mostrar conteúdo a quem saiu da conta.
- **Alternativas**: Serwist/next-pwa (útil quando houver modo offline; hoje é complexidade
  sem necessidade).

## Decisão 11: Sessão e proteção de rotas

- **Decisão**: `@supabase/ssr` guarda a sessão em cookies; `proxy.ts` renova a sessão e
  redireciona quem não tem login para `/entrar` (com `?voltar=` para retornar à página
  tentada). A decisão por situação/papel acontece nos `layout.tsx` de cada grupo de rotas,
  usando `getUser()` (validado no servidor) e nunca somente dados do cookie.
- **Justificativa**: casos de borda "sessão expirada" e "voltar à página tentada";
  `getUser()` valida o token no Supabase, ao contrário de ler o cookie às cegas.
- **Segurança do redirecionamento**: `voltar` aceita apenas caminhos internos começando com
  `/` (evita *open redirect*); coberto por teste unitário.

## Decisão 12: Ambientes, implantação e CI

- **Decisão**:
  - **Local**: Supabase CLI (precisa de Docker) + `next dev`; é onde rodam os testes.
  - **Desenvolvimento/Preview**: um projeto Supabase gratuito (`imbutanta-dev`) + Vercel Preview
    (branch `develop` e branches de feature).
  - **Produção**: segundo projeto Supabase gratuito (`imbutanta-prod`) + Vercel Production
    (branch `main`).
  - **Migrações**: aplicadas pela **integração do Supabase com o GitHub** ("Deploy to
    production"), uma integração por projeto: o projeto dev acompanha a branch `develop` e o
    projeto prod acompanha a `main`. Detalhes em
    [ADR 0003](../../docs/decisions/0003-implantacao-de-migracoes.md).
  - CI no GitHub Actions rodando lint, tipos, Vitest, `supabase test db` e Playwright.
- **Justificativa**: a integração com o GitHub é gratuita e dispensa guardar token do Supabase
  nos segredos do GitHub. O **Supabase Branching** (banco de preview por PR) exige o plano Pro,
  então fica fora (constituição VI). Dois projetos gratuitos separam dados de teste dos reais
  (LGPD) e é o máximo que o plano gratuito permite.
- **Alternativa considerada, um único projeto**: `develop`, previews e produção compartilhando o
  mesmo banco. Funciona no plano gratuito e economiza configuração, mas testes e previews
  escreveriam em dados reais de membros (risco de privacidade) e uma migração com defeito
  derrubaria a produção. Rejeitada.
- **Fallback**: se a integração não oferecer o "Deploy to production" no plano gratuito, usar um
  workflow do GitHub Actions com `supabase db push` (precisa de `SUPABASE_ACCESS_TOKEN`, senha
  do banco e `project-ref` como segredos do GitHub).
- **Configurações de Auth (Site URL, Google, SMTP, senha) não são implantadas pela integração**
  (ela só leva migrações, funções e buckets); são feitas à mão no painel de cada projeto.
- **Risco**: projetos gratuitos do Supabase **pausam após ~1 semana sem atividade**. Em
  produção, o uso semanal da igreja evita; no projeto de desenvolvimento, aceitar a pausa e
  restaurar quando necessário.
- **Variáveis de ambiente** (nunca no git; ver `.env.example`): `NEXT_PUBLIC_SUPABASE_URL`,
  `NEXT_PUBLIC_SUPABASE_ANON_KEY` (chave pública, protegida por RLS). Chave `service_role`
  **não** é configurada no app. Na Vercel: escopo Production aponta para o projeto prod; escopo
  Preview (e Development) para o projeto dev.

## Decisão 13: Mensagens de erro em pt-BR

- **Decisão**: módulo `mensagens-erro.ts` que mapeia códigos de erro do Supabase
  (`invalid_credentials`, `user_already_exists`, `weak_password`,
  `over_request_rate_limit`, etc.) para frases em português; erro desconhecido cai em uma
  mensagem genérica amigável.
- **Justificativa**: RF-007 e RF-034. As mensagens de login e recuperação são deliberadamente
  genéricas para não revelar se um email existe. No cadastro, "email já cadastrado" usa texto
  neutro ("não foi possível criar a conta com estes dados; tente entrar ou recuperar a
  senha"), e o Supabase com confirmação de email já evita vazar a existência da conta.

## Limites gratuitos {#limites-gratuitos}

Valores de referência conhecidos no momento da pesquisa; confirmar nos sites oficiais
(supabase.com/pricing, vercel.com/pricing, resend.com/pricing):

- **Supabase Free**: 50 mil usuários ativos/mês, 500 MB de banco, 5 GB de saída, 2 projetos
  ativos, pausa por inatividade (~1 semana). SMTP padrão extremamente limitado.
- **Vercel Hobby**: gratuito para uso pessoal/não comercial, com cotas mensais de banda
  (ordem de 100 GB), execuções de função e builds. Um app de uma igreja sem fins lucrativos
  se encaixa no uso não comercial; se os termos mudarem ou forem interpretados de outra
  forma, a alternativa gratuita é Cloudflare Pages ou Netlify (trocar a hospedagem não muda
  o banco).
- **Resend Free**: ~3.000 emails/mês, 100/dia, 1 domínio.
- **Google Cloud OAuth**: sem custo para escopos básicos.

Com ≈ centenas de usuários, estamos a ordens de grandeza abaixo de todos os limites.
