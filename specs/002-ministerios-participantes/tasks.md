---

description: "Lista de tarefas da funcionalidade Ministérios e Participantes"
---

# Tarefas: Ministérios e Participantes

**Entrada**: documentos de design em `specs/002-ministerios-participantes/`

**Pré-requisitos**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Testes**: INCLUÍDOS e obrigatórios. A constitution (princípio IV) e o RF-039 exigem testes automatizados para permissões, pedidos, aprovação por líder e "pelo menos um líder", escritos **antes ou junto** da implementação: cada teste deve ser visto falhando (vermelho) antes de a regra ser implementada (verde).

**Organização**: tarefas agrupadas por história de usuário para permitir implementar e testar cada uma de forma independente.

## Formato: `[ID] [P?] [História] Descrição`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência de tarefa incompleta)
- **[USn]**: história de usuário a que a tarefa pertence
- Todo texto de código, comentários e commits em pt-BR (constitution VII); comentários explicam o porquê
- **Antes de escrever qualquer página ou ação**, consultar o guia do Next.js 16 em `node_modules/next/dist/docs/` (regra do `AGENTS.md`): `params` e `searchParams` são `Promise`.

## Convenções de caminho

Projeto único Next.js na raiz do repositório: `src/`, `supabase/`, `tests/`, `docs/` (ver estrutura em [plan.md](plan.md)).

**Migrações** (nome `<data e hora>_<nome>.sql`, nunca editar uma já aplicada em ambiente online): usar os arquivos abaixo, em ordem. **Testes pgTAP** continuam a numeração da 001 (`009` em diante).

---

## Fase 1: Preparação

**Objetivo**: conferir o ponto de partida.

- [X] T001 Conferir que a branch `002-ministerios-participantes` contém a constituição 1.3.0 e a ADR 0005 (`git log --oneline -3`, `.specify/memory/constitution.md`) e que `npm run lint`, `npm run typecheck`, `npm test` e `npx supabase test db` passam **antes** de qualquer mudança (linha de base verde)
- [X] T002 [P] Ler no guia do Next.js 16 (`node_modules/next/dist/docs/01-app/`) as páginas de rotas dinâmicas, Server Actions/formulários (`useActionState`) e `revalidatePath`, e anotar em "Notas de implementação" ao final deste arquivo qualquer diferença em relação ao padrão já usado na 001

---

## Fase 2: Fundação (pré-requisitos bloqueantes)

**Objetivo**: tabelas, regras de acesso, gatilhos e o ajuste do papel "líder" que todas as histórias usam. **⚠️ CRÍTICO**: nenhuma história começa antes desta fase.

### Testes da fundação (escrever primeiro; devem falhar)

- [X] T003 [P] Escrever teste pgTAP da migração dos líderes globais em `supabase/tests/009_migracao_lideres.test.sql`: a constraint `perfis_papel_sem_lider` barra gravar `lider`; `alterar_papel(..., 'lider', ...)` levanta `transicao_invalida`; o `update` de conversão (`lider` → `membro`) converte um perfil inserido com a constraint removida e recriada dentro da transação, sem perder nenhum outro campo (RF-027)
- [X] T004 [P] Escrever teste pgTAP das políticas de acesso em `supabase/tests/010_rls_ministerios.test.sql`: visitante e pessoa logada leem só `id`, `nome`, `descricao`, `ativo` de ministérios **ativos**; administrador lê todos; cada pessoa lê só as próprias participações e pedidos; administrador lê todos; **nenhuma** escrita direta (insert/update/delete) em nenhuma das três tabelas por `anon` ou `authenticated`; a política `perfis_ler_fila_lider` não existe mais (RF-035)
- [X] T005 [P] Escrever teste pgTAP do gatilho "pelo menos um líder" em `supabase/tests/011_ultimo_lider.test.sql`: rebaixar, apagar a participação, **excluir a conta** (cascata) e **remover o acesso** do único líder válido falham com `ultimo_lider`; com um segundo líder válido passam; ministério **desativado** não exige líder; líder com conta não aprovada não conta como válido (RF-012, RF-013, CS-006)
- [X] T006 [P] Escrever teste pgTAP das regras de pedido em `supabase/tests/012_regras_pedidos.test.sql`: o índice único barra dois pedidos pendentes iguais; pedido recusado/cancelado/aceito **não** impede um novo; quando a conta vira `recusado` ou `acesso_removido`, os pedidos pendentes viram `cancelado`; **excluir a conta** de quem não é a única líder apaga junto as participações e os pedidos dela, sem deixar linhas órfãs (RF-018, RF-020, RF-037)
- [X] T007 [P] Atualizar testes Vitest de `tests/unit/permissoes.test.ts`: `Papel` só com `membro` e `administrador`; `destinoPara` recebe `lidera`; `/aprovacoes` liberada a administrador **ou** quem lidera; `/usuarios` e `/ministerios/novo` só administrador; atalhos por papel e por liderança (RF-027)
- [X] T008 [P] Atualizar testes Vitest de `traduzirErro` em `tests/unit/mensagens-erro.test.ts` com os novos códigos (`nome_duplicado`, `nome_invalido`, `ultimo_lider`, `ministerio_inativo`, `ja_participa`, `pedido_duplicado`, `conflito_pedido`, `pessoa_invalida`, `sem_lider`)
- [X] T009 [P] Escrever testes Vitest de `validarNomeMinisterio`, `validarDescricaoMinisterio` e `validarIdsMinisterios` em `tests/unit/validacao-ministerios.test.ts` (nome vazio, só espaços, <2, >60; descrição >200; ids que não são UUID são ignorados; no máximo 30) (RF-006)

