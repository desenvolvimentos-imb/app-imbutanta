---

description: "Lista de tarefas da funcionalidade Login e Papéis de Acesso"
---

# Tarefas: Login e Papéis de Acesso

**Entrada**: documentos de design em `specs/001-login-papeis-acesso/`

**Pré-requisitos**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Testes**: INCLUÍDOS e obrigatórios. A constitution (princípio IV) e o RF-035 exigem testes automatizados para login, papéis e permissões, escritos **antes ou junto** da implementação: cada teste deve ser visto falhando (vermelho) antes de a regra ser implementada (verde).

**Organização**: tarefas agrupadas por história de usuário para permitir implementar e testar cada uma de forma independente.

## Formato: `[ID] [P?] [História] Descrição`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência de tarefa incompleta)
- **[USn]**: história de usuário a que a tarefa pertence
- Todo texto de código, comentários e commits em pt-BR (constitution VII); comentários explicam o porquê

## Convenções de caminho

Projeto único Next.js na raiz do repositório: `src/`, `supabase/`, `tests/`, `public/`, `docs/` (ver estrutura em [plan.md](plan.md)).

---

## Fase 1: Preparação (infraestrutura compartilhada)

**Objetivo**: criar o projeto e as ferramentas básicas.

- [X] T001 Criar a branch `develop` a partir de `main` e preparar o PR da feature para `develop` (constitution, fluxo de branches); anotar no `CONTRIBUTING.md` se algo mudar *(branches `main` e `develop` já existiam e a feature sai de `develop`; o PR ainda não foi aberto)*
- [X] T002 Criar o projeto Next.js 16 (App Router, TypeScript, Tailwind, ESLint) na raiz do repositório, com `src/app/layout.tsx` em `lang="pt-BR"` e Node 22 fixado em `package.json` (`engines`)
- [X] T003 [P] Instalar dependências `@supabase/supabase-js`, `@supabase/ssr`, `zod` e de teste (`vitest`, `@playwright/test`) em `package.json`, com scripts `lint`, `typecheck`, `test`, `test:e2e`
- [X] T004 [P] Inicializar o Supabase CLI (`supabase init`) criando `supabase/config.toml`; ajustar Auth: confirmação de email ligada, senha mínima 8 com letras e números, URLs de retorno locais, provedor Google (lendo Client ID/Secret de variáveis de ambiente)
- [X] T005 [P] Criar `.env.example` com `NEXT_PUBLIC_SUPABASE_URL` e `NEXT_PUBLIC_SUPABASE_ANON_KEY` (sem valores reais) e garantir `.env*` (exceto o exemplo) no `.gitignore`
- [X] T006 [P] Configurar `vitest.config.ts` e `playwright.config.ts` (dispositivo de celular emulado, URL `http://localhost:3000`)
- [X] T007 [P] Criar o workflow `.github/workflows/ci.yml` rodando lint, typecheck, Vitest, `supabase test db` e Playwright a cada PR
- [X] T008 [P] Atualizar `README.md` com como rodar o projeto localmente (resumo do [quickstart.md](quickstart.md)), em pt-BR

---

## Fase 2: Fundação (pré-requisitos bloqueantes)

**Objetivo**: banco base, clientes Supabase, proteção de rotas e módulos compartilhados que todas as histórias usam.

**⚠️ CRÍTICO**: nenhuma história começa antes desta fase.

### Testes da fundação (escrever primeiro; devem falhar)

