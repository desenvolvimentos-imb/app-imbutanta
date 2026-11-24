---

description: "Lista de tarefas da funcionalidade Disponibilidade dos Participantes dos Ministérios"
---

# Tarefas: Disponibilidade dos Participantes dos Ministérios

**Entrada**: documentos de design em `specs/004-disponibilidade-participantes/`

**Pré-requisitos**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Testes**: INCLUÍDOS e obrigatórios. A disponibilidade influencia escalas e depende de permissões, áreas críticas da constitution (princípio IV): os testes são escritos **antes ou junto** da implementação, e cada um deve ser visto falhando (vermelho) antes de a regra ser implementada (verde).

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
| `20261124120001_disponibilidade_tipos_e_tabelas.sql` | tipo, 4 tabelas, índices e restrições | T004 |
| `20261124120002_disponibilidade_acesso.sql` | RLS, revogações e auxiliares (`consulta_esta_aberta`, `exigir_gestor_consulta`, `exigir_participante_consulta`) | T006 |
| `20261124120003_disponibilidade_consultas.sql` | criar/editar consulta, datas, fechar, reabrir, `listar_consultas_ministerio` | US1 |
| `20261124120004_desativar_ministerio_consultas.sql` | `desativar_ministerio` fecha as consultas abertas | US1 |
| `20261124120005_disponibilidade_respostas.sql` | `responder_disponibilidade`, `minhas_consultas`, `contar_consultas_pendentes`, `ler_consulta_participante` | US2 |
| `20261124120006_disponibilidade_grade.sql` | `ler_consulta_gestor` (grade, totais, contagem por função) | US3 |
| `20261124120007_disponibilidade_preencher.sql` | `preencher_disponibilidade` | US4 |
| `20261124120008_disponibilidade_escalas.sql` | `avisos_para_vaga` redefinida e `disponibilidade_da_escala` | US5 |

**Regra de ouro**: a numeração segue a ordem das histórias; **nenhuma tarefa edita uma migração já criada**. Funções anteriores alteradas (`desativar_ministerio`, `avisos_para_vaga`) usam `create or replace` na migração **da própria história**.

