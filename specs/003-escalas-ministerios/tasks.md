---

description: "Lista de tarefas da funcionalidade Escalas dos Ministérios"
---

# Tarefas: Escalas dos Ministérios

**Entrada**: documentos de design em `specs/003-escalas-ministerios/`

**Pré-requisitos**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Testes**: INCLUÍDOS e obrigatórios. A constitution (princípio IV) exige testes automatizados para escalas (conflitos, duplicidades, datas) e permissões, escritos **antes ou junto** da implementação: cada teste deve ser visto falhando (vermelho) antes de a regra ser implementada (verde).

**Organização**: tarefas agrupadas por história de usuário para permitir implementar e testar cada uma de forma independente.

## Formato: `[ID] [P?] [História] Descrição`

- **[P]**: pode rodar em paralelo (arquivos diferentes, sem dependência de tarefa incompleta)
- **[USn]**: história de usuário a que a tarefa pertence (ver [spec.md](spec.md))
- Todo texto de código, comentários e commits em pt-BR (constitution VII); comentários explicam o porquê
- **Antes de escrever qualquer página ou ação**, consultar o guia do Next.js 16 em `node_modules/next/dist/docs/` (regra do `AGENTS.md`): `params` e `searchParams` são `Promise`.

## Convenções de caminho

Projeto único Next.js na raiz do repositório: `src/`, `supabase/`, `tests/`, `docs/` (ver estrutura em [plan.md](plan.md)).

**Migrações** (nome `<data e hora>_<nome>.sql`, nunca editar uma já aplicada em ambiente online). Usar os arquivos abaixo, em ordem; cada tarefa indica o seu:

| Arquivo | Conteúdo | Tarefa que cria |
|---------|----------|-----------------|
| `20261123120001_escalas_tipos_e_tempo.sql` | tipos enumerados e funções de tempo/normalização | T004 |
| `20261123120002_escalas_tabelas.sql` | 6 tabelas, índices e restrições | T006 |
| `20261123120003_escalas_acesso.sql` | RLS, revogações e funções auxiliares de permissão | T008 |
| `20261123120004_funcoes_aptidoes.sql` | funções e aptidões | US1 |
| `20261123120005_escalas_escrita.sql` | criar/editar escala, vagas, avisos, publicar, cancelar | US2 |
| `20261123120006_escalas_leitura.sql` | `listar_escalas_ministerio`, `ler_escala` (completa: vagas, minha resposta, respostas e destaques do gestor) e contador de vagas em aberto | US2 |
| `20261123120007_responder_e_minhas_escalas.sql` | `responder_escala`, `minhas_escalas`, `contar_pendencias_escala` | US3 |
| `20261123120008_liberar_vagas_futuras.sql` | `liberar_vagas_futuras` e os gatilhos de remoção de participante e perda de acesso | US4 |
| `20261123120009_pedidos_troca.sql` | pedir, responder, decidir, cancelar, listar trocas; `contar_pendencias_escala` ampliada | US5 |
| `20261123120010_desativar_ministerio_escalas.sql` | `desativar_ministerio` cancela escalas futuras e contador | US6 |

**Regra de ouro**: a numeração segue a ordem das histórias; **nenhuma tarefa edita uma migração já criada**. Quando uma história precisa mudar uma função anterior (ex.: `ler_escala`), faz `create or replace` na **sua própria** migração nova.