- [X] T009 [P] Escrever teste pgTAP do gatilho de criação de perfil e de sincronia de email (`pendente`/`membro` por padrão, nome vindo dos metadados) em `supabase/tests/001_criacao_perfil.test.sql`
- [X] T010 [P] Escrever teste pgTAP do administrador inicial (só vira administrador se o email estiver em `administradores_iniciais` **e** verificado) em `supabase/tests/002_administrador_inicial.test.sql`
- [X] T011 [P] Escrever teste pgTAP das políticas RLS de `perfis` (própria linha; admin vê todos; líder vê só pendentes verificados; anônimo nada; campos protegidos não editáveis) em `supabase/tests/003_rls_perfis.test.sql`
- [X] T012 [P] Escrever teste pgTAP do gatilho do último administrador (rebaixar, remover acesso e apagar o único administrador falham com `ultimo_administrador`) em `supabase/tests/004_ultimo_administrador.test.sql`
- [X] T013 [P] Escrever testes Vitest de `validarNome`, `validarEmail`, `validarSenha` em `tests/unit/validacao.test.ts` (nome vazio, só espaços, curto, >100; senha sem número/letra, <8)
- [X] T014 [P] Escrever testes Vitest de `traduzirErro` em `tests/unit/mensagens-erro.test.ts` (códigos conhecidos, erro desconhecido, 429, texto sem vazar existência de email)
- [X] T015 [P] Escrever testes Vitest de `caminhoVoltarSeguro` (aceita só caminhos internos; rejeita `//x`, `https://...`, `\\`) em `tests/unit/redirecionamento.test.ts`
- [X] T016 [P] Escrever testes Vitest de `destinoPorSituacao` e `podeAcessar` (tabela de redirecionamento e permissões por papel) em `tests/unit/permissoes.test.ts`

### Implementação da fundação

- [X] T017 Criar migração com enums `situacao_conta` e `papel_usuario`, tabela `perfis` (campos e restrições do [data-model.md](data-model.md)) e tabela `administradores_iniciais` (vazia, sem acesso para usuários) em `supabase/migrations/0001_perfis.sql`
- [X] T018 Na migração `supabase/migrations/0002_gatilhos_auth.sql`, criar os gatilhos em `auth.users`: criação do perfil `pendente`/`membro` com nome dos metadados (ou nome da conta Google), sincronia de `email`/`email_verificado` e aplicação do administrador inicial (faz T009 e T010 passarem)
- [X] T019 Criar a função auxiliar `perfil_atual()` (`security definer`, `stable`, `search_path` fixo) e habilitar RLS com as políticas de `perfis` em `supabase/migrations/0003_rls_perfis.sql` (faz T011 passar)
- [X] T020 Criar a proteção de campos (usuário comum só altera o próprio `nome`, feita por **permissões por coluna** em 0003, mais simples que um gatilho) e o gatilho do último administrador em `supabase/migrations/0004_regras_integridade.sql` (faz T011 e T012 passarem)
- [X] T021 [P] Implementar `src/lib/auth/validacao.ts` com esquemas Zod de nome, email e senha, mensagens em pt-BR (faz T013 passar)
- [X] T022 [P] Implementar `src/lib/auth/mensagens-erro.ts` mapeando códigos do Supabase e códigos das funções SQL (`sem_permissao`, `conflito_situacao`, `transicao_invalida`, `ultimo_administrador`, `nao_encontrado`, `over_request_rate_limit`) para pt-BR, com fallback genérico (faz T014 passar)
- [X] T023 [P] Implementar `src/lib/auth/redirecionamento.ts` com `caminhoVoltarSeguro` (faz T015 passar)
- [X] T024 [P] Implementar `src/lib/auth/permissoes.ts` com `destinoPorSituacao`, `podeAcessar` e a lista de atalhos por papel, como fonte única da interface (faz T016 passar)
- [X] T025 [P] Criar os clientes Supabase em `src/lib/supabase/client.ts` (navegador), `src/lib/supabase/server.ts` (servidor, cookies) e `src/lib/supabase/proxy.ts` (renovação de sessão)
- [X] T026 Implementar `src/lib/auth/sessao.ts` (`obterSessao()`: usa `getUser()` validado no servidor e lê o perfil; devolve usuário, situação e papel) e `src/proxy.ts` (renova sessão, redireciona quem não tem login para `/entrar?voltar=...` nas rotas protegidas)
- [X] T027 Criar `supabase/seed.sql` (somente ambiente local) com cinco contas de teste: administrador, líder, membro aprovado, pendente e recusado (documentar as credenciais no próprio arquivo, avisando que é só local)
- [X] T028 [P] Criar componentes base acessíveis em `src/components/` (`Campo.tsx` com rótulo visível e `aria-describedby` para erro, `Botao.tsx` com alvo ≥ 44 px, `MensagemErro.tsx` com `role="alert"`, `Cabecalho.tsx`) e o estilo base mobile-first
- [X] T029 [P] Criar `src/app/manifest.ts` (nome, ícones, `display: standalone`, `lang: pt-BR`), ícones em `public/icons/` e `public/sw.js` mínimo (sem cache de páginas autenticadas), registrado em `src/app/layout.tsx`