### Ajuste dos testes e do código da 001 que dependem do papel global "líder"

- [X] T010 Ajustar os testes pgTAP existentes `supabase/tests/003_rls_perfis.test.sql`, `004_ultimo_administrador.test.sql`, `006_decidir_cadastro.test.sql` e `008_alterar_papel_situacao.test.sql`: nenhum deles pode gravar `papel = 'lider'`; em `006`, `decidir_cadastro` por quem não é administrador (inclusive líder de ministério) passa a levantar `sem_permissao`; em `003`, quem lidera ministério **não** lê perfis alheios
- [X] T011 Ajustar os testes existentes `tests/unit/perfil.test.ts`, `tests/e2e/papeis.spec.ts`, `tests/e2e/aprovacao.spec.ts`, `tests/e2e/entrar.spec.ts` e `tests/e2e/seguranca-api.spec.ts` para o novo modelo (líder = quem lidera um ministério; o líder de teste vem do `seed.sql`); testes de aprovação por líder ficam pendentes de US4 e marcados com `test.fixme` apontando para T049

### Implementação da fundação

- [X] T012 Criar a migração `supabase/migrations/20261120120001_ministerios_tabelas.sql`: extensão `unaccent`, função imutável `normalizar_nome_ministerio`, tipos `papel_ministerio` e `situacao_pedido`, tabelas `ministerios`, `participacoes_ministerio` e `pedidos_entrada_ministerio` com chaves, checks de tamanho, índice único parcial do nome entre ativos, índice único parcial do pedido pendente e demais índices, conforme [data-model.md](data-model.md)
- [X] T013 Criar a migração `supabase/migrations/20261120120002_lideranca_por_ministerio.sql`: converte `papel = 'lider'` em `membro`, adiciona `perfis_papel_sem_lider check (papel <> 'lider')`, remove a política `perfis_ler_fila_lider`, torna `decidir_cadastro` exclusiva do administrador e faz `alterar_papel` recusar `lider` com `transicao_invalida`, com comentários explicando o porquê ([research.md](research.md#decisao-1))
- [X] T014 Criar a migração `supabase/migrations/20261120120003_acesso_ministerios.sql`: funções `eh_lider_de(uuid)` e `ministerios_que_lidero()` (`security definer`, `search_path` fixo, lendo do banco a cada chamada), `revoke`/`grant` das funções, `enable row level security`, permissões por coluna e políticas das três tabelas conforme a tabela de RLS do [data-model.md](data-model.md) (visitante lê só colunas públicas de ministérios ativos)
- [X] T015 Criar a migração `supabase/migrations/20261120120004_regras_ministerios.sql`: gatilho `proteger_ultimo_lider` em `participacoes_ministerio` (antes de `update` e `delete`) e em `perfis` (quando a situação deixa de ser `aprovado`), com trava `for update` e exceção `ultimo_lider` com o nome do ministério no detalhe; gatilho que cancela os pedidos pendentes quando a conta vira `recusado` ou `acesso_removido`
- [X] T016 Atualizar `supabase/seed.sql` (somente ambiente local): o "líder" de teste passa a `papel = 'membro'` e lidera o ministério "Louvor"; criar "Recepção" (líder: administrador), "Teatro" desativado com um participante, o membro como participante do Louvor e um pedido pendente do usuário pendente para o Louvor, conforme [quickstart.md](quickstart.md)
- [X] T017 Rodar `npx supabase db reset && npx supabase test db`: todos os testes pgTAP (novos e ajustados) devem passar; confirmar que T003–T006 estavam vermelhos antes das migrações T012–T015
- [X] T018 [P] Ajustar `src/lib/auth/permissoes.ts`: `Papel = "membro" | "administrador"`; `destinoPara(situacao, papel, rota, lidera)` com `/aprovacoes` para administrador ou quem lidera e `/ministerios/novo` para administrador; `atalhosPorPapel(papel, lidera)` com "Pedidos e aprovações", "Meus ministérios", "Ministérios" e "Gerenciar usuários" conforme [contracts/rotas.md](contracts/rotas.md)
- [X] T019 [P] Ajustar `src/lib/auth/perfil.ts` e `src/lib/auth/sessao.ts`: `Perfil` ganha `lidera: boolean` lido pela função `ministerios_que_lidero` **do banco a cada requisição** (RF-034); `exigirAcesso` repassa `lidera` a `destinoPara`
- [X] T020 [P] Ajustar `src/lib/auth/mensagens-erro.ts` com a tradução dos novos códigos (mensagens da tabela de [contracts/banco-rpc.md](contracts/banco-rpc.md)), incluindo o nome do ministério em `ultimo_lider` quando vier no detalhe
- [X] T021 [P] Criar `src/lib/ministerios/validacao.ts` com os esquemas Zod `validarNomeMinisterio` (2–60), `validarDescricaoMinisterio` (≤ 200) e `validarIdsMinisterios` (UUIDs, ignora inválidos, máximo 30) reutilizando o padrão de `src/lib/auth/validacao.ts`
- [X] T022 Ajustar `src/app/(app)/usuarios/lista.tsx` e `src/app/(app)/usuarios/actions.ts`: remover a opção de papel "Líder", mantendo "Membro" e "Administrador", e exibir `ultimo_lider` ao remover o acesso de quem lidera sozinho
- [X] T023 Rodar `npm run lint`, `npm run typecheck`, `npm test` e `npm run test:e2e`: tudo verde (os e2e de aprovação por líder seguem como `fixme` até T049)

**Ponto de verificação**: banco com as regras de acesso e gatilhos funcionando; app compila sem o papel global de líder.

---

## Fase 3: História 1 - Administrador cadastra e mantém os ministérios (Prioridade: P1) 🎯 MVP

**Meta**: o administrador cria, edita, desativa e reativa ministérios; a igreja passa a ter a lista oficial.

**Teste Independente**: como administrador, criar "Teatro" com líder inicial, tentar duplicar o nome, desativar e recriar o mesmo nome.

### Testes da História 1 (escrever primeiro; devem falhar)

- [X] T024 [P] [US1] Escrever teste pgTAP das funções de ministério em `supabase/tests/013_ministerios_admin.test.sql`: `criar_ministerio` exige administrador, nome/descrição válidos (`nome_invalido`) e líder inicial com conta `aprovado` (`pessoa_invalida`) e cria ministério e liderança juntos; nome duplicado ignorando caixa, acento e espaços (`nome_duplicado`); `editar_ministerio` com a mesma regra; `desativar_ministerio` não apaga participações nem pedidos; recriar o nome de um desativado funciona; `reativar_ministerio` falha com `nome_duplicado` e com `sem_lider` sem líder válido; membro e líder de ministério recebem `sem_permissao` (RF-001 a RF-007)
- [X] T025 [P] [US1] Escrever teste Playwright em `tests/e2e/ministerios-admin.spec.ts`: administrador cria "Teatro" com descrição e líder, vê na lista; duplicado mostra "Já existe um ministério ativo com esse nome."; desativa e o ministério sai da lista de ativos; membro abrindo `/ministerios/novo` é redirecionado (CS-001, CS-005)

### Implementação da História 1

- [X] T026 [US1] Criar a migração `supabase/migrations/20261120120005_funcoes_ministerios.sql` com `criar_ministerio`, `editar_ministerio`, `desativar_ministerio` e `reativar_ministerio` conforme [contracts/banco-rpc.md](contracts/banco-rpc.md) (`security definer`, `search_path` fixo, validação de `auth.uid()`, `unique_violation` traduzido para `nome_duplicado`) e rodar `npx supabase test db` até T024 ficar verde
- [X] T027 [P] [US1] Criar `src/lib/ministerios/consultas.ts` com as leituras do servidor: lista de ministérios (ativos, e todos para o administrador) e um ministério por id, devolvendo só as colunas permitidas
- [X] T028 [P] [US1] Criar `src/components/CartaoMinisterio.tsx` (nome, descrição, situação ativo/desativado, link para o detalhe), mobile-first, alvo de toque ≥ 44 px
- [X] T029 [US1] Criar `src/app/(app)/ministerios/page.tsx`: administrador vê ativos e desativados com "Novo ministério"; estado vazio com texto orientador
- [X] T030 [US1] Criar `src/app/(app)/ministerios/novo/page.tsx`, `formulario.tsx` e `actions.ts`: nome, descrição curta e líder inicial escolhido entre contas aprovadas (lidas por RLS do administrador, com busca por nome); erros por campo com `aria-describedby`; chama `criar_ministerio`
- [X] T031 [US1] Criar `src/app/(app)/ministerios/[id]/page.tsx` e `actions.ts` (com `await params`): cabeçalho do ministério e, para administrador, editar nome/descrição, desativar (botão de duas etapas) e reativar (pedindo líder se necessário); `revalidatePath` após cada ação
- [X] T032 [US1] Ajustar `src/app/(app)/inicio/page.tsx` com o atalho "Ministérios" para todos; rodar T024 e T025 até ficarem verdes

**Ponto de verificação**: a História 1 funciona sozinha (cenários 1 a 4 do quickstart).

---

## Fase 4: História 2 - Gerenciar participantes e líderes de um ministério (Prioridade: P1)

**Meta**: administrador e líder do ministério adicionam, removem e promovem participantes; nunca falta líder.

**Teste Independente**: adicionar uma pessoa como participante, promovê-la a líder e tentar remover o último líder.

### Testes da História 2 (escrever primeiro; devem falhar)

- [X] T033 [P] [US2] Escrever teste pgTAP em `supabase/tests/014_participantes.test.sql`: `adicionar_participante` por administrador e por líder **do próprio** ministério; líder de outro ministério recebe `sem_permissao`; conta não aprovada → `pessoa_invalida`; repetir → `ja_participa`; ministério desativado → `ministerio_inativo`; adicionar pessoa com pedido pendente marca o pedido como `aceito`; `alterar_papel_ministerio` vale só naquele ministério; `remover_participante` mantém as outras participações; remover/rebaixar o último líder → `ultimo_lider`; `buscar_pessoas` exige 2 letras, devolve só `id` e `nome`, no máximo 20, e só a administrador ou líder do ministério (RF-009 a RF-014)
- [X] T034 [P] [US2] Escrever teste Playwright em `tests/e2e/participantes.spec.ts`: líder do Louvor busca uma pessoa, adiciona, promove a líder, tenta remover o último líder e vê "O ministério precisa de pelo menos um líder."; o mesmo líder não vê controles de gestão na Recepção; excluir a conta da única líder de um ministério ativo mostra o erro com o nome do ministério e passa depois de definir outro líder (RF-013, CS-005, CS-006)

### Implementação da História 2

- [X] T035 [US2] Criar a migração `supabase/migrations/20261120120006_funcoes_participantes.sql` com `adicionar_participante`, `alterar_papel_ministerio`, `remover_participante`, `buscar_pessoas` e `listar_participantes` (devolve nome e papel, nunca email; lista vazia para quem não pode ver) conforme [contracts/banco-rpc.md](contracts/banco-rpc.md); rodar `npx supabase test db` até T033 ficar verde
- [X] T036 [P] [US2] Estender `src/lib/ministerios/consultas.ts` com a leitura de participantes (`listar_participantes`) e a busca de pessoas (`buscar_pessoas`)
- [X] T037 [P] [US2] Criar `src/components/ListaParticipantes.tsx` (nome e papel; ações Promover, Rebaixar e Remover só quando permitido, remoção em duas etapas) e `src/components/BuscaPessoa.tsx` (busca por nome com resultados acessíveis e botão Adicionar)
- [X] T038 [US2] Estender `src/app/(app)/ministerios/[id]/page.tsx` e `actions.ts` com a seção de participantes para administrador e líder do ministério (adicionar, promover/rebaixar, remover) e tradução de `ultimo_lider` e `ja_participa`; rodar T034 até ficar verde

**Ponto de verificação**: cenários 5 a 7 do quickstart.

---

## Fase 5: História 3 - Pedir para entrar em ministérios no cadastro (Prioridade: P1)

**Meta**: a pessoa marca ministérios ao se cadastrar (email) ou na tela de espera (Google); cada marcação vira um pedido pendente.

**Teste Independente**: criar conta marcando dois ministérios e conferir dois pedidos pendentes, sem participação.

### Testes da História 3 (escrever primeiro; devem falhar)

- [X] T039 [P] [US3] Escrever teste pgTAP em `supabase/tests/015_pedidos_cadastro.test.sql`: criar usuário no Auth com `raw_user_meta_data.ministerios` gera pedidos pendentes só para ministérios **ativos** e válidos; ids inválidos, inexistentes, inativos e acima de 30 são ignorados **sem impedir** a criação da conta; `pedir_entrada_ministerio` por conta `pendente` e `aprovado` funciona (com `origem_cadastro` correto); `recusado` e `acesso_removido` → `sem_permissao`; `ja_participa`, `pedido_duplicado` e `ministerio_inativo` (RF-015 a RF-018)
- [X] T040 [P] [US3] Escrever teste Playwright em `tests/e2e/cadastro-ministerios.spec.ts`: sem ministérios ativos, `/cadastrar` **não** mostra a escolha; com ministérios, cadastrar marcando Louvor e Recepção (confirmando o email no Mailpit) leva a `/aguardando-aprovacao` com dois pedidos pendentes; cadastrar sem marcar nada também funciona; na tela de espera é possível pedir outro ministério (CS-003)

### Implementação da História 3

- [X] T041 [US3] Criar a migração `supabase/migrations/20261120120007_pedir_entrada.sql` com `pedir_entrada_ministerio` e a nova versão do gatilho `sincronizar_perfil_auth` que cria os pedidos a partir dos metadados do cadastro (valida UUID, ministério ativo, máximo 30, nunca falha o cadastro; só no `insert` da conta); rodar `npx supabase test db` até T039 ficar verde
- [X] T042 [P] [US3] Estender `src/lib/ministerios/consultas.ts` com a lista de ministérios ativos para o cadastro, lida no servidor com a chave pública (sem criar rota pública nova)
- [X] T043 [P] [US3] Criar `src/components/SeletorMinisterios.tsx`: `fieldset` com `legend`, caixas de marcar com rótulo claro, retorna os ids marcados; não renderiza nada quando a lista está vazia
- [X] T044 [US3] Ajustar `src/app/(publico)/cadastrar/page.tsx`, `formulario.tsx` e `actions.ts`: carregar os ministérios ativos, exibir o `SeletorMinisterios` e enviar `ministerios` em `options.data` do `signUp`, validado por `validarIdsMinisterios`; o cadastro **nunca** falha por causa dos ministérios
- [X] T045 [US3] Ajustar `src/app/(situacao)/aguardando-aprovacao/page.tsx` e criar `actions.ts` na mesma pasta: mostrar os pedidos já feitos e, havendo ministérios ativos, "Pedir ministérios" (fluxo do Google) chamando `pedir_entrada_ministerio`; rodar T040 até ficar verde

**Ponto de verificação**: cenários 8, 9 e 12 do quickstart (a parte "sem pedido").

---

## Fase 6: História 4 - Líder decide pedidos e aprova novos usuários (Prioridade: P1)

**Meta**: líder e administrador aceitam ou recusam cada pedido; aceitar o pedido de uma conta nova a ativa.

**Teste Independente**: conta nova que pediu o Louvor é aceita pelo líder do Louvor e vira membro e participante.

### Testes da História 4 (escrever primeiro; devem falhar)

- [X] T046 [P] [US4] Escrever teste pgTAP em `supabase/tests/016_decidir_pedido.test.sql`: líder do ministério aceita e a conta `pendente` (email confirmado) vira `aprovado` + `membro`, com participação criada, `decidido_por` e `decidido_em` gravados, tudo na mesma operação; os outros pedidos da conta seguem pendentes; recusar **não** altera a conta; líder de outro ministério → `sem_permissao`; ninguém decide o próprio pedido; decisão repetida → `conflito_pedido`; ministério desativado → `ministerio_inativo`; conta `recusado`/`acesso_removido` ou sem email confirmado → `transicao_invalida`; administrador decide qualquer pedido (RF-019 a RF-024)
- [X] T047 [P] [US4] Escrever teste pgTAP em `supabase/tests/017_listar_pedidos.test.sql`: `listar_pedidos_pendentes` e `contar_pedidos_pendentes` — administrador vê todos de ministérios ativos; líder só os dos seus; membro recebe lista vazia; conta pendente sem email confirmado não aparece; pedido de ministério desativado não aparece; conta pendente **sem nenhum pedido** não aparece para líder (RF-025, RF-028)
- [X] T048 [P] [US4] Escrever teste Playwright em `tests/e2e/aprovacao-por-lider.spec.ts`: líder do Louvor aceita o pedido da conta nova em até 2 toques a partir de `/inicio`, a conta fica ativa e participante; recusar mantém a conta pendente; conta sem ministério só é aprovada pelo administrador na seção "Cadastros pendentes"; dois decisores no mesmo pedido geram o aviso de conflito; promover uma pessoa a líder com ela já conectada faz `/aprovacoes` aparecer ao recarregar a página, sem novo login, e rebaixá-la faz sumir (RF-034, CS-002, CS-007)

### Implementação da História 4

- [X] T049 [US4] Criar a migração `supabase/migrations/20261120120008_decidir_pedido.sql` com `decidir_pedido_entrada`, `listar_pedidos_pendentes` e `contar_pedidos_pendentes` conforme [contracts/banco-rpc.md](contracts/banco-rpc.md); rodar `npx supabase test db` até T046 e T047 ficarem verdes, e então reativar os e2e marcados `test.fixme` em T011
- [X] T050 [P] [US4] Estender `src/lib/ministerios/consultas.ts` com a leitura de pedidos pendentes e a contagem
- [X] T051 [US4] Reescrever `src/app/(app)/aprovacoes/page.tsx`, `fila.tsx` e `actions.ts`: título "Pedidos e aprovações"; seção **Pedidos de entrada** (administrador: todos; líder: dos seus ministérios) com Aceitar/Recusar por pedido, o ministério e o aviso "Aceitar também ativa a conta" quando `conta_pendente`; seção **Cadastros pendentes** só para administrador (aprovar/recusar a conta); `revalidatePath` e tradução de `conflito_pedido`
- [X] T052 [US4] Ajustar `src/app/(app)/inicio/page.tsx` para o contador de pendentes (pedidos para o líder; pedidos e cadastros para o administrador) usando `contar_pedidos_pendentes`; rodar T048 até ficar verde

**Ponto de verificação**: cenários 10, 11, 12 e 13 do quickstart. **Fim do MVP (US1 a US4)**.

---

## Fase 7: História 5 - "Meus ministérios" e pedir para entrar depois (Prioridade: P2)

**Meta**: cada pessoa vê seus ministérios, seus pedidos e pede outros a qualquer momento; a tela existe mesmo vazia.

**Teste Independente**: membro sem ministério abre a tela vazia, pede um ministério e acompanha o pedido.

### Testes da História 5 (escrever primeiro; devem falhar)

- [X] T053 [P] [US5] Escrever teste pgTAP em `supabase/tests/018_cancelar_pedido.test.sql`: `cancelar_pedido_entrada` só pela própria pessoa e só se `pendente` (`conflito_pedido` nos demais casos); depois de cancelar ou ser recusado, um novo pedido é permitido (RF-017, RF-020)
- [X] T054 [P] [US5] Escrever teste Playwright em `tests/e2e/meus-ministerios.spec.ts`: membro sem ministério vê o estado vazio amigável sem erro; pede a Recepção em até 3 toques; vê o pedido pendente; cancela e pede de novo sem duplicidade; pedido recusado aparece como "recusado" e permite novo pedido (CS-004)

### Implementação da História 5

- [X] T055 [US5] Criar a migração `supabase/migrations/20261120120009_cancelar_pedido.sql` com `cancelar_pedido_entrada`; rodar `npx supabase test db` até T053 ficar verde
- [X] T056 [US5] Criar `src/app/(app)/meus-ministerios/page.tsx` e `actions.ts`: ministérios de que participa (com papel e a lista de quem faz parte, via `listar_participantes`), pedidos e estados, "Pedir para entrar em outro ministério" (ministérios ativos de que não participa e sem pedido pendente) e "Cancelar pedido"; estado vazio com orientação
- [X] T057 [US5] Ajustar `src/app/(app)/ministerios/page.tsx` e `src/app/(app)/ministerios/[id]/page.tsx` com o botão "Pedir para entrar" para quem não é participante (reaproveitando a ação de T056); ajustar `src/app/(app)/inicio/page.tsx` com o atalho "Meus ministérios" a 1 toque; rodar T054 até ficar verde

**Ponto de verificação**: cenários 14 e 15 do quickstart.

---

## Fase 8: História 6 - Visibilidade por papel (Prioridade: P2)

**Meta**: cada papel vê só o que lhe cabe; quem não faz parte de um ministério não vê seus participantes.

**Teste Independente**: com administrador, líder do Louvor e participante da Recepção, conferir o que cada um enxerga.

### Testes da História 6 (escrever primeiro; devem falhar)

- [X] T058 [P] [US6] Escrever teste pgTAP em `supabase/tests/019_visibilidade_ministerios.test.sql`: `listar_participantes` — administrador vê todos (inclusive desativados); líder vê os do seu ministério e **lista vazia** nos demais; participante vê os do próprio ministério; quem não participa recebe lista vazia; as funções nunca devolvem email; ministério desativado só para administrador; pessoa com conta recusada, com acesso removido ou excluída **não aparece** na lista, e volta a aparecer se a conta for reaprovada (RF-029 a RF-031)
- [X] T059 [P] [US6] Ampliar `tests/e2e/seguranca-api.spec.ts` com chamadas diretas pela chave pública: membro lê `participacoes_ministerio` de outra pessoa (zero linhas), escreve em `ministerios` (negado), chama `decidir_pedido_entrada` e `criar_ministerio` (`sem_permissao`), líder do Louvor decide pedido da Recepção (`sem_permissao`); e adicionar `tests/e2e/visibilidade-ministerios.spec.ts` conferindo as telas de administrador, líder, participante e membro sem vínculo (CS-005)

### Implementação da História 6

- [X] T060 [US6] Ajustar `src/app/(app)/ministerios/[id]/page.tsx` ao conteúdo por papel de [contracts/rotas.md](contracts/rotas.md): administrador (tudo), líder deste ministério (participantes e pedidos, sem editar/desativar), participante (descrição e lista de nomes e papéis), outras pessoas (só nome e descrição e "Pedir para entrar"); ministério desativado: "não encontrado" para quem não é administrador
- [X] T061 [US6] Ajustar `src/app/(app)/ministerios/page.tsx` para não administradores (lista de ativos com nome e descrição, sem participantes) e confirmar que nenhuma tela ou ação expõe email; rodar `npx supabase test db` e T059 até ficarem verdes

**Ponto de verificação**: cenários 16, 17 e 21 do quickstart.

---

## Fase 9: Acabamento e itens transversais

**Objetivo**: acessibilidade, documentação e verificação final.

- [X] T062 [P] Ampliar `tests/e2e/acessibilidade.spec.ts` (axe-core, celular de 375 px) para `/ministerios`, `/ministerios/novo`, `/ministerios/[id]`, `/meus-ministerios`, `/aprovacoes` e a tela de espera com o seletor, sem violações AA e sem rolagem horizontal (CS-009, RF-038)
- [X] T063 [P] Escrever a ADR `docs/decisions/0006-lideranca-por-ministerio.md` (contexto, decisão, consequências): liderança derivada por ministério no lugar do papel global, valor `lider` mantido no tipo, leitura pública restrita da lista de ministérios ativos para o cadastro, funções de leitura no lugar de abrir `perfis` (ver [research.md](research.md))
- [X] T064 [P] Atualizar `README.md` e `CONTRIBUTING.md` (papéis agora são administrador e membro, liderança por ministério, telas novas) e `specs/001-login-papeis-acesso/spec.md` com uma nota apontando que RF-011, RF-012, RF-015, RF-017 e RF-019 e a premissa "o líder aprova qualquer pessoa pendente" foram ajustados por esta funcionalidade
- [X] T065 [P] Atualizar `src/app/(legal)/privacidade/page.tsx` com o que passou a ser guardado (participação e pedidos de ministério, e que colegas do ministério veem seu nome) e o `ExcluirConta` em `src/components/ExcluirConta.tsx` para avisar que vínculos e pedidos também serão apagados (RF-037, constitution V)
- [X] T066 Rodar todos os cenários do [quickstart.md](quickstart.md) no ambiente local (1 a 19, 21 a 23) e registrar o resultado nas "Notas de implementação"
- [X] T067 Rodar a suíte completa: `npm run lint`, `npm run typecheck`, `npm test`, `npx supabase test db`, `npm run test:e2e` e `npm run build`: tudo verde; conferir que cada teste crítico foi visto falhando antes de passar (constitution IV)

---

## Fase 10: Implantação das migrações (constituição 1.3.0, ADR 0005)

**Objetivo**: cumprir a regra de que as migrações chegam aos ambientes por workflow versionado, antes de publicar a 002.

- [X] T068 Criar `.github/workflows/migracoes.yml` conforme a [ADR 0005](../../docs/decisions/0005-migracoes-automatizadas.md): em push para `develop` ou `main` que altere `supabase/migrations/**`, instala o Supabase CLI, faz `supabase link` e `supabase db push` no projeto do ambiente (`develop` → Environment `desenvolvimento`; `main` → Environment `producao`), com `concurrency` por ambiente e **sem** imprimir segredos
- [X] T069 **Ação do mantenedor (segredos)**: criar no GitHub os Environments `desenvolvimento` e `producao` (revisor obrigatório em `producao`) e cadastrar em cada um `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF` e `SUPABASE_DB_PASSWORD`; nenhum valor é versionado nem colado no chat *(Conferido em 2026-11-20 pela API do GitHub: os dois Environments existem, os três segredos estão em cada um e `producao` exige revisor (`arthur-lzrs`). Os valores não são verificáveis: confirmar na primeira execução que cada ambiente usa o projeto certo.)*
- [ ] T070 Antes do primeiro `db push` em cada ambiente, conferir que o histórico de migrações do projeto lista as 7 migrações da 001 (consulta em `supabase_migrations.schema_migrations`); se faltar alguma, corrigir com `supabase migration repair` antes de ligar o workflow
- [ ] T071 Abrir o PR da 002 para `develop` e fazer o merge (squash) com CI verde; conferir que o workflow `migracoes.yml` rodou no push e aplicou as migrações 20261120120001 a 20261120120009 no projeto de desenvolvimento (se falhar, usar a contingência da ADR 0003 e registrar o motivo no PR)
- [ ] T072 Confirmar na primeira execução em **desenvolvimento** que a conexão do runner funciona (se exigir o endereço de pooler, ajustar o workflow e registrar na ADR 0005) e marcar a ADR 0005 como "Implementada" com a data
- [ ] T073 Antes do release para produção: rodar a consulta somente leitura da seção 4 do [quickstart.md](quickstart.md) no projeto de produção e anotar quem tinha o papel global `lider`, para o administrador revincular essas pessoas depois da migração
- [ ] T074 Validar a 002 no ambiente de desenvolvimento online (cenários do quickstart e o roteiro manual do Google, cenário 20) e só então abrir o PR `develop` → `main`; após o merge, aprovar a execução do ambiente `producao` e conferir o resultado no painel do Supabase

---

## Dependências e ordem de execução

### Entre fases

- **Preparação (1)** → **Fundação (2)** → histórias → **Acabamento (9)** → **Implantação (10)**
- A Fundação bloqueia todas as histórias. O workflow (T068) pode ser feito a qualquer momento depois da Fundação, mas T069 a T074 só fazem sentido com as histórias prontas. O workflow só roda depois do merge da 002 em `develop` (T071).

### Entre histórias

- **US1 (P1)**: começa após a Fundação; cria a lista e o detalhe de ministérios usados pelas demais.
- **US2 (P1)**: depende de `ministerios/[id]` da US1 (T031); as funções SQL independem.
- **US3 (P1)**: depende só da Fundação (e do seed); a tela de espera e o cadastro são independentes de US1/US2, mas precisam de ministérios existentes para testar (usar o seed).
- **US4 (P1)**: depende de US3 (pedidos) e de `inicio` (T032); a função SQL é independente.
- **US5 (P2)**: depende de US3 (`pedir_entrada_ministerio`) e das páginas de US1.
- **US6 (P2)**: depende de US1, US2 e US5 (telas de detalhe e lista); os testes pgTAP independem.

### Dentro de cada história

- Testes primeiro (devem falhar) → migração/função SQL → leituras e componentes → telas e ações → verificação.
- Migrações numeradas na ordem de aplicação; nunca editar uma já aplicada em ambiente online, criar nova.

### Oportunidades de paralelismo

- Fundação: T003–T009 em paralelo; T012 → T013 → T014 → T015 em sequência; T018–T021 em paralelo após T017.
- Cada história: seus testes ([P]) em paralelo. Depois da Fundação, **US3 (SQL), US4 (SQL) e US5 (SQL)** podem avançar em paralelo por serem arquivos distintos; as telas de `ministerios/[id]` (US1, US2, US5, US6) mexem no mesmo arquivo e devem ser feitas em sequência.

### Exemplo de paralelismo (Fundação)

```text
Em paralelo: T003, T004, T005, T006 (pgTAP) + T007, T008, T009 (Vitest)
Depois, em sequência: T010 → T011 → T012 → T013 → T014 → T015 → T016 → T017
Em paralelo: T018, T019, T020, T021
```

---

## Estratégia de implementação

### MVP primeiro (US1 a US4)

1. Concluir Preparação e Fundação.
2. Concluir US1, US2, US3 e US4: já existem ministérios, participantes, pedidos e a aprovação de novos usuários pelo líder, o núcleo que as escalas vão usar.
3. **Parar e validar** pelos cenários do quickstart no ambiente local.
4. Seguir com US5 e US6 (P2) e o acabamento antes do PR final.

### Entrega incremental

1. Fundação pronta (banco e papel de líder derivado).
2. US1 → US2 → US3 → US4 (MVP).
3. US5 ("Meus ministérios") e US6 (visibilidade e testes de segurança por chamada direta).
4. Acabamento, workflow de migrações e implantação.
5. Um único PR da funcionalidade para `develop` (a constituição permite ajustes da mesma funcionalidade na mesma branch); se ficar grande demais, dividir por fases mantendo `develop` sempre verde.

### Observações

- Para cada regra crítica: escrever o teste, vê-lo falhar, implementar, vê-lo passar; explicar no PR, de forma didática, os conceitos de teste usados (constitution IV).
- Commits em pt-BR no padrão Conventional Commits, um por tarefa ou grupo lógico.
- Nunca versionar segredos; `.env.local` e `supabase/.env` ficam fora do git.
- Esta funcionalidade traz migrações: seguir a regra da constituição 1.3.0 (migrações por workflow; colar SQL só como contingência com o motivo no PR).

---

## Notas de implementação

*(preencher durante a implementação: desvios do plano, resultados de T002 e T066)*

- **T002 (guias do Next.js 16)**: confirmado que `params`/`searchParams` são `Promise` (precisam de `await`); formulários seguem o padrão já usado na 001 (`useActionState` + Server Actions + `revalidatePath`).
- **Fundação (T003–T023)**: concluída em 2026-11-20. Lint, tipos, 62 testes Vitest, 12 arquivos pgTAP (163 testes) e a suíte e2e passam. Evidência do "vermelho": os testes foram escritos antes das migrações e, depois, uma checagem de mutação (remover os gatilhos do último líder dentro de uma transação) fez o teste 011 falhar como esperado.
- **Ambiente local**: após o primeiro `supabase db reset` o Mailpit passou a receber o email padrão do Supabase (sem os modelos de `supabase/templates`), o que quebrou 4 testes e2e de link de email. Foi o ambiente, não o código: `npx supabase stop && npx supabase start && npx supabase db reset` resolveu.
- **Desvio do plano**: o mapeamento de papel ficou em `src/lib/auth/permissoes.ts` + `src/lib/auth/lideranca.ts` (nova função `lideraAlgumMinisterio`), e a barra de navegação inferior usa rótulos curtos (`Atalho.curto`) para caber em celular. `ministerios` dá `select` de todas as colunas a pessoas logadas (só o visitante fica restrito a `id`, `nome`, `descricao`, `ativo`).
- **Implementação concluída em 2026-11-20 (T001–T068)**; falta só a Fase 10 que depende do ambiente online (T070–T074).
- **T066 (cenários do quickstart)**: todos os cenários 1 a 19 e 21 a 23 estão cobertos por teste automatizado, rodando em celular emulado: 1–4 `ministerios-admin.spec.ts` e pgTAP 013; 5–7 `participantes.spec.ts` e pgTAP 014; 8–9 e 12 `cadastro-ministerios.spec.ts`; 10–13 `aprovacao-por-lider.spec.ts`; 14–15 `meus-ministerios.spec.ts`; 16–17 `visibilidade-ministerios.spec.ts`; 18 `participantes.spec.ts` (e2e) e pgTAP 011; 19 pgTAP 016/017; 21 `seguranca-api.spec.ts`; 22 pgTAP 012; 23 `acessibilidade.spec.ts` (axe e rolagem horizontal). **Só o cenário 20 (Google real) é manual** e fica para o ambiente de desenvolvimento online (T074).
- **Resultado final local**: lint e tipos limpos; 62 testes Vitest; 19 arquivos pgTAP (343 testes); 71 testes Playwright; build de produção ok.
- **Defeitos que os testes pegaram e foram corrigidos**: (1) `papel_aprovado_atual()` é NULL para contas sem acesso aprovado e fazia o `if not (...)` pular a checagem de permissão em `exigir_gestor_ministerio`, `listar_participantes` e `decidir_pedido_entrada` (conta pendente/recusada conseguiria gerir ministério e decidir pedidos); corrigido com `coalesce` e coberto por testes 014, 016 e 019; (2) `/meus-ministerios` do administrador listava vínculos e pedidos de todo mundo, porque a RLS do administrador libera tudo; corrigido filtrando pela pessoa logada; (3) a consulta pública de ministérios pedia uma coluna que o visitante não pode ler. Detalhes e a lição aprendida na [ADR 0006](../../docs/decisions/0006-lideranca-por-ministerio.md).
- **Migrações editadas no lugar**: as migrações 20261120120006 e 20261120120008 foram corrigidas (coalesce) depois de criadas, o que é permitido porque nenhuma migração da 002 foi aplicada em ambiente online.
- **Workflow `migracoes.yml` (T068)**: criado, mas **ainda não executado**; só roda após o merge em `develop` e a primeira execução em desenvolvimento (T072) confirma conexão e histórico. Não foi possível testá-lo localmente.
- Os testes da US6 (T058, T059) testam funções criadas antes (T035, T049), então podem chegar verdes; o "vermelho antes do verde" dessas regras foi visto nas tarefas que as criaram.