**Testes pgTAP** continuam a numeração da 003 (`040` em diante). Todo teste que depende de data redefine `agora_sp()` dentro da própria transação, revertida no `rollback` (ver [research.md da 003](../003-escalas-ministerios/research.md#decisao-2)).

---

## Fase 1: Preparação

**Objetivo**: conferir o ponto de partida.

- [ ] T001 Conferir que a branch `004-disponibilidade-participantes` parte da `develop` com a 003 (`git log --oneline -3`) e que `npm run lint`, `npm run typecheck`, `npm test` e `npx supabase test db` passam **antes** de qualquer mudança (linha de base verde)
- [ ] T002 [P] Ler no guia do Next.js 16 (`node_modules/next/dist/docs/01-app/`) as páginas de rotas dinâmicas, Server Actions/formulários (`useActionState`) e `revalidatePath`, e anotar em "Notas de implementação" ao final deste arquivo qualquer diferença em relação ao padrão já usado na 003
- [ ] T003 [P] Ler `supabase/migrations/20261123120005_escalas_escrita.sql` (padrão de `salvar_vaga`/`avisos_para_vaga`, trava `for update`, retorno de avisos como dado), `20261123120006_escalas_leitura.sql` e `20261123120010_desativar_ministerio_escalas.sql`, e os testes `supabase/tests/026_vagas_avisos.test.sql` e `032_visibilidade_respostas.test.sql`, para repetir o estilo

---

## Fase 2: Fundação (pré-requisitos bloqueantes)

**Objetivo**: tipo, tabelas, acesso e utilitários compartilhados por todas as histórias.

**⚠️ CRÍTICO**: nenhuma história começa antes desta fase.

- [ ] T004 Criar `supabase/migrations/20261124120001_disponibilidade_tipos_e_tabelas.sql` com o tipo `resposta_disponibilidade` e as tabelas `consultas_disponibilidade`, `datas_consulta`, `respostas_disponibilidade`, `observacoes_disponibilidade`: chaves, `check`s de tamanho (título 2–80, mensagem ≤ 500, rótulo ≤ 40, observação 1–300), `unique (id, ministerio_id)` em consultas, chave estrangeira composta `(consulta_id, ministerio_id)` em datas, **índice único `(ministerio_id, data)`** em `datas_consulta`, `on delete` conforme [data-model.md](data-model.md) (cascata em datas, respostas e observações; `set null` em `criada_por` e `preenchida_por`); comentários em pt-BR explicando o porquê
- [ ] T005 [P] Escrever `supabase/tests/040_restricoes_disponibilidade.test.sql` (pgTAP): mesma data duas vezes no mesmo ministério é rejeitada **mesmo por escrita direta**; a mesma data em ministérios diferentes passa; `ministerio_id` da data diferente do da consulta é rejeitado; limites de tamanho; remover a data apaga as respostas; exclusão de conta apaga respostas e observações e mantém a consulta (`criada_por` nulo); `resposta` só aceita `disponivel`/`indisponivel` (não existe valor "sem resposta")
- [ ] T006 Criar `supabase/migrations/20261124120002_disponibilidade_acesso.sql`: ligar RLS nas 4 tabelas, `revoke all` de `anon`/`authenticated` (nenhuma leitura direta, [Decisão 4](research.md#decisao-4)); auxiliares `consulta_esta_aberta(consulta)` (`not fechada and (prazo is null or hoje_sp() <= prazo)`), `exigir_gestor_consulta(p_consulta)` (trava com `for update`, exige gestor via `eh_gestor_de` e ministério ativo, `nao_encontrado` se não existir) e `exigir_participante_consulta(p_consulta)`, todas validando `auth.uid()` por dentro e sem permissão de execução para `anon`/`authenticated`
- [ ] T007 [P] Escrever `supabase/tests/041_rls_disponibilidade.test.sql` (pgTAP): anônimo e autenticado (inclusive líder e administrador) não leem nem escrevem diretamente nas 4 tabelas; `consulta_esta_aberta` com relógio fixo: prazo hoje = aberta, prazo ontem = fechada, sem prazo = aberta, `fechada = true` = fechada; auxiliares recusam visitante, participante comum, líder de outro ministério e ministério inativo
- [ ] T008 [P] Criar `src/lib/disponibilidade/datas.ts` com `datasDoDiaDaSemana(ano, mes, diaDaSemana, hoje)` (todas as datas daquele dia da semana no mês, sem as anteriores a `hoje`, em ordem), `formatarDataConsulta` (ex.: "domingo, 06/12") e `prazoVencido(prazo, hoje)`, sempre em America/Sao_Paulo; e `tests/unit/datas-disponibilidade.test.ts` (Vitest): meses com 4 e 5 domingos, mês que já começou (descarta passadas), virada de ano, fevereiro bissexto
- [ ] T009 [P] Criar `src/lib/disponibilidade/validacao.ts` (esquemas Zod: título 2–80, mensagem ≤ 500, prazo, lista de datas com rótulo ≤ 40 e máximo 31 sem repetição, observação ≤ 300, resposta `disponivel`/`indisponivel`/nula) e `tests/unit/validacao-disponibilidade.test.ts`
- [ ] T010 [P] Ajustar `src/lib/auth/mensagens-erro.ts` com os códigos novos de [contracts/banco-rpc.md](contracts/banco-rpc.md) (`consulta_invalida` … `resposta_invalida`, incluindo `data_duplicada` com o título vindo do `detail`) e `tests/unit/mensagens-erro.test.ts`; nenhum texto técnico cru chega ao usuário
- [ ] T011 [P] Em `src/lib/auth/permissoes.ts`, **não criar regra de rota nova**: `/disponibilidade*` e `/ministerios/[id]/disponibilidade*` valem para qualquer pessoa aprovada (a barreira por ministério é do banco, que devolve "não encontrado"); acrescentar em `tests/unit/permissoes.test.ts` casos que provem isso
- [ ] T012 Criar `src/lib/disponibilidade/consultas.ts` com funções de leitura que chamam as RPCs (`listarConsultasMinisterio`, `minhasConsultas`, `lerConsultaParticipante`, `lerConsultaGestor`, `contarConsultasPendentes`, `disponibilidadeDaEscala`) e tipos TypeScript dos retornos; sem lógica de regra; **toda leitura é dinâmica (sem cache de página)**, para ver sempre a versão atual
- [ ] T013 Rodar `npx supabase db reset` e `npx supabase test db` e confirmar tudo verde até aqui (testes T005 e T007 passando)

**Ponto de verificação**: a base da disponibilidade existe, fechada para acesso direto; as histórias podem começar.

---

## Fase 3: História 1 - Líder cria e gerencia uma consulta (Prioridade: P1) 🎯 MVP

**Objetivo**: criar consultas com datas (calendário e atalho de mês), editar, fechar, reabrir, ver o histórico; desativar o ministério fecha as abertas.

**Teste Independente**: criar uma consulta com várias datas, editar, fechar e reabrir, sem nenhuma resposta ainda, e conferir as barreiras para quem não é gestor.

### Testes da História 1 (escrever primeiro; devem FALHAR antes da implementação)

- [ ] T014 [P] [US1] Escrever `supabase/tests/042_criar_consulta.test.sql` (pgTAP): `criar_consulta` — gestor cria aberta com datas e rótulos; título vazio → `consulta_invalida`; sem datas → `consulta_sem_datas`; data de ontem → `data_passada` (hoje passa); prazo de ontem → `prazo_invalido` (hoje passa); mais de 31 datas → `consulta_invalida`; data repetida na lista ou já em outra consulta do ministério → `data_duplicada` com o título no `detail`; a mesma data em outro ministério passa; tudo ou nada (nenhuma consulta fica gravada após erro); líder de outro ministério, participante comum e anônimo → `sem_permissao`; ministério inativo → `ministerio_inativo`
- [ ] T015 [P] [US1] Escrever `supabase/tests/043_editar_datas_consulta.test.sql` (pgTAP): `editar_consulta` altera título, mensagem e prazo (nulo remove) só se aberta (`consulta_fechada`); `adicionar_datas_consulta` (novas datas sem respostas, duplicada recusada, limite de 31); `remover_data_consulta`: sem respostas remove; com respostas e sem confirmação **não grava** e devolve `confirmacao_necessaria` com a contagem; confirmado remove data e respostas juntas; recusa a última data (`consulta_sem_datas`); data de outra consulta/ministério → `nao_encontrado`/`sem_permissao`
- [ ] T016 [P] [US1] Escrever `supabase/tests/044_fechar_reabrir_consulta.test.sql` (pgTAP) com relógio fixo: `fechar_consulta` e `reabrir_consulta` (idempotência do fechar; `consulta_ja_aberta`); consulta com prazo vencido vale como fechada sem ação alguma; reabrir sem mudar o prazo vencido → `prazo_vencido`; reabrir com novo prazo (hoje ou depois) ou com `p_remover_prazo` funciona; novo prazo no passado → `prazo_invalido`; em consulta fechada só reabrir é possível (editar e mexer em datas → `consulta_fechada`); nenhuma função apaga consulta; ministério inativo → `ministerio_inativo`
- [ ] T017 [P] [US1] Escrever `supabase/tests/045_listar_consultas.test.sql` (pgTAP): `listar_consultas_ministerio` — gestor vê todas (abertas primeiro, depois histórico) com situação efetiva, motivo ("fechada pelo líder", "prazo encerrado", "ministério desativado"), quantidade de datas e de participantes sem resposta nenhuma; participante comum e estranho recebem `[]`; administrador vê qualquer ministério; líder de outro ministério não vê; ministério desativado continua legível (histórico)
- [ ] T018 [P] [US1] Escrever `supabase/tests/046_desativar_ministerio_consultas.test.sql` (pgTAP): `desativar_ministerio` marca `fechada = true` nas consultas abertas na mesma transação; consultas já fechadas e de outros ministérios não mudam; nada é apagado; reabrir após desativar → `ministerio_inativo`
- [ ] T019 [P] [US1] Escrever `tests/e2e/consulta-criar-gerenciar.spec.ts` (Playwright, celular): líder cria "Escala de dezembro" com o atalho "todos os domingos de dezembro" e ajusta a lista, rótulo em uma data; data repetida em outra consulta do ministério mostra erro indicando a consulta; edita título e prazo; fecha e reabre; membro comum não vê as telas de gestão

### Implementação da História 1

- [ ] T020 [US1] Criar `supabase/migrations/20261124120003_disponibilidade_consultas.sql` com `criar_consulta`, `editar_consulta`, `adicionar_datas_consulta`, `remover_data_consulta` (com `p_confirmado`), `fechar_consulta`, `reabrir_consulta` e `listar_consultas_ministerio` conforme [contracts/banco-rpc.md](contracts/banco-rpc.md), travando a consulta com `for update` e convertendo a violação do índice único em `data_duplicada` (T014 a T017 ficam verdes)
- [ ] T021 [US1] Criar `supabase/migrations/20261124120004_desativar_ministerio_consultas.sql` com `create or replace function public.desativar_ministerio(uuid)`: mantém tudo o que a versão da 003 faz (copiar o corpo atual de `20261123120010_desativar_ministerio_escalas.sql`) e acrescenta o fechamento das consultas abertas (T018 fica verde, e os testes 039 e 013 continuam verdes)
- [ ] T022 [P] [US1] Criar a Server Action `src/app/(app)/ministerios/[id]/disponibilidade/acoes.ts` (criar, editar, adicionar/remover data com o fluxo de confirmação, fechar, reabrir) validando com Zod e traduzindo erros pelo mapa de mensagens
- [ ] T023 [P] [US1] Criar `src/components/SeletorDatas.tsx` (campo de data nativo + "Adicionar data"; atalho por mês e dia da semana usando `datasDoDiaDaSemana`; lista ordenada com rótulo opcional e "Remover"; contador "N de 31 datas"; bloqueia datas anteriores a hoje; rótulos e `aria-describedby`; alvos ≥ 44 px)
- [ ] T024 [P] [US1] Criar `src/components/FormularioConsulta.tsx` (título, mensagem, prazo, `SeletorDatas`; usado em criar e editar) e `src/components/AcoesConsulta.tsx` (fechar, reabrir com pedido de novo prazo ou "Remover o prazo" quando vencido; remover data com diálogo de confirmação usando `AcaoComConfirmacao`)
- [ ] T025 [US1] Criar a página `src/app/(app)/ministerios/[id]/disponibilidade/page.tsx` (lista "Abertas" e "Histórico" com selo "Aberta", "Fechada" ou "Prazo encerrado", ícone + texto; botão "Nova consulta" só com ministério ativo; somente gestor, demais veem "não encontrado")
- [ ] T026 [US1] Criar a página `src/app/(app)/ministerios/[id]/disponibilidade/nova/page.tsx` usando T022 e T024
- [ ] T027 [US1] Criar a página `src/app/(app)/ministerios/[id]/disponibilidade/[consultaId]/page.tsx` com os dados da consulta, edição, adicionar/remover datas, fechar e reabrir (a grade entra na US3; por ora, lista as datas)
- [ ] T028 [US1] Ajustar `src/app/(app)/ministerios/[id]/page.tsx` com o atalho "Disponibilidade" visível apenas ao gestor, com a contagem de consultas abertas
- [ ] T029 [US1] Rodar `npx supabase test db`, `npm test` e `npm run test:e2e -- consulta-criar-gerenciar` até ficarem verdes (cenários 1 a 3, 11 a 13 e 16 do [quickstart.md](quickstart.md))

**Ponto de verificação**: líderes já criam e gerenciam consultas; a História 1 pode ser entregue sozinha.

---

## Fase 4: História 2 - Participante responde a uma consulta (Prioridade: P1)

**Objetivo**: tela "Disponibilidade", resposta por data com salvamento parcial, observação e aviso na tela inicial.

**Teste Independente**: com uma consulta aberta (criada na US1 ou pelo seed), um participante responde, salva parcialmente, altera e deixa observação.

### Testes da História 2

- [ ] T030 [P] [US2] Escrever `supabase/tests/047_responder_disponibilidade.test.sql` (pgTAP): participante marca `disponivel`/`indisponivel`, salva parcial e as demais continuam sem linha (**"sem resposta" nunca vira "indisponível"**); resposta nula limpa a data; altera enquanto aberta; observação de 300 passa e de 301 → `consulta_invalida`, vazia apaga, nula mantém; consulta fechada (pelo líder, por prazo vencido com relógio fixo ou ministério desativado) → `consulta_fechada` sem perder respostas anteriores; data que já passou → `data_encerrada`; `data_id` de outra consulta → `resposta_invalida` e **nada é gravado** (tudo ou nada); quem não participa (ou saiu) → `sem_permissao`/`nao_participante`; quem entra depois da abertura responde; a própria resposta zera `preenchida_por`; líder (`preencher_disponibilidade`) e participante gravando a mesma resposta em sequência: vale a última gravada, sem erro nem linha duplicada
- [ ] T031 [P] [US2] Escrever `supabase/tests/048_minhas_consultas.test.sql` (pgTAP): `minhas_consultas` traz só consultas abertas dos ministérios em que a pessoa participa (e `fechadas_recentes` dos últimos 60 dias), só as **próprias** respostas e observação, `sem_resposta` correto, sem email; `ler_consulta_participante` devolve só o que é da pessoa e `pode_responder` falso em consulta fechada; `contar_consultas_pendentes` conta consulta aberta com data ainda respondível sem resposta da pessoa, ignora ministério inativo, consulta fechada e datas passadas, e cai a zero ao responder tudo
- [ ] T032 [P] [US2] Escrever `supabase/tests/049_visibilidade_disponibilidade.test.sql` (pgTAP): um participante **não** vê respostas nem observação de outro por nenhuma função; pessoa de outro ministério não vê nada (nem por `ler_consulta_participante`); quem saiu do ministério não consegue ler nem responder
- [ ] T033 [P] [US2] Escrever `tests/integration/disponibilidade-concorrencia.test.ts` (Vitest com duas sessões `supabase-js`, mesmo estilo de `tests/integration` da 003): responder e fechar a consulta ao mesmo tempo; só uma ordem é possível e o resultado nunca é misto (resposta gravada antes do fechamento, ou recusada com `consulta_fechada`)
- [ ] T034 [P] [US2] Escrever `tests/e2e/disponibilidade-responder.spec.ts` (Playwright, celular): a tela inicial mostra "Consulta aguardando sua resposta"; participante marca 2 de 4 datas e salva ("Faltam 2 datas"); volta e altera; observação com contador de 300; ao responder tudo o aviso some; consulta fechada aparece só leitura; outra pessoa não acessa a consulta por link direto; a partir da tela inicial a consulta abre em até 2 toques (constitution I: fluxo principal em no máximo 3)

### Implementação da História 2

- [ ] T035 [US2] Criar `supabase/migrations/20261124120005_disponibilidade_respostas.sql` com `responder_disponibilidade`, `minhas_consultas`, `ler_consulta_participante` e `contar_consultas_pendentes` conforme o contrato, travando a consulta com `for update` na escrita e filtrando por participação ativa nas leituras (T030 a T032 ficam verdes)
- [ ] T036 [P] [US2] Criar a Server Action `src/app/(app)/disponibilidade/acoes.ts` (salvar respostas e observação em uma única chamada) com Zod e mensagens traduzidas
- [ ] T037 [P] [US2] Criar `src/components/FormularioResposta.tsx` (uma linha por data com data por extenso e rótulo; grupo de botões de rádio **Disponível**/**Indisponível** e "Limpar"; observação com contador; botão "Salvar"; ícone + texto, nunca só cor) e `src/components/SeloDisponibilidade.tsx` (selos "Disponível", "Indisponível", "Sem resposta" com contraste AA)
- [ ] T038 [US2] Criar `src/app/(app)/disponibilidade/page.tsx` (consultas abertas dos meus ministérios, "N datas sem resposta", prazo; "Fechadas recentemente" em somente leitura; estado vazio "Nenhuma consulta aberta no momento.")
- [ ] T039 [US2] Criar `src/app/(app)/disponibilidade/[consultaId]/page.tsx` (formulário; consulta fechada em somente leitura com o motivo; quem não participa vê "não encontrado")
- [ ] T040 [US2] Ajustar `src/app/(app)/inicio/page.tsx` e a lista de atalhos em `src/lib/auth/permissoes.ts` com "Disponibilidade" e o destaque "Consulta aguardando sua resposta" quando `contarConsultasPendentes() > 0` (acompanhar o padrão dos contadores de "Minhas escalas"), com teste em `tests/unit/permissoes.test.ts`
- [ ] T041 [US2] Rodar `npx supabase test db`, `npm test`, `npm run test:integracao` e `npm run test:e2e -- disponibilidade-responder` até ficarem verdes (cenários 4 a 7, 14, 15 e 19 do [quickstart.md](quickstart.md))

**Ponto de verificação**: o ciclo pedir → responder já substitui o formulário externo, mesmo sem a grade.

---

## Fase 5: História 3 - Líder acompanha as respostas em uma grade (Prioridade: P1)

**Objetivo**: grade com participante por linha e data por coluna, totais, contagem por função, destaque de quem não respondeu, observações e uso no celular.

**Teste Independente**: com uma consulta com respostas variadas (seed), conferir células, totais, destaques, observações e o uso a 360 px.

### Testes da História 3

- [ ] T042 [P] [US3] Escrever `supabase/tests/050_grade_consulta.test.sql` (pgTAP): `ler_consulta_gestor` devolve participantes ativos por nome, `respostas` só com as datas marcadas, `nao_respondeu` verdadeiro só para quem não marcou nada, observações, totais `disponiveis`/`indisponiveis`/`sem_resposta` por data (sem resposta **não** entra em disponíveis nem em indisponíveis), `passada` por data, `tem_funcoes`; quem saiu do ministério some das linhas e das contagens e **volta com as respostas preservadas** ao retornar; quem não é gestor (participante, estranho, líder de outro ministério) recebe `null`; administrador lê qualquer ministério; consulta fechada e ministério desativado continuam legíveis; sem email
- [ ] T043 [P] [US3] Escrever `supabase/tests/051_contagem_por_funcao.test.sql` (pgTAP): `por_funcao` conta, por data e por função **ativa**, só participantes ativos "disponíveis" com aptidão (principal ou secundária); quem é apto em duas funções conta nas duas; função com zero fica `faltando`; função desativada não aparece; ministério sem funções ou sem aptidões devolve `por_funcao` vazio e `tem_funcoes` falso quando não há funções
- [ ] T044 [P] [US3] Escrever `tests/e2e/disponibilidade-grade.spec.ts` (Playwright, celular 360 px e desktop): visão por data sem rolagem horizontal da página, grupos "Disponíveis/Indisponíveis/Sem resposta", contagem por função com destaque de falta, quem não respondeu destacado, observações visíveis; alternar para a tabela com coluna do nome fixa e linha de totais; membro comum não acessa a grade; administrador abre consultas de qualquer ministério

### Implementação da História 3

- [ ] T045 [US3] Criar `supabase/migrations/20261124120006_disponibilidade_grade.sql` com `ler_consulta_gestor` (uma chamada, formato do contrato, junção com `participacoes_ministerio` e `perfis.situacao = 'aprovado'`, aptidões da 003 para `por_funcao`) (T042 e T043 ficam verdes)
- [ ] T046 [P] [US3] Criar `src/components/VisaoPorData.tsx` (um cartão por data: data por extenso, rótulo, "N disponíveis", `ContagemPorFuncao`, pessoas agrupadas por situação) e `src/components/ContagemPorFuncao.tsx` (função sem disponíveis em destaque com ícone + texto; aviso "Cadastre as funções e aptidões para ver a contagem por função" com link para `/ministerios/[id]/funcoes` quando `tem_funcoes` é falso)
- [ ] T047 [P] [US3] Criar `src/components/GradeDisponibilidade.tsx` (tabela: nome fixo na primeira coluna, rolagem horizontal só da tabela, célula com ícone + texto, linha de totais e linha por função, destaque "Ainda não respondeu" e lista dessas pessoas no topo, observações sob o nome) e o alternador de visões (padrão: visão por data em tela estreita, tabela em tela larga; escolha lembrada só no navegador, sem dado pessoal)
- [ ] T048 [US3] Ajustar `src/app/(app)/ministerios/[id]/disponibilidade/[consultaId]/page.tsx` para exibir a grade (T046/T047) acima das ações de gestão da US1
- [ ] T049 [US3] Rodar `npx supabase test db`, `npm test` e `npm run test:e2e -- disponibilidade-grade` até ficarem verdes (cenários 8 a 10 do [quickstart.md](quickstart.md))

**Ponto de verificação**: o líder acompanha tudo numa só tela; o objetivo central da funcionalidade está entregue.

---

## Fase 6: História 4 - Líder preenche ou corrige a resposta de um participante (Prioridade: P2)

**Objetivo**: registrar respostas de quem respondeu por outro meio, inclusive em consulta fechada, com marcador "preenchido pelo líder".

**Teste Independente**: preencher as respostas de um participante que não respondeu e corrigir as de outro, em consulta aberta e fechada.

### Testes da História 4

- [ ] T050 [P] [US4] Escrever `supabase/tests/052_preencher_disponibilidade.test.sql` (pgTAP): `preencher_disponibilidade` — gestor preenche em consulta aberta **e fechada** (inclusive por prazo vencido), grava `preenchida_por = auth.uid()`, aceita datas passadas, não mexe na observação; limpar uma data com resposta nula; pessoa que não é participante ativa → `nao_participante`; data de outra consulta → `resposta_invalida` e nada gravado; líder de outro ministério, participante comum e anônimo → `sem_permissao`; ministério inativo → `ministerio_inativo`; depois, `responder_disponibilidade` da própria pessoa zera `preenchida_por` e `ler_consulta_gestor` deixa de marcar `preenchida_pelo_lider`; o participante nunca vê quem preencheu nem o marcador (`minhas_consultas` e `ler_consulta_participante` não trazem `preenchida_por`)
- [ ] T051 [P] [US4] Escrever `tests/e2e/disponibilidade-preencher.spec.ts` (Playwright): líder corrige a resposta de um participante na grade (célula ou "Corrigir"), célula passa a mostrar "preenchido pelo líder", em consulta fechada continua possível; participante altera depois e o marcador some

### Implementação da História 4

- [ ] T052 [US4] Criar `supabase/migrations/20261124120007_disponibilidade_preencher.sql` com `preencher_disponibilidade` conforme o contrato (T050 fica verde)
- [ ] T053 [P] [US4] Acrescentar a ação `preencherResposta` em `src/app/(app)/ministerios/[id]/disponibilidade/acoes.ts` e criar `src/components/PreencherResposta.tsx` (reusa a linha de resposta de `FormularioResposta`, sem o campo de observação, com o nome da pessoa em destaque)
- [ ] T054 [US4] Ligar o preenchimento à grade em `GradeDisponibilidade.tsx` e `VisaoPorData.tsx` (toque na célula/pessoa abre `PreencherResposta`; marcador "preenchido pelo líder" com ícone + texto) e em `[consultaId]/page.tsx`
- [ ] T055 [US4] Rodar `npx supabase test db`, `npm test` e `npm run test:e2e -- disponibilidade-preencher` até ficarem verdes (cenário 12 do [quickstart.md](quickstart.md))

**Ponto de verificação**: a transição para quem não usa o app está coberta.

---

## Fase 7: História 5 - Disponibilidade visível ao montar a escala (Prioridade: P2)

**Objetivo**: ao escolher alguém para uma vaga, mostrar a resposta na data da escala e avisar (sem bloquear) quando não for "disponível".

**Teste Independente**: com uma consulta que contém a data de uma escala e pessoas com respostas diferentes, escalar cada uma e conferir indicação e aviso.

### Testes da História 5

- [ ] T056 [P] [US5] Escrever `supabase/tests/053_disponibilidade_escalas.test.sql` (pgTAP): `disponibilidade_da_escala` devolve `disponivel`/`indisponivel`/`sem_resposta` por participante ativo quando a data da escala está numa consulta **do mesmo ministério** (aberta ou fechada), e **zero linhas** quando não está; consulta de outro ministério com a mesma data é ignorada; remover (US1) uma data que está numa escala existente não altera a escala, e a função passa a devolver zero linhas para ela; só gestor (participante e estranho recebem zero linhas); quem saiu do ministério não aparece
- [ ] T057 [P] [US5] Escrever `supabase/tests/054_aviso_sem_disponibilidade.test.sql` (pgTAP): `salvar_vaga` devolve o aviso `sem_disponibilidade` com `resposta` correta para "indisponível" e "sem resposta" e **nenhum** para "disponível" nem para data fora de consulta; sem `p_ciente` nada é gravado, com `p_ciente` grava; pessoa que já ocupa outra vaga da mesma escala não recebe o aviso de novo; os avisos `outro_ministerio` e `sem_aptidao` e sua ordem **não mudam** (rodar também `026_vagas_avisos` e `035_decidir_troca`, que continuam verdes); `decidir_troca_lider` herda o aviso para a indicada
- [ ] T058 [P] [US5] Escrever `tests/e2e/disponibilidade-escala.spec.ts` (Playwright): ao escolher a pessoa a candidata mostra a resposta; escalar "indisponível" mostra o aviso e "Continuar mesmo assim"; a indicação fica ao lado da pessoa na escala (só para gestor); participante comum não vê a indicação; escala em data sem consulta não mostra nada
- [ ] T059 [P] [US5] Ampliar `tests/unit/avisos-escalas.test.ts` com o tipo `sem_disponibilidade` (leitura de dados válidos e inválidos, texto "Esta pessoa marcou que está indisponível nesta data." / "Esta pessoa ainda não respondeu sobre esta data.")

### Implementação da História 5

- [ ] T060 [US5] Criar `supabase/migrations/20261124120008_disponibilidade_escalas.sql`: `create or replace function public.avisos_para_vaga` (copiar o corpo atual de `20261123120005_escalas_escrita.sql` **sem alterar os avisos existentes** e acrescentar `sem_disponibilidade` dentro da mesma condição de "pessoa ainda sem vaga nesta escala") e a função nova `disponibilidade_da_escala(p_escala)` (T056 e T057 ficam verdes)
- [ ] T061 [P] [US5] Ajustar `src/lib/escalas/avisos.ts` (tipo `AvisoSemDisponibilidade`, `lerAvisos` e `textoDoAviso`) e `src/components/AvisosVaga.tsx` para exibir o novo aviso com ícone + texto (T059 fica verde)
- [ ] T062 [US5] Ajustar a tela da escala `src/app/(app)/ministerios/[id]/escalas/[escalaId]/page.tsx`, `src/components/ListaVagas.tsx` e `src/components/EditorVagas.tsx`: carregar `disponibilidadeDaEscala` (só para gestor), mostrar a resposta de cada candidata na escolha da pessoa e o selo "Indisponível"/"Sem resposta" ao lado da pessoa escalada (nada quando a função devolve zero linhas); a visão de participante não muda
- [ ] T063 [US5] Rodar `npx supabase test db`, `npm test` e `npm run test:e2e -- disponibilidade-escala` até ficarem verdes (cenários 17 e 18 do [quickstart.md](quickstart.md)), e confirmar que os testes de escalas da 003 continuam verdes

**Ponto de verificação**: a disponibilidade já ajuda a escalar; as cinco histórias estão completas.

---

## Fase 8: Acabamento e transversais

- [ ] T064 [P] Ajustar `supabase/seed.sql` conforme [quickstart.md](quickstart.md): consulta aberta "Escala de dezembro" no Louvor (4 domingos, um com rótulo "Culto especial", prazo daqui a alguns dias), respostas variadas (completa, parcial, nenhuma e uma preenchida pelo líder), uma observação, uma consulta fechada, e uma data que coincide com a escala publicada de exemplo da 003
- [ ] T065 [P] Ampliar `tests/e2e/acessibilidade.spec.ts` (axe) com as telas novas em 360 px: disponibilidade, responder, lista de consultas, nova consulta, grade (as duas visões); corrigir violações AA
- [ ] T066 [P] Escrever `docs/decisions/0008-disponibilidade-prazo-e-ausencia.md` (prazo calculado, "sem resposta" como ausência de linha, unicidade de data por índice, quem sai some por junção, integração por avisos), com contexto, decisão e consequências
- [ ] T067 [P] Atualizar o `README.md` (o que a 004 entrega, seed e testes novos), marcar o status da especificação e atualizar em [data-model.md](data-model.md) a lista de migrações para a numeração real deste arquivo
- [ ] T068 Conferir o workflow `.github/workflows/migracoes.yml` com as 8 migrações novas (ordem, nenhuma migração antiga editada) e registrar no PR
- [ ] T069 Executar todos os cenários do [quickstart.md](quickstart.md) manualmente em um celular (Chrome Android e Safari iOS), incluindo a visão por data a 360 px, e registrar o resultado na descrição do PR
- [ ] T070 Rodar o conjunto completo: `npm run lint`, `npm run typecheck`, `npm test`, `npm run test:integracao`, `npx supabase test db`, `npm run test:e2e`; tudo verde
- [ ] T071 Abrir o PR para `develop` com contexto, mudança e motivação (constitution VII), conceitos de teste explicados e checklist de acessibilidade/mobile

---

## Dependências e ordem de execução

- **Fase 1** → **Fase 2** (bloqueia tudo) → histórias → **Fase 8**.
- **US1** (criar consultas) vem primeiro: sem consulta não há o que responder. **US2** e **US3** dependem da US1 para criar dados pela interface, mas as migrações próprias só dependem da Fase 2, e o seed (T064) permite testá-las sozinhas. **US2** e **US3** podem andar em paralelo (arquivos diferentes; a página `[consultaId]` do gestor é só da US3 e US4).
- **US4** depende da grade (US3) para a interface; a função do banco depende só da Fase 2.
- **US5** depende da US1/US2 para haver respostas, e da 003 (já entregue).
- Dentro de cada história: testes escritos e vistos **falhando** → migração → ações → componentes → páginas → verificação.
- Migrações são aplicadas em ordem numérica, que é a mesma ordem das histórias; cada história cria **migrações novas** e nunca edita as anteriores.

## Oportunidades de paralelismo

- Fase 2: T005, T007 e T008–T011 em paralelo (arquivos distintos).
- Em cada história, todos os testes marcados [P] podem ser escritos juntos, e as Server Actions/componentes [P] em paralelo depois da migração.
- US2 e US3 podem ser feitas por sessões diferentes, desde que não editem os mesmos arquivos (`acoes.ts` de cada área é separado).

## Estratégia de implementação

1. **MVP**: Fases 1 e 2 + US1 + US2 + US3 (líder cria, participante responde, líder acompanha na grade). Já substitui o formulário externo.
2. **Incremento 2**: US4 (preencher pelo líder) e US5 (integração com escalas), depois acabamento.
3. Parar em cada ponto de verificação, rodar toda a bateria de testes e só então seguir.

## Notas de implementação

- (a preencher durante a implementação: diferenças do Next.js 16, ajustes de desenho e decisões tomadas no caminho)