**Ponto de verificação**: `supabase db reset` aplica migrações e seed; `supabase test db` e `npm test` passam; `npm run dev` abre.

---

## Fase 3: História 1 - Criar conta e aguardar aprovação (Prioridade: P1) 🎯 MVP

**Meta**: criar conta por Google ou email/senha e cair na tela de aguardando aprovação, sem acesso a conteúdo.

**Teste independente**: criar conta pelos dois métodos; em ambos a pessoa fica `pendente` e só vê a tela de espera; acessar qualquer rota protegida pelo endereço leva de volta à espera.

### Testes da História 1 (escrever primeiro; devem falhar)

- [X] T030 [P] [US1] Teste Playwright: cadastro com email/senha (confirmar email no Mailpit local), cai em `/aguardando-aprovacao`; email duplicado e senha fraca mostram mensagem em pt-BR; pendente abrindo `/inicio`, `/aprovacoes`, `/usuarios` volta à espera, em `tests/e2e/cadastro.spec.ts`
- [X] T031 [P] [US1] Teste pgTAP: pendente não lê nada além do próprio perfil e não consegue se auto-aprovar nem alterar `papel`/`situacao`, em `supabase/tests/005_pendente_sem_acesso.test.sql`

### Implementação da História 1

- [X] T032 [P] [US1] Criar o grupo `src/app/(publico)/layout.tsx` (redireciona quem já tem sessão para o destino da situação) e a página `src/app/(publico)/cadastrar/page.tsx` com formulário (nome, email, senha) e botão "Continuar com Google"
- [X] T033 [US1] Implementar a Server Action de cadastro (valida com Zod, chama `signUp` com `nome` nos metadados, mensagem neutra para email já cadastrado, aviso "confirme seu email") em `src/app/(publico)/cadastrar/actions.ts`
- [X] T034 [US1] Implementar o início do login com Google (`signInWithOAuth`, PKCE, `redirectTo` para `/auth/callback`) em `src/components/BotaoGoogle.tsx` e a rota `src/app/auth/callback/route.ts` (troca o código por sessão e redireciona pela situação; nome do Google já vem nos metadados)
- [X] T035 [US1] Implementar `src/app/auth/confirmar/route.ts` para o link de confirmação de email (`verifyOtp`) redirecionando pela situação
- [X] T036 [P] [US1] Criar o grupo `src/app/(situacao)/layout.tsx` (exige sessão; redireciona aprovados para `/inicio`) e as telas `aguardando-aprovacao/page.tsx`, `cadastro-recusado/page.tsx` e `acesso-removido/page.tsx`, com botão "Sair"
- [X] T037 [US1] Criar o grupo `src/app/(app)/layout.tsx` que exige conta `aprovado` e redireciona as demais situações pelo `destinoPorSituacao`, e uma página provisória `src/app/(app)/inicio/page.tsx` (substituída na US2)
- [X] T038 [US1] Implementar a Server Action de sair (`signOut`) em `src/app/actions/sair.ts` e usá-la nas telas de situação

**Ponto de verificação**: T030 e T031 passam; cenários 1 e 2 do [quickstart.md](quickstart.md) validados.

---

## Fase 4: História 2 - Entrar, ver a tela inicial do papel e sair (Prioridade: P1)

**Meta**: entrar (Google ou email/senha), ver a tela inicial do papel, sair, permanecer conectado entre visitas.

**Teste independente**: com uma conta de cada papel, entrar e ver telas iniciais diferentes e só as ações permitidas.

### Testes da História 2 (escrever primeiro; devem falhar)