**Testes pgTAP** continuam a numeração da 002 (`020` em diante). Cada teste que depende de data redefine `agora_sp()` dentro da própria transação, revertida no `rollback` (ver [research.md](research.md#decisao-2)).

---

## Fase 1: Preparação

**Objetivo**: conferir o ponto de partida.

- [X] T001 Conferir que a branch `003-escalas-ministerios` parte do `develop` com a 002 (`git log --oneline -3`) e que `npm run lint`, `npm run typecheck`, `npm test` e `npx supabase test db` passam **antes** de qualquer mudança (linha de base verde)
- [X] T002 [P] Ler no guia do Next.js 16 (`node_modules/next/dist/docs/01-app/`) as páginas de rotas dinâmicas, Server Actions/formulários (`useActionState`) e `revalidatePath`, e anotar em "Notas de implementação" ao final deste arquivo qualquer diferença em relação ao padrão já usado na 001/002
- [X] T003 [P] Ler as migrações `supabase/migrations/20261120120003_acesso_ministerios.sql` e `20261120120006_funcoes_participantes.sql` e os testes `supabase/tests/011_ultimo_lider.test.sql` e `014_participantes.test.sql`, para repetir o estilo (funções `security definer`, `search_path` fixo, códigos de erro, estrutura pgTAP)

---

## Fase 2: Fundação (pré-requisitos bloqueantes)

**Objetivo**: tipos, tabelas, acesso e utilitários compartilhados por todas as histórias.

**⚠️ CRÍTICO**: nenhuma história começa antes desta fase.

- [X] T004 Criar `supabase/migrations/20261123120001_escalas_tipos_e_tempo.sql` com: tipos `tipo_aptidao`, `situacao_escala`, `resposta_escala`, `situacao_troca`; funções `agora_sp()` (apenas `now()`, **sem gancho de teste** em produção), `hoje_sp()` (via `agora_sp()`), `inicio_da_escala(date, time)` (imutável, America/Sao_Paulo) e `normalizar_nome_funcao(text)` (mesma regra de `normalizar_nome_ministerio`)
- [X] T005 [P] Escrever `supabase/tests/020_tempo_escalas.test.sql` (pgTAP): `hoje_sp()` e `inicio_da_escala` corretos perto da meia-noite e na virada de horário; `agora_sp()` devolve `now()`; ao redefinir `agora_sp()` na transação, `hoje_sp()` e `inicio_da_escala` passam a segui-la (nenhuma usa `now()` direto); após o `rollback` a função original volta; nenhuma configuração de sessão altera o relógio
- [X] T006 Criar `supabase/migrations/20261123120002_escalas_tabelas.sql` com as tabelas `funcoes_ministerio`, `aptidoes`, `escalas`, `vagas_escala`, `respostas_escala`, `pedidos_troca`, chaves, `check`s de tamanho, índices únicos parciais (nome de função ativa por ministério; um pedido pendente por vaga), `on delete` conforme [data-model.md](data-model.md); comentários em pt-BR explicando o porquê; **integridade no próprio banco**: `unique (id, escala_id)` em `vagas_escala` e chave estrangeira composta `(vaga_id, escala_id)` em `pedidos_troca` (o pedido nunca aponta para escala diferente da vaga); gatilho `before insert or update` em `vagas_escala` que, quando `perfil_id` é preenchido e mudou, exige participação da pessoa no ministério da escala
- [X] T007 [P] Escrever `supabase/tests/021_restricoes_escalas.test.sql` (pgTAP): nome duplicado de função ativa (sem diferenciar caixa/acento), duas funções iguais em ministérios diferentes e uma desativada passam; um segundo pedido pendente na mesma vaga é rejeitado; limites de tamanho; exclusão de conta: aptidões, respostas e pedidos somem e a vaga fica em aberto (`perfil_id` nulo); **escrita direta inconsistente é recusada**: pedido com `escala_id` diferente da escala da vaga e vaga com pessoa que não participa do ministério
- [X] T008 Criar `supabase/migrations/20261123120003_escalas_acesso.sql`: ligar RLS nas 6 tabelas, `revoke all` de `anon`/`authenticated`, `grant select` apenas em `funcoes_ministerio` com política para participantes/gestores do ministério; funções auxiliares `eh_participante_de(ministerio)`, `eh_gestor_de(ministerio)` (administrador ou líder válido) e `exigir_gestor_escala(escala)` (ver `exigir_gestor_ministerio` da 002), todas validando `auth.uid()` por dentro
- [X] T009 [P] Escrever `supabase/tests/022_rls_escalas.test.sql` (pgTAP): anônimo e autenticado não leem nem escrevem diretamente em nenhuma das 5 tabelas fechadas; `funcoes_ministerio` só é lida por participante, líder do ministério e administrador; as funções auxiliares devolvem o esperado para administrador, líder, líder de outro ministério, participante e estranho
- [X] T010 [P] Criar `src/lib/escalas/datas.ts` com `hoje()`, `jaComecou(data, horario)`, `somenteLeitura(data)` e formatação pt-BR (ex.: "dom., 14/12 às 09:00") sempre em America/Sao_Paulo; e `tests/unit/datas-escalas.test.ts` (Vitest) cobrindo virada do dia, horário de verão fora do país e formatação
- [X] T011 [P] Criar `src/lib/escalas/validacao.ts` (esquemas Zod: evento 2–80, observação ≤ 300, rótulo ≤ 40, motivo ≤ 200, nome de função 2–40, data, horário, tipo de aptidão) e `tests/unit/validacao-escalas.test.ts`
- [X] T012 [P] Criar `src/lib/escalas/avisos.ts` (tipos `Aviso` e texto de cada aviso, incluindo "participante já escalado em outro ministério neste mesmo dia") e `tests/unit/avisos-escalas.test.ts`
- [X] T013 [P] Ajustar `src/lib/auth/mensagens-erro.ts` com os códigos novos de [contracts/banco-rpc.md](contracts/banco-rpc.md) (`funcao_duplicada` … `troca_invalida`) e `tests/unit/mensagens-erro.test.ts`; nenhum texto técnico cru chega ao usuário
- [X] T014 [P] Em `src/lib/auth/permissoes.ts`, **não criar regra de rota nova**: `/minhas-escalas`, `/pedidos-de-troca` e `/ministerios/[id]/escalas*` valem para qualquer pessoa aprovada (a barreira por ministério é do banco, que devolve "não encontrado"); acrescentar em `tests/unit/permissoes.test.ts` casos que provem isso
- [X] T015 Criar `src/lib/escalas/consultas.ts` com funções de leitura que chamam as RPCs (`listarEscalasMinisterio`, `lerEscala`, `minhasEscalas`, `listarPedidosTroca`, `contarPendencias`, `listarFuncoes`, …) com tipos TypeScript dos retornos; sem lógica de regra (as regras ficam no banco); **toda leitura é dinâmica (sem cache de página)**, para o escalado sempre ver a versão atual (FR-016)
- [X] T016 Rodar `npx supabase db reset` e `npx supabase test db` e confirmar tudo verde até aqui (testes T005, T007 e T009 passando)

**Ponto de verificação**: a base de escalas existe, fechada para acesso direto; as histórias podem começar.

---

## Fase 3: História 1 - Líder cadastra as funções e as aptidões do ministério (Prioridade: P1) 🎯 MVP

**Objetivo**: o ministério passa a ter funções (vocal, violão…) e a lista de quem é apto em quê.

**Teste Independente**: criar, editar e desativar funções e cadastrar aptidões de um participante, como líder, e conferir as barreiras para quem não é gestor.

### Testes da História 1 (escrever primeiro; devem FALHAR antes da implementação)

- [X] T017 [P] [US1] Escrever `supabase/tests/023_funcoes.test.sql` (pgTAP): `criar_funcao`, `editar_funcao`, `desativar_funcao`, `reativar_funcao` — gestor pode, líder de outro ministério, participante e anônimo recebem `sem_permissao`; `funcao_duplicada` entre ativas (caixa/acento); nome igual a uma desativada é permitido; desativar não altera vagas existentes; reativar com nome já ativo falha; ministério inativo falha
- [X] T018 [P] [US1] Escrever `supabase/tests/024_aptidoes.test.sql` (pgTAP): `definir_aptidoes` substitui a lista completa; só participantes do ministério; função de outro ministério ou nova função desativada → `funcao_invalida`; `listar_aptidoes` só para gestor; `minhas_aptidoes` só da própria pessoa; nenhum email nos retornos; `listar_funcoes` com e sem inativas
- [X] T019 [P] [US1] Escrever `tests/e2e/funcoes-aptidoes.spec.ts` (Playwright, celular): líder cria "Vocal" e "Violão", tenta "vocal" duplicado (erro claro), define aptidões principal/secundária, desativa uma função; membro comum não vê a tela de gestão

### Implementação da História 1

- [X] T020 [US1] Criar `supabase/migrations/20261123120004_funcoes_aptidoes.sql` com `criar_funcao`, `editar_funcao`, `desativar_funcao`, `reativar_funcao`, `definir_aptidoes`, `listar_funcoes`, `listar_aptidoes`, `minhas_aptidoes` conforme [contracts/banco-rpc.md](contracts/banco-rpc.md) (T017 e T018 ficam verdes)
- [X] T021 [P] [US1] Criar a Server Action `src/app/(app)/ministerios/[id]/funcoes/acoes.ts` (criar, renomear, desativar/reativar função; salvar aptidões) validando com Zod e traduzindo erros pelo mapa de mensagens
- [X] T022 [P] [US1] Criar `src/components/EditorFuncoes.tsx` e `src/components/EditorAptidoes.tsx` (formulários acessíveis: rótulos, `aria-describedby`, alvos ≥ 44 px, seletor "principal/secundária" com texto, não só cor)
- [X] T023 [US1] Criar a página `src/app/(app)/ministerios/[id]/funcoes/page.tsx` (somente gestor; quem não é gestor vê "não encontrado") usando T021 e T022
- [X] T024 [US1] Ajustar `src/app/(app)/ministerios/[id]/page.tsx` com o atalho "Funções e aptidões" visível apenas ao gestor
- [X] T025 [US1] Rodar `npx supabase test db`, `npm test` e `npm run test:e2e -- funcoes-aptidoes` até ficarem verdes (cenários 1 e 2 do [quickstart.md](quickstart.md))

**Ponto de verificação**: a História 1 funciona e pode ser entregue sozinha.

---

## Fase 4: História 2 - Líder monta e publica a escala de um evento (Prioridade: P1)

**Objetivo**: criar escala em rascunho, preencher vagas com avisos de conflito, publicar e cancelar.

**Teste Independente**: criar uma escala, preencher vagas, publicar e conferir que um participante passa a vê-la.

### Testes da História 2

- [X] T026 [P] [US2] Escrever `supabase/tests/025_criar_editar_escala.test.sql` (pgTAP): `criar_escala` (gestor; evento obrigatório; `data_passada` para ontem; hoje e amanhã passam; ministério inativo falha; quem não é gestor falha); `editar_escala` (cancelada → `escala_cancelada`; dia seguinte → `escala_somente_leitura`; nova data passada → `data_passada`; mudar só o evento não limpa nada)
- [X] T027 [P] [US2] Escrever `supabase/tests/026_vagas_avisos.test.sql` (pgTAP): `salvar_vaga` — cria vaga em aberto; várias da mesma função; `nao_participante`; função desativada em vaga nova → `funcao_invalida`; vaga existente com função desativada continua editável; `limite_vagas` (51ª vaga); mesma pessoa em duas vagas da mesma escala sem aviso; aviso `outro_ministerio` (escala publicada de outro ministério, mesmo dia, **resposta da pessoa `confirmado`**, horário ignorado) com ministério/evento/horário; **sem** aviso para mesma escala, mesmo ministério, rascunho, cancelada ou resposta pendente/recusada; aviso `sem_aptidao` (inclui pessoa sem nenhuma aptidão); sem `p_ciente` nada é gravado; com `p_ciente` grava; `remover_vaga`
- [X] T028 [P] [US2] Escrever `supabase/tests/027_publicar_cancelar.test.sql` (pgTAP): `publicar_escala` (sem vagas → `escala_sem_vagas`; com vaga em aberto → ok; idempotente; somente leitura falha); `cancelar_escala` (não apaga; idempotente; somente leitura falha); rascunho invisível para participante via leituras
- [X] T029 [P] [US2] Escrever `tests/e2e/escala-montar-publicar.spec.ts` (Playwright, celular): líder cria escala com 6 vagas (uma em aberto), vê avisos de outro ministério e de aptidão e continua, publica; participante vê a escala publicada com "Em aberto"; líder cancela e a escala continua visível como cancelada

### Implementação da História 2

- [X] T030 [US2] Criar `supabase/migrations/20261123120005_escalas_escrita.sql` com `criar_escala`, `editar_escala` (sem os efeitos em respostas/pedidos, que entram na US4), `salvar_vaga`, `remover_vaga`, função interna `avisos_para_vaga(escala, perfil, funcao)`, `publicar_escala`, `cancelar_escala` (inclui marcar pedidos pendentes como `sem_efeito`), `listar_candidatos_escala`, todas travando a escala com `for update` ([Decisão 4](research.md#decisao-4))
- [X] T031 [US2] Criar a parte de leitura necessária ao gestor em `supabase/migrations/20261123120006_escalas_leitura.sql`: `listar_escalas_ministerio` e `ler_escala` (sem respostas ainda além do que a US3 e US4 acrescentam), contadores `contar_escalas_com_vagas_abertas`; mesmas regras de visibilidade do contrato
- [X] T032 [P] [US2] Criar as Server Actions em `src/app/(app)/ministerios/[id]/escalas/acoes.ts` (criar/editar escala, salvar/remover vaga com o fluxo de avisos e `p_ciente`, publicar, cancelar)
- [X] T033 [P] [US2] Criar `src/components/ListaVagas.tsx`, `src/components/AvisosVaga.tsx` ("Continuar mesmo assim"/"Escolher outra pessoa") e `src/components/CartaoEscala.tsx` (selo de situação com ícone + texto)
- [X] T034 [US2] Criar `src/app/(app)/ministerios/[id]/escalas/page.tsx` (lista) e `.../escalas/nova/page.tsx` (formulário)
- [X] T035 [US2] Criar `src/app/(app)/ministerios/[id]/escalas/[escalaId]/page.tsx` com o editor de vagas do gestor, publicar e cancelar (com confirmação, usando `AcaoComConfirmacao`); visão de participante em modo leitura por enquanto
- [X] T036 [US2] Ajustar `src/app/(app)/ministerios/[id]/page.tsx` com o atalho "Escalas" e o aviso "N escalas com vagas em aberto"
- [X] T037 [US2] Rodar `npx supabase test db`, `npm test` e `npm run test:e2e -- escala-montar-publicar` até ficarem verdes (cenários 3 a 7 do [quickstart.md](quickstart.md))

**Ponto de verificação**: líderes já montam e publicam escalas; participantes as veem.

---

## Fase 5: História 3 - Pessoa escalada vê, confirma ou recusa (Prioridade: P1)

**Objetivo**: tela "Minhas escalas" e a resposta no próprio item.

**Teste Independente**: publicar uma escala com uma pessoa e conferir que ela a vê, confirma, recusa e muda de ideia até o início.

### Testes da História 3

- [X] T038 [P] [US3] Escrever `supabase/tests/028_responder_escala.test.sql` (pgTAP): `responder_escala` — quem ocupa vaga confirma/recusa; vale para todas as vagas da pessoa; motivo só gravado ao recusar; `nao_escalado`; `escala_nao_publicada` (rascunho); `escala_cancelada`; `evento_iniciado` (depois do horário, no mesmo dia); muda de resposta antes do início; resposta única por pessoa por escala
- [X] T039 [P] [US3] Escrever `supabase/tests/029_minhas_escalas.test.sql` (pgTAP): `minhas_escalas` só devolve publicadas/canceladas em que a pessoa ocupa vaga; rascunho não aparece; ordem das próximas e das passadas; várias funções da mesma pessoa agrupadas; `minha_resposta` "pendente" sem linha; nenhum dado de outras pessoas; `contar_pendencias_escala`
- [X] T040 [P] [US3] Escrever `tests/e2e/minhas-escalas.spec.ts` (Playwright, celular): escalado vê o item com ministério, evento, função, data, horário e resposta; confirma e recusa com motivo no item (≤ 3 toques desde a tela inicial); escala cancelada aparece sem botões; tela vazia amigável; depois de o líder mudar a escala, o escalado ao reabrir a tela vê a versão nova (FR-016)

### Implementação da História 3

- [X] T041 [US3] Criar `supabase/migrations/20261123120007_responder_e_minhas_escalas.sql` com `responder_escala`, `minhas_escalas`, `contar_pendencias_escala` (por ora só escalas sem resposta) e `create or replace` de `ler_escala` acrescentando `minha_resposta` e `pode_responder`
- [X] T042 [P] [US3] Criar a Server Action `src/app/(app)/minhas-escalas/acoes.ts` e `src/components/BotoesResposta.tsx` (Confirmar/Recusar, motivo opcional, estados desabilitados com texto explicando por quê)
- [X] T043 [US3] Criar `src/app/(app)/minhas-escalas/page.tsx` ("Próximas", "Ver passadas", vazio amigável)
- [X] T044 [US3] Ajustar `src/app/(app)/ministerios/[id]/escalas/[escalaId]/page.tsx` para o participante: nome de quem ocupa cada vaga, suas vagas, sua resposta e os botões; **sem** respostas dos outros
- [X] T045 [US3] Ajustar `src/app/(app)/inicio/page.tsx` com o atalho "Minhas escalas" e o contador de escalas sem resposta
- [X] T046 [US3] Rodar `npx supabase test db`, `npm test` e `npm run test:e2e -- minhas-escalas` até ficarem verdes (cenários 8 e 9 do [quickstart.md](quickstart.md))

**Ponto de verificação**: o ciclo escalar → ver → responder já funciona de ponta a ponta.

---

## Fase 6: História 4 - Líder acompanha respostas e reorganiza a escala (Prioridade: P1)

**Objetivo**: líder vê respostas e motivos, com destaques; troca pessoas, muda data/horário com os efeitos corretos; remoção de pessoa libera vagas futuras.

**Teste Independente**: com uma escala publicada com respostas variadas, conferir destaques, trocar a pessoa de uma vaga e mudar o horário.

### Testes da História 4

- [X] T047 [P] [US4] Escrever `supabase/tests/030_efeitos_de_mudanca.test.sql` (pgTAP): trocar a pessoa de uma vaga → nova pessoa pendente, anterior sem a vaga e sem resposta se não tem outra; pessoa com outra vaga mantém a resposta; quem ganha segunda vaga mantém a resposta que já tinha; mudar data ou horário apaga **todas** as respostas e marca pedidos pendentes como `sem_efeito`; mudar só evento/observação não apaga nada; remover vaga com pessoa aplica as mesmas regras
- [X] T048 [P] [US4] Escrever `supabase/tests/031_liberar_vagas_futuras.test.sql` (pgTAP): remover participante deixa suas vagas **futuras** (não canceladas, data ≥ hoje) do ministério em aberto, apaga a resposta dela nessas escalas e põe pedidos ligados em `sem_efeito`; escalas passadas e de outros ministérios ficam intactas; conta que perde acesso (`situacao` ≠ `aprovado`) tem as vagas futuras de **todos** os ministérios liberadas; exclusão de conta deixa vagas em aberto
- [X] T049 [P] [US4] Escrever `supabase/tests/032_visibilidade_respostas.test.sql` (pgTAP): `ler_escala` para o gestor traz respostas, motivos e `precisa_atencao` (recusada, sem resposta, em aberto); participante comum **nunca** recebe respostas nem motivos de outros; administrador vê tudo; estranho recebe nada
- [X] T050 [P] [US4] Escrever `tests/e2e/lider-acompanha.spec.ts` (Playwright, celular): líder vê vagas recusadas/sem resposta/em aberto em destaque (ícone + texto) e o motivo; troca a pessoa de uma vaga; muda o horário e as respostas voltam a "pendente"; remove um participante do ministério e vê "em aberto" e o aviso na página do ministério

### Implementação da História 4

- [X] T051 [US4] Criar `supabase/migrations/20261123120008_efeitos_de_mudanca.sql`: função interna `encerrar_pedidos_pendentes(escala, vaga null)`; ajuste de `salvar_vaga`, `remover_vaga` e `editar_escala` (por `create or replace` na nova migração) para aplicar os efeitos; `liberar_vagas_futuras(perfil, ministerio)` e os gatilhos em `participacoes_ministerio` (após apagar) e em `perfis` (ao deixar de ser `aprovado`), conforme [Decisão 6](research.md#decisao-6); rodar `supabase/tests/013_ministerios_admin.test.sql` e `014_participantes.test.sql` e ajustar o que dependia do comportamento antigo (cada ajuste explicado no PR)
- [X] T052 [US4] Criar `supabase/migrations/20261123120009_leitura_do_gestor.sql` com `create or replace` de `ler_escala` (acrescenta `respostas` e `precisa_atencao`, somente para gestor) e de `listar_escalas_ministerio` (acrescenta contagens `recusadas`/`sem_resposta`, somente para gestor)
- [X] T053 [P] [US4] Criar `src/components/DestaqueVaga.tsx` (selos "Recusou", "Sem resposta", "Em aberto" com ícone e texto) e usá-lo em `ListaVagas.tsx`
- [X] T054 [US4] Ajustar `src/app/(app)/ministerios/[id]/escalas/[escalaId]/page.tsx` e `.../escalas/page.tsx` para mostrar respostas, motivos e destaques ao gestor, e a edição de data/horário com aviso "as respostas voltarão para pendente"
- [X] T055 [US4] Ajustar `src/app/(app)/ministerios/[id]/page.tsx` para o aviso "N escalas com vagas em aberto" também após remover participante
- [X] T056 [US4] Rodar `npx supabase test db`, `npm test` e `npm run test:e2e -- lider-acompanha` até ficarem verdes (cenários 10, 11 e 17 do [quickstart.md](quickstart.md))

**Ponto de verificação**: o líder consegue sustentar a escala depois de publicada.

---

## Fase 7: História 5 - Pessoa escalada pede troca e o fluxo é decidido (Prioridade: P2)

**Objetivo**: pedido de troca com aceite da indicada e aprovação do líder; troca atômica.

**Teste Independente**: com duas pessoas e um líder, percorrer pedido, aceite, aprovação e conferir a vaga e a resposta "confirmado".

### Testes da História 5

- [X] T057 [P] [US5] Escrever `supabase/tests/033_pedir_troca.test.sql` (pgTAP): `pedir_troca` — só quem ocupa a vaga; escala publicada e não iniciada (`evento_iniciado`, `escala_nao_publicada`, `escala_cancelada`); indicada participante, aprovada, ≠ solicitante e sem vaga na escala (`ja_escalada`, `troca_invalida`); `troca_duplicada`; nada muda na escala; `listar_candidatas_troca` sem email
- [X] T058 [P] [US5] Escrever `supabase/tests/034_responder_pedido_troca.test.sql` (pgTAP): só a indicada responde; aceitar → `aguardando_lider`; recusar → `recusado_indicada`; pedido já encerrado → `conflito_troca`; indicada escalada por outro caminho → pedido `sem_efeito`; evento iniciado
- [X] T059 [P] [US5] Escrever `supabase/tests/035_decidir_troca.test.sql` (pgTAP): aprovar move a vaga para a indicada com resposta `confirmado`; solicitante perde só aquela vaga e mantém as outras e a resposta delas; sem outras vagas, a resposta dele é apagada; outros pedidos da mesma vaga/indicada viram `sem_efeito`; avisos (sem aptidão, outro ministério) devolvidos sem alterar nada sem `p_ciente`; com `p_ciente` aprova; recusar não muda a escala; **atomicidade**: uma falha forçada no meio deixa a vaga como estava; só gestor decide; pedido fora de `aguardando_lider` → `conflito_troca`
- [X] T060 [P] [US5] Escrever `supabase/tests/036_cancelar_listar_trocas.test.sql` (pgTAP): `cancelar_pedido_troca` pelo solicitante e pelo gestor, não por terceiros; `listar_pedidos_troca` mostra feitos, recebidos e, para gestor, os aguardando aprovação; situação **efetiva** `sem_efeito` para escala cancelada ou já iniciada; escala cancelada, mudança de pessoa da vaga e mudança de horário encerram pedidos; sem email
- [X] T061 [P] [US5] Provar a consistência sob concorrência (SC-004, FR-035) em duas camadas. (a) `supabase/tests/037_troca_sequencial.test.sql` (pgTAP, uma conexão): líder troca a pessoa e depois aprova o pedido antigo → `conflito_troca`; aprovação e depois troca de pessoa; nunca estado misto. (b) `tests/integration/concorrencia-escalas.test.ts` (Vitest, **duas sessões `supabase-js` reais** de usuários diferentes contra o Supabase local, disparando em paralelo `salvar_vaga` e `decidir_troca_lider` sobre a mesma escala, repetido ao menos 20 vezes): o estado final é sempre ou "vaga com a indicada, confirmada" ou "vaga como o líder deixou", nunca misto, e uma das chamadas recebe `conflito_troca` ou é desfeita. Criar `vitest.integration.config.ts` (inclui `tests/integration/**`) e o script `test:integracao` no `package.json`; documentar que exige `supabase start`
- [X] T062 [P] [US5] Escrever `tests/e2e/pedido-de-troca.spec.ts` (Playwright, celular): participante pede troca escolhendo colega em uma lista; colega aceita em "Pedidos de troca"; líder aprova (com aviso e "Continuar mesmo assim"); a vaga passa à colega com "confirmado"; cancelar pedido; segundo pedido na mesma vaga é recusado

### Implementação da História 5

- [X] T063 [US5] Criar `supabase/migrations/20261123120009_pedidos_troca.sql` com `pedir_troca`, `responder_pedido_troca`, `decidir_troca_lider` (trava da escala, atomicidade, avisos reutilizando `avisos_para_vaga`), `cancelar_pedido_troca`, `listar_pedidos_troca`, `listar_candidatas_troca`, e `create or replace` de `contar_pendencias_escala` acrescentando os contadores de trocas recebidas e a aprovar, conforme [contracts/banco-rpc.md](contracts/banco-rpc.md)
- [X] T064 [P] [US5] Criar as Server Actions `src/app/(app)/pedidos-de-troca/acoes.ts` e `src/app/(app)/ministerios/[id]/escalas/[escalaId]/acoes-troca.ts` (pedir, aceitar/recusar, aprovar/recusar com `p_ciente`, cancelar)
- [X] T065 [P] [US5] Criar `src/components/FormularioPedidoTroca.tsx` (seletor de colegas elegíveis, sem digitar email) e `src/components/CartaoPedidoTroca.tsx` (situação com ícone + texto, ações conforme quem é a pessoa)
- [X] T066 [US5] Criar `src/app/(app)/pedidos-de-troca/page.tsx` com os blocos "Recebidos", "Feitos", "Aguardando minha aprovação" (gestor) e "Histórico"
- [X] T067 [US5] Ajustar `src/app/(app)/ministerios/[id]/escalas/[escalaId]/page.tsx` com o botão "Pedir troca" em cada vaga da própria pessoa (quando `pode_pedir_troca`) e o pedido em andamento
- [X] T068 [US5] Ajustar `src/app/(app)/inicio/page.tsx` com o atalho "Pedidos de troca" e seus contadores
- [X] T069 [US5] Rodar `npx supabase test db`, `npm test` e `npm run test:e2e -- pedido-de-troca` até ficarem verdes (cenários 12 a 16 do [quickstart.md](quickstart.md))

**Ponto de verificação**: o fluxo completo de troca funciona e é atômico.

---

## Fase 8: História 6 - Visibilidade por papel e efeitos em ministérios (Prioridade: P2)

**Objetivo**: confirmar as regras de visibilidade e o efeito da desativação de ministério.

**Teste Independente**: participante, não participante, líder e administrador olhando a mesma escala; desativar ministério com escalas futuras.

### Testes da História 6

- [X] T070 [P] [US6] Escrever `supabase/tests/038_visibilidade_escalas.test.sql` (pgTAP): participante vê só publicadas (e canceladas em que esteve escalado) com nomes, só a própria resposta; líder de outro ministério e estranho recebem zero linhas/nada; administrador vê rascunhos, respostas e motivos de qualquer ministério; ministério desativado deixa as escalas somente para leitura e **toda função de escrita** (inclusive com administrador) retorna `ministerio_inativo`
- [X] T071 [P] [US6] Escrever `supabase/tests/039_desativar_ministerio_escalas.test.sql` (pgTAP): `contar_escalas_futuras` conta não canceladas com data ≥ hoje (rascunhos e publicadas); `desativar_ministerio` cancela essas escalas e seus pedidos pendentes na mesma transação e não toca nas passadas; só administrador; desativar sem escalas continua funcionando como na 002
- [X] T072 [P] [US6] Escrever `tests/e2e/visibilidade-escalas.spec.ts` (Playwright): participante não vê respostas dos outros; estranho abre a URL direta e não vê nada; administrador desativa um ministério, vê "Isto cancelará N escalas futuras" e só após confirmar elas ficam canceladas
- [X] T073 [P] [US6] Ampliar `tests/e2e/seguranca-api.spec.ts`: chamadas diretas à API com a chave pública e com sessão de membro às tabelas e funções de escalas devolvem negado/vazio

### Implementação da História 6

- [X] T074 [US6] Criar `supabase/migrations/20261123120010_desativar_ministerio_escalas.sql` (`create or replace` de `desativar_ministerio` cancelando escalas futuras + `contar_escalas_futuras`), mantendo a assinatura e o comportamento da 002; rodar `supabase/tests/013_ministerios_admin.test.sql` e ajustar o que dependia do comportamento antigo
- [X] T075 [US6] Ajustar a tela de desativação em `src/app/(app)/ministerios/[id]/page.tsx` (e a Server Action existente) para consultar `contar_escalas_futuras` e mostrar a confirmação com o número antes de desativar
- [X] T076 [US6] Revisar `listar_escalas_ministerio`, `ler_escala` e as telas para os casos de borda de [spec.md](spec.md) (escala sem vagas; função desativada em vaga existente; líder também escalado; escala de hoje com horário já passado) e ajustar o que faltar, com um teste para cada ajuste
- [X] T077 [US6] Rodar `npx supabase test db`, `npm test` e `npm run test:e2e` até ficarem verdes (cenários 18 a 20 do [quickstart.md](quickstart.md))

**Ponto de verificação**: todas as histórias funcionam e a visibilidade está provada.

---

## Fase 9: Acabamento e transversais

- [X] T078 [P] Ajustar `supabase/seed.sql` conforme [quickstart.md](quickstart.md): funções, aptidões, escala publicada e rascunho do Louvor, escala da Recepção no mesmo dia
- [X] T079 [P] Ampliar `tests/e2e/acessibilidade.spec.ts` (axe) com as telas novas em 360 px: minhas escalas, pedidos de troca, escalas do ministério, detalhe da escala, funções; corrigir violações AA
- [X] T080 [P] Escrever `docs/decisions/0007-escalas-tempo-e-leitura.md` (tempo calculado em vez de tarefa agendada, resposta como ausência de linha, leitura somente por funções, trava da escala), com contexto, decisão e consequências
- [X] T081 [P] Atualizar o `README.md` (o que a 003 entrega, como rodar o seed e os testes novos) e marcar o status da especificação
- [X] T082 Conferir o workflow `.github/workflows/migracoes.yml` com as 10 migrações novas (ordem, nenhuma migração antiga editada) e registrar no PR
- [X] T083 (validado pelo mantenedor no ambiente local; celular real a repetir na develop) Executar todos os cenários do [quickstart.md](quickstart.md) manualmente em um celular (Chrome Android e Safari iOS), incluindo a instalação do PWA, e registrar o resultado na descrição do PR; se possível com 3 a 5 pessoas da igreja (SC-006), anotando quantas conseguem confirmar, recusar e pedir troca sem ajuda
- [X] T084 Rodar o conjunto completo: `npm run lint`, `npm run typecheck`, `npm test`, `npx supabase test db`, `npm run test:e2e`; tudo verde
- [ ] T085 (PENDENTE: aguarda confirmação) Abrir o PR para `develop` com contexto, mudança e motivação (constitution VII), conceitos de teste explicados e checklist de acessibilidade/mobile

---

## Dependências e ordem de execução

- **Fase 1** → **Fase 2** (bloqueia tudo) → histórias → **Fase 9**.
- **US1** (funções) é pré-requisito prático da **US2** (a vaga exige função), mas é testável sozinha. **US2** antes de **US3**, **US4** e **US5** (precisam de escalas publicadas). **US3** e **US4** podem andar em paralelo depois da US2 (mexem em partes diferentes das mesmas telas: coordenar `[escalaId]/page.tsx`). **US5** depende de US2, US3 e US4 (efeitos sobre pedidos). **US6** depende de US2 e US4.
- Dentro de cada história: testes escritos e vistos **falhando** → migração → ações → componentes → páginas → verificação.
- Migrações são aplicadas em ordem numérica, que é a mesma ordem das histórias; cada história cria **migrações novas** e nunca edita as anteriores (funções ampliadas usam `create or replace` na migração da própria história).

## Oportunidades de paralelismo

- Fase 2: T005, T007, T009 e T010–T014 em paralelo (arquivos distintos).
- Em cada história, todos os testes marcados [P] podem ser escritos juntos, e as Server Actions/componentes [P] em paralelo depois da migração.
- US3 e US4 podem ser feitas por sessões diferentes se as páginas compartilhadas forem coordenadas.

## Estratégia de implementação

1. **MVP**: Fases 1 e 2 + US1 + US2 + US3 (líder monta e publica, pessoa vê e responde). Já entrega valor real à igreja.
2. **Incremento 2**: US4 (acompanhar e reorganizar, cascatas).
3. **Incremento 3**: US5 (troca) e US6 (visibilidade/desativação), depois acabamento.
4. Parar em cada ponto de verificação, rodar toda a bateria de testes e só então seguir.

## Notas de implementação

- **Efeitos de mudança dentro da 005**: trocar a pessoa de uma vaga e mudar data/horário (respostas voltam a pendente, pedidos perdem efeito) ficaram em `20261123120005_escalas_escrita.sql`, junto das funções de escrita, em vez de uma migração separada. A leitura completa do gestor (respostas, destaques) também está em `…0006`. Por isso as migrações da US4 se reduzem a `liberar_vagas_futuras` e seus gatilhos; os testes da US4 provam os efeitos de qualquer forma.
- **Next.js 16**: `params` e `searchParams` são `Promise` (já seguido nas páginas novas). O React 19 limpa formulários depois de cada Server Action: no editor de vagas, os campos são recriados com os valores devolvidos pelo servidor (`key`) para o líder poder "continuar mesmo assim" com a mesma vaga.
- O botão que reenvia o formulário com a ciência do líder usa `formAction` (função) em vez de depender do nome/valor do botão enviado.