- [X] T039 [P] [US2] Teste Playwright: entrar com cada conta do seed (administrador, líder, membro) e conferir os atalhos de `/inicio` por papel; senha errada mostra mensagem genérica; sair e abrir rota protegida pede login e volta à rota (`voltar`); sessão persiste ao recarregar, em `tests/e2e/entrar.spec.ts`
- [X] T040 [P] [US2] Teste Playwright: o mesmo email por email/senha e (simulado via API de teste do Auth local) por outra identidade abre a mesma conta e o mesmo papel, em `tests/e2e/vinculacao-email.spec.ts`; documentar limites da simulação do Google no próprio arquivo

### Implementação da História 2

- [X] T041 [P] [US2] Criar `src/app/(publico)/entrar/page.tsx` (email, senha, "Continuar com Google", links para cadastrar e recuperar senha) e a Server Action em `src/app/(publico)/entrar/actions.ts` (`signInWithPassword`, mensagem genérica, tratamento do limite de tentativas via `traduzirErro`, respeita `voltar` com `caminhoVoltarSeguro`)
- [X] T042 [US2] Implementar `src/app/(app)/inicio/page.tsx` com saudação e conteúdo por papel a partir de `permissoes.ts` (membro: espaços reservados; líder: + "Aprovar cadastros"; administrador: + "Gerenciar usuários"), substituindo a provisória
- [X] T043 [P] [US2] Criar `src/app/(app)/conta/page.tsx` com dados da conta (nome, email) e botão "Sair"
- [X] T044 [US2] Tratar sessão expirada no meio do uso (redirecionar a `/entrar?voltar=`) e o caso do email já ligado a outra identidade, verificando no Supabase local o comportamento de vinculação descrito na Decisão 5 de [research.md](research.md); registrar o resultado em `research.md` *(sessão expirada: coberta pelo `proxy.ts` e pelo teste de `voltar`; vinculação Google + senha só é verificável com Google real e ficou no roteiro manual T071)*

**Ponto de verificação**: T039 e T040 passam; cenários 13 do [quickstart.md](quickstart.md) validado.

---

## Fase 5: História 3 - Aprovar ou recusar novos usuários (Prioridade: P1)

**Meta**: administrador e líder aprovam ou recusam pendentes; o primeiro administrador é o dono do projeto.

**Teste independente**: com uma conta pendente e uma aprovadora, aprovar e recusar e verificar o efeito no acesso.

### Testes da História 3 (escrever primeiro; devem falhar)

- [X] T045 [P] [US3] Teste pgTAP de `decidir_cadastro`: admin e líder podem; membro e pendente recebem `sem_permissao`; aprovar dá papel `membro`; só atua em `pendente` com email verificado; não decide a si mesmo; conflito de situação devolve `conflito_situacao`; grava `decidido_por`/`decidido_em`, em `supabase/tests/006_decidir_cadastro.test.sql`
- [X] T046 [P] [US3] Teste Playwright: líder aprova um pendente em ≤ 3 toques a partir de `/inicio`, o pendente passa a entrar como membro; outro é recusado e vê `/cadastro-recusado`; membro abrindo `/aprovacoes` é barrado; dois aprovadores em conflito veem o aviso, em `tests/e2e/aprovacao.spec.ts`

### Implementação da História 3

- [X] T047 [US3] Criar a função `decidir_cadastro` conforme [contracts/banco-rpc.md](contracts/banco-rpc.md) em `supabase/migrations/0005_decidir_cadastro.sql` (faz T045 passar)
- [X] T048 [US3] Criar `src/app/(app)/aprovacoes/page.tsx` listando pendentes com email verificado (nome e data em America/Sao_Paulo, formato brasileiro), guardado por `podeAcessar` (admin e líder), e a Server Action de aprovar/recusar em `src/app/(app)/aprovacoes/actions.ts` com `situacao_esperada` e tradução de erros
- [X] T049 [US3] Mostrar a contagem de pendentes no atalho "Aprovar cadastros" em `src/app/(app)/inicio/page.tsx`
- [X] T050 [US3] Documentar no `README.md` e em `docs/decisions/0002-administrador-inicial.md` como inserir o email do dono em `administradores_iniciais` em cada ambiente (SQL de exemplo, sem email real)

**Ponto de verificação**: T045 e T046 passam; cenários 3 a 7 do [quickstart.md](quickstart.md) validados. **MVP completo (US1 + US2 + US3)**: dá para colocar no ar e usar.

---

## Fase 6: História 4 - Recuperar acesso à conta (Prioridade: P2)

**Meta**: redefinir a senha por link seguro, com resposta neutra; quem usa só Google recupera pelo Google.

**Teste independente**: pedir recuperação, usar o link, definir nova senha e entrar.

### Testes da História 4 (escrever primeiro; devem falhar)

- [X] T051 [P] [US4] Teste Playwright: recuperação com email existente e inexistente mostra a mesma mensagem; link do Mailpit leva a `/redefinir-senha`; nova senha funciona e a antiga não; reabrir o link mostra "expirou", em `tests/e2e/recuperar-senha.spec.ts`

### Implementação da História 4

- [X] T052 [P] [US4] Criar `src/app/(publico)/recuperar-senha/page.tsx` e a Server Action (`resetPasswordForEmail`, sempre a mesma mensagem) em `src/app/(publico)/recuperar-senha/actions.ts`
- [X] T053 [US4] Estender `src/app/auth/confirmar/route.ts` para o tipo `recovery` (valida o link e abre `/redefinir-senha`; link inválido/expirado mostra aviso com opção de novo pedido)
- [X] T054 [US4] Criar `src/app/(publico)/redefinir-senha/page.tsx` e a Server Action (`updateUser({ password })`, mesma regra de senha, confirmação da senha) em `src/app/(publico)/redefinir-senha/actions.ts`
- [X] T055 [P] [US4] Na tela `/entrar`, orientar quem usa Google ("Se você entra com o Google, recupere o acesso pela sua conta Google") em `src/app/(publico)/recuperar-senha/page.tsx`

**Ponto de verificação**: T051 passa; cenários 10 a 12 do [quickstart.md](quickstart.md) validados.

---

## Fase 7: História 5 - Excluir a própria conta e os dados (LGPD) (Prioridade: P2)

**Meta**: a pessoa exclui conta e dados após confirmar; o único administrador não pode.

**Teste independente**: excluir uma conta de teste; login deixa de funcionar e a pessoa some das listas.

### Testes da História 5 (escrever primeiro; devem falhar)

- [X] T056 [P] [US5] Teste pgTAP de `excluir_minha_conta`: remove `auth.users` e `perfis` (nome, email, identidades); funciona em qualquer situação; único administrador recebe `ultimo_administrador`; só atua em `auth.uid()`; anônimo sem acesso, em `supabase/tests/007_excluir_conta.test.sql`
- [X] T057 [P] [US5] Teste Playwright: excluir exige confirmação e desistir não apaga nada; depois de excluir o login falha e um novo cadastro começa `pendente`; administrador único é impedido, em `tests/e2e/excluir-conta.spec.ts`

### Implementação da História 5

- [X] T058 [US5] Criar a função `excluir_minha_conta` em `supabase/migrations/0006_excluir_conta.sql` (faz T056 passar); se o Supabase não permitir apagar `auth.users` por função SQL, registrar o plano B em `docs/decisions/0003-exclusao-de-conta.md` (rota de servidor com `service_role`, protegida) e ajustar [contracts/banco-rpc.md](contracts/banco-rpc.md)
- [X] T059 [US5] Adicionar a seção "Excluir minha conta" em `src/app/(app)/conta/page.tsx` com confirmação em duas etapas (explica o que será apagado) e a Server Action em `src/app/(app)/conta/actions.ts` (chama a função, encerra a sessão, redireciona a `/entrar`)
- [X] T060 [P] [US5] Oferecer a exclusão também nas telas `cadastro-recusado` e `acesso-removido` em `src/app/(situacao)/`, reutilizando o componente de confirmação em `src/components/ExcluirConta.tsx`

**Ponto de verificação**: T056 e T057 passam; cenários 9 (parte da exclusão) e 14 do [quickstart.md](quickstart.md) validados.

---

## Fase 8: História 6 - Gerenciar papéis de usuários (Prioridade: P3)

**Meta**: o administrador lista usuários, altera papéis e remove ou restaura acesso; reabre cadastros recusados.

**Teste independente**: promover um membro a líder, ver que ele passa a aprovar, rebaixar de volta.

### Testes da História 6 (escrever primeiro; devem falhar)

- [X] T061 [P] [US6] Teste pgTAP de `alterar_papel` e `alterar_situacao`: só administrador; transições da tabela do [data-model.md](data-model.md) (e `transicao_invalida` para o resto); `ultimo_administrador`; conflito de situação; reaprovar entra como `membro`, em `supabase/tests/008_alterar_papel_situacao.test.sql`
- [X] T062 [P] [US6] Teste Playwright: administrador promove membro a líder em < 1 min e o líder conectado vê "Aprovar cadastros" ao atualizar, sem novo login; líder e membro barrados em `/usuarios`; administrador único não consegue rebaixar-se nem remover o próprio acesso, em `tests/e2e/papeis.spec.ts`

### Implementação da História 6

- [X] T063 [US6] Criar `alterar_papel` e `alterar_situacao` em `supabase/migrations/0007_gestao_usuarios.sql` (faz T061 passar)
- [X] T064 [US6] Criar `src/app/(app)/usuarios/page.tsx` (lista com filtro por situação, papel atual, ações de alterar papel, remover/restaurar acesso e reaprovar recusados; somente administrador) e `src/app/(app)/usuarios/actions.ts` com `situacao_esperada` e tradução de erros
- [X] T065 [US6] Registrar no `data-model.md` a nota de que a tabela de participação em ministérios fica para a funcionalidade futura (já descrito); conferir que nenhuma tabela de ministério foi criada

**Ponto de verificação**: T061 e T062 passam; cenários 8 e 9 do [quickstart.md](quickstart.md) validados.

---

## Fase 9: Acabamento e itens transversais

**Objetivo**: qualidade, acessibilidade, segurança e publicação.

- [X] T066 [P] Teste Playwright de segurança por chamada direta à API do Supabase com chave pública (membro lendo perfis alheios e chamando `decidir_cadastro`; anônimo sem acesso) em `tests/e2e/seguranca-api.spec.ts` (cenário 15 do quickstart)
- [ ] T067 [P] Revisar acessibilidade WCAG AA e mobile de todas as telas (contraste, foco visível, rótulos, `aria-describedby`, alvos ≥ 44 px, leitor de tela) e registrar o resultado no checklist do PR (CS-009) *(parte automática feita: `tests/e2e/acessibilidade.spec.ts` com axe-core passa em todas as telas; falta a revisão manual com leitor de tela/zoom e o registro no PR)*
- [ ] T068 [P] Medir carga da tela inicial em conexão móvel simulada (< 10 s, CS-002) e contar toques dos fluxos (CS-002, CS-003)
- [X] T069 [P] Criar `docs/decisions/` índice se necessário e conferir que o ADR `0001-stack-supabase-vercel.md` está coerente com o implementado
- [ ] T070 Configurar os ambientes online conforme a checklist da seção 5 do [quickstart.md](quickstart.md): dois projetos Supabase, Google Cloud em produção, Vercel com variáveis por ambiente, `supabase db push` em cada um (**exige ações do dono do projeto**; SMTP em produção depende da decisão do domínio)
- [ ] T071 Executar o roteiro manual do Google (seção 4 do quickstart) no ambiente de desenvolvimento e registrar o resultado no PR
- [ ] T072 Configurar branch protection em `main` e `develop` no GitHub (PR obrigatório, CI verde) conforme a constitution
- [ ] T073 Rodar todos os cenários da seção 3 do [quickstart.md](quickstart.md) e atualizar `README.md` e `CONTRIBUTING.md` com o que mudou

---

## Dependências e ordem de execução

### Entre fases

- **Preparação (1)** → **Fundação (2)** → histórias → **Acabamento (9)**
- A Fundação bloqueia todas as histórias.

### Entre histórias

- **US1 (P1)**: começa após a Fundação; define os grupos de rotas `(publico)`, `(situacao)` e `(app)` usados pelas demais.
- **US2 (P1)**: depende da estrutura de rotas da US1 (T036–T037); a lógica de entrar é independente do cadastro, pois usa contas do seed.
- **US3 (P1)**: depende de US1 (contas pendentes) e de `inicio` da US2 (atalho e contagem); a função SQL é independente.
- **US4 (P2)**: depende de `/entrar` (US2) e da rota `auth/confirmar` (US1).
- **US5 (P2)**: depende de `conta` (US2) e das telas de situação (US1).
- **US6 (P3)**: depende de `inicio` (US2); as funções SQL independem das demais.

### Dentro de cada história

- Testes primeiro (devem falhar) → migração/função SQL → ações e telas → verificação.
- Migrações numeradas na ordem de aplicação; nunca editar migração já aplicada em ambiente online, criar nova.

### Oportunidades de paralelismo

- Preparação: T003–T008 em paralelo após T002.
- Fundação: todos os testes T009–T016 em paralelo; T021–T025, T028, T029 em paralelo; migrações T017–T020 em sequência.
- Cada história: seus testes ([P]) em paralelo; após a Fundação, **US3 (SQL), US4 e US5 (SQL) e US6 (SQL)** podem avançar em paralelo por serem arquivos distintos.

### Exemplo de paralelismo (Fundação)

```text
Em paralelo: T009, T010, T011, T012 (pgTAP) + T013, T014, T015, T016 (Vitest)
Depois, em sequência: T017 → T018 → T019 → T020
Em paralelo: T021, T022, T023, T024, T025, T028, T029
```

---

## Estratégia de implementação

### MVP primeiro (US1 + US2 + US3)

1. Concluir Preparação e Fundação.
2. Concluir US1, US2 e US3: já existe login, fila de aprovação e papéis básicos, suficiente para colocar no ar com o dono como administrador.
3. **Parar e validar** pelos cenários do quickstart, no ambiente local e depois no de desenvolvimento online.
4. Publicar em produção (T070–T072 já necessários aqui, junto com a decisão do domínio de email).

### Entrega incremental

1. Fundação pronta.
2. US1 → US2 → US3 (MVP).
3. US4 (recuperação) e US5 (exclusão) em seguida; são exigências de privacidade/usabilidade e devem estar antes de abrir o app a toda a igreja.
4. US6 (gestão de papéis) por último; até lá o dono promove líderes por SQL.
5. Um PR por história, pequeno e focado, apontando para `develop` (constitution).

### Observações

- Para cada regra crítica: escrever o teste, vê-lo falhar, implementar, vê-lo passar; explicar no PR, de forma didática, os conceitos de teste usados (constitution IV).
- Commits em pt-BR no padrão Conventional Commits, um por tarefa ou grupo lógico.
- Nunca versionar segredos; `.env.local` fica fora do git.


---

## Notas de implementação (2026-11-19)

- **Estado**: fases 1 a 8 concluídas e verificadas localmente (lint, tipos, 38 testes Vitest, 8 arquivos pgTAP, 29 testes Playwright com axe-core, build de produção). Nada foi commitado.
- **Pendentes** (dependem de pessoas/ambientes online, não de código): T067 revisão manual de acessibilidade, T068 medição de carga em rede móvel real, T070 ambientes online, T071 roteiro manual do Google, T072 branch protection no GitHub, T073 rodada final do quickstart nos ambientes online.
- **Ordem "vermelho antes de verde"**: nas fases 2 e 3 os testes foram escritos antes, mas migrações e código foram escritos logo em seguida, antes de ver cada teste falhar isoladamente. Nas demais histórias o ciclo foi o previsto.
- **Desvio do plano**: o Next.js 16 gerado vinha com `cacheComponents` ligado; foi desligado em `next.config.ts` porque todas as telas dependem de quem está logado.
- **Desvio do contrato**: nas funções SQL a mensagem do erro é exatamente o código (ex.: `sem_permissao`).
