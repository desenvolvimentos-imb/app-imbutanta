# Contrato do Banco: Funções (RPC) e Regras: Escalas

Interface entre o app Next.js e o Supabase. Segue as convenções da 001 e da 002
([banco-rpc.md da 002](../../002-ministerios-participantes/contracts/banco-rpc.md)): funções
`security definer` com `search_path` fixo, que **validam `auth.uid()` por dentro** e nunca confiam
num valor possivelmente nulo para decidir permissão; erros com código estável na mensagem; cada
função tem teste pgTAP (constitution IV). O app chama com `supabase.rpc('<nome>', {...})`.

**Convenção de travas**: toda função que altera uma escala começa travando a linha dela
(`for update`) e só então avalia o estado ([Decisão 4](../research.md#decisao-4)).

**Ministério ativo**: toda função de **escrita** exige ministério ativo (`ministerio_inativo`), inclusive para o administrador; as leituras de escalas de ministério desativado continuam permitidas (somente leitura).

**Convenções de papéis** (a partir da 002): "gestor" = administrador aprovado **ou** líder válido do
ministério (`exigir_gestor_ministerio`); "participante" = conta aprovada com participação no
ministério ativo.

## Novos códigos de erro

Somam-se aos da 001 e da 002.

| Código | Significado | Mensagem ao usuário |
|--------|-------------|---------------------|
| `funcao_duplicada` | já existe função ativa com esse nome no ministério | "Já existe uma função ativa com esse nome neste ministério." |
| `funcao_invalida` | função desativada/de outro ministério, ou nome fora das regras | "Escolha uma função ativa deste ministério." |
| `evento_invalido` | evento, rótulo ou observação fora das regras | "Informe o nome do evento (2 a 80 caracteres)." |
| `data_passada` | criar/mover escala para data anterior a hoje | "A data não pode ser anterior a hoje." |
| `escala_somente_leitura` | já é o dia seguinte à data da escala | "Esta escala já passou e não pode mais ser alterada." |
| `escala_cancelada` | a escala está cancelada | "Esta escala foi cancelada." |
| `escala_sem_vagas` | publicar sem nenhuma vaga | "Adicione ao menos uma vaga antes de publicar." |
| `escala_nao_publicada` | ação que só vale em escala publicada | "Esta escala ainda não foi publicada." |
| `limite_vagas` | mais de 50 vagas | "Uma escala pode ter no máximo 50 vagas." |
| `nao_participante` | pessoa escolhida não participa do ministério | "Só participantes do ministério podem ser escalados." |
| `evento_iniciado` | o horário de início já passou | "O horário de início deste evento já passou." |
| `nao_escalado` | a pessoa não ocupa vaga na escala | "Você não está escalado nesta escala." |
| `ja_escalada` | a indicada já ocupa vaga nessa escala | "Esta pessoa já está escalada nesta escala." |
| `troca_duplicada` | a vaga já tem pedido de troca pendente | "Esta vaga já tem um pedido de troca em andamento." |
| `conflito_troca` | a situação do pedido mudou desde que a tela abriu | "Este pedido já foi decidido ou perdeu efeito. Atualize a lista." |
| `troca_invalida` | indicar a si mesma ou pessoa inelegível | "Escolha outra pessoa do ministério que ainda não esteja nesta escala." |

(`sem_permissao`, `nao_encontrado` e `ministerio_inativo` já existem.) Não há erro para os avisos:
eles voltam como **dados** (veja `salvar_vaga`).

## Formato dos avisos (jsonb)

```json
[
  { "tipo": "outro_ministerio", "ministerio": "Recepção", "evento": "Culto de domingo", "horario": "09:00" },
  { "tipo": "sem_aptidao", "funcao": "Violão" }
]
```

A mensagem de `outro_ministerio` na interface é sempre "participante já escalado em outro ministério
neste mesmo dia" mais os dados da outra escala.

**Quando `outro_ministerio` vale**: a outra escala é de outro ministério, está **publicada**, é do mesmo dia e a resposta da pessoa nela é `confirmado`. Rascunho, cancelada, resposta pendente ou recusada não geram o aviso. O mesmo critério vale ao aprovar uma troca.

## Funções e aptidões (gestor)

### `criar_funcao(p_ministerio uuid, p_nome text)` → `funcoes_ministerio`
- **Regras**: gestor; ministério ativo; nome 2–40; `funcao_duplicada` entre ativas (sem diferenciar
  caixa, acento nem espaços repetidos).

### `editar_funcao(p_funcao uuid, p_nome text)` → `funcoes_ministerio`
- **Regras**: gestor; mesmas validações; renomear não altera vagas existentes (elas apontam para a
  função, não para o texto).

### `desativar_funcao(p_funcao uuid)` / `reativar_funcao(p_funcao uuid)` → `funcoes_ministerio`
- **Efeito**: troca `ativa`; vagas e escalas passadas **não mudam** (FR-003). Reativar exige nome
  livre entre as ativas (`funcao_duplicada`). Idempotentes.

### `definir_aptidoes(p_ministerio uuid, p_perfil uuid, p_aptidoes jsonb)` → void
- **Entrada**: `[{ "funcao": uuid, "tipo": "principal" | "secundaria" }, ...]` (a lista completa
  da pessoa; o que não estiver nela é removido).
- **Regras**: gestor; a pessoa participa do ministério; todas as funções são do ministério
  (desativadas **podem permanecer** na lista, mas não podem ser adicionadas novas); `funcao_invalida`.

### `listar_funcoes(p_ministerio uuid, p_incluir_inativas boolean default false)` → tabela
- **Quem**: gestor ou participante do ministério. **Devolve**: `id`, `nome`, `ativa`.

### `listar_aptidoes(p_ministerio uuid)` → tabela (`perfil_id`, `nome`, `funcao_id`, `tipo`)
- **Quem**: gestor. Só participantes do ministério; nunca email.

### `minhas_aptidoes(p_ministerio uuid)` → tabela (`funcao_id`, `funcao`, `tipo`)
- **Quem**: a própria pessoa (para mostrar "suas funções").

## Escalas (gestor)

### `criar_escala(p_ministerio uuid, p_evento text, p_data date, p_horario time, p_observacao text default '')` → `escalas`
- **Efeito**: cria como `rascunho`. **Regras**: gestor; ministério ativo; `evento_invalido`;
  `data_passada` se `p_data < hoje_sp()`.

### `editar_escala(p_escala uuid, p_evento text, p_data date, p_horario time, p_observacao text)` → `escalas`
- **Regras**: gestor; não cancelada (`escala_cancelada`); não somente leitura
  (`escala_somente_leitura`); `data_passada` se a **nova** data for anterior a hoje.
- **Efeito se data ou horário mudou em escala publicada** (FR-015): apaga todas as linhas de
  `respostas_escala` da escala e marca como `sem_efeito` os pedidos de troca pendentes. Mudar só
  evento ou observação não mexe em respostas nem pedidos. Em rascunho nada precisa ser limpo.

### `salvar_vaga(p_escala uuid, p_vaga uuid, p_funcao uuid, p_rotulo text, p_perfil uuid, p_ciente boolean default false)` → jsonb
- **Uso**: cria (`p_vaga` nulo) ou altera a vaga. `p_perfil` nulo = "em aberto".
- **Retorno**: `{ "salvo": true, "vaga": {...}, "avisos": [] }`, ou
  `{ "salvo": false, "avisos": [ ... ] }` quando há avisos e `p_ciente` é falso (nada é gravado).
- **Regras**: gestor; escala não cancelada e não somente leitura; função ativa e do ministério
  (ao criar a vaga ou trocar a função; uma vaga existente com função já desativada pode ser
  editada sem trocar a função); `nao_participante`; `limite_vagas`.
- **Avisos**: calculados quando `p_perfil` não é nulo e **mudou** em relação ao valor atual
  (ver [Decisão 5](../research.md#decisao-5)).
- **Efeitos em escala publicada** (FR-014): se a pessoa da vaga mudou, a anterior deixa de estar
  escalada; se não ocupa mais nenhuma vaga na escala, a resposta dela é apagada; o pedido de troca
  pendente dessa vaga vira `sem_efeito`. A nova pessoa fica "pendente" (sem resposta), a menos que
  já tenha resposta na escala ([Decisão 1](../research.md#decisao-1)).

### `remover_vaga(p_vaga uuid)` → void
- **Regras**: gestor; escala não cancelada e não somente leitura. Mesmos efeitos de pessoa/pedido de
  `salvar_vaga` ao tirar a pessoa.

### `publicar_escala(p_escala uuid)` → `escalas`
- **Regras**: gestor; está em `rascunho`; tem ao menos uma vaga (`escala_sem_vagas`); não somente
  leitura. Publicar com vagas em aberto é permitido (FR-011). Idempotente se já publicada.

### `cancelar_escala(p_escala uuid)` → `escalas`
- **Regras**: gestor; não somente leitura. **Efeito**: `situacao = 'cancelada'`, `cancelada_em`; as
  respostas ficam gravadas, mas **perdem efeito** (as telas mostram "cancelada" e não deixam
  responder); pedidos pendentes viram `sem_efeito` (FR-013). Idempotente.

### `listar_candidatos_escala(p_escala uuid)` → tabela (`id`, `nome`, `apta_para jsonb`)
- **Quem**: gestor. Participantes do ministério (aprovados) com as funções em que são aptos, para o
  seletor de pessoas na vaga. Nunca email.

### `contar_escalas_futuras(p_ministerio uuid)` → inteiro
- **Quem**: administrador. Conta escalas **não canceladas** com `data >= hoje_sp()`; é o número
  mostrado antes de desativar o ministério (FR-020).

### `contar_escalas_com_vagas_abertas(p_ministerio uuid)` → inteiro
- **Quem**: gestor. Escalas futuras, não canceladas, com ao menos uma vaga em aberto.

## Leitura de escalas

### `listar_escalas_ministerio(p_ministerio uuid, p_passadas boolean default false)` → tabela
- **Quem**: gestor (vê rascunhos, publicadas e canceladas) ou participante (vê publicadas e
  canceladas em que esteve escalado). Quem não participa recebe **zero linhas** (não um erro que revele
  o ministério).
- **Devolve** por escala: `id`, `evento`, `data`, `horario`, `situacao`, `total_vagas`,
  `vagas_abertas` e, **só para gestor**, `recusadas` e `sem_resposta`.
- **Ordem**: próximas por data crescente; passadas por data decrescente (sem limite de tempo; volume pequeno).

### `ler_escala(p_escala uuid)` → jsonb
- **Quem**: mesmas regras de visibilidade. **Devolve**: dados da escala; `vagas` (id, função,
  rótulo, pessoa `{id, nome}` ou nulo, `em_aberto`); `minhas_vagas`; `minha_resposta`
  (`pendente|confirmado|recusado`, motivo); `pode_responder`, `pode_pedir_troca`; e **somente para
  gestor**, `respostas` por pessoa (resposta e motivo) e o destaque `precisa_atencao` de cada vaga
  (`recusada`, `sem_resposta`, `em_aberto`).
- **Privacidade**: participante comum **nunca** recebe respostas nem motivos de outras pessoas
  (FR-022). `somente_leitura` e `iniciada` vêm calculados para a interface.

### `minhas_escalas(p_passadas boolean default false)` → tabela
- **Quem**: qualquer conta aprovada. Escalas **publicadas** (ou canceladas) em que a pessoa ocupa
  vaga: `escala_id`, `ministerio`, `evento`, `funcoes` (todas as dela), `data`, `horario`,
  `situacao`, `minha_resposta`, `motivo`. Próximas em ordem de data; passadas por data decrescente.
- **Contador** para a tela inicial: `contar_pendencias_escala()` → `{ sem_resposta, trocas_recebidas, trocas_para_aprovar }`.

## Confirmação e recusa

### `responder_escala(p_escala uuid, p_resposta resposta_escala, p_motivo text default '')` → void
- **Quem**: quem ocupa ao menos uma vaga da escala (`nao_escalado`).
- **Regras**: escala `publicada` (`escala_nao_publicada`, `escala_cancelada`); `agora < inicio`
  (`evento_iniciado`); motivo até 200 caracteres e só gravado quando `recusado`. Grava (ou
  substitui) a linha única da pessoa, valendo para todas as vagas dela (FR-026).
- **Efeito**: a vaga recusada continua com a pessoa (FR-028).

## Pedidos de troca

### `pedir_troca(p_vaga uuid, p_indicada uuid)` → `pedidos_troca`
- **Quem**: a pessoa que ocupa a vaga.
- **Regras**: escala `publicada` e `agora < inicio`; indicada é participante do ministério ativo,
  conta aprovada, diferente do solicitante e **sem nenhuma vaga na escala** (`ja_escalada`,
  `troca_invalida`); `troca_duplicada` se a vaga já tem pedido pendente.
- **Efeito**: cria em `aguardando_indicada`; nada muda na escala (FR-031).

### `responder_pedido_troca(p_pedido uuid, p_aceita boolean)` → `pedidos_troca`
- **Quem**: a indicada. **Regras**: pedido em `aguardando_indicada` (`conflito_troca`); escala
  publicada e `agora < inicio`; a indicada ainda não foi escalada na escala por outro caminho
  (senão o pedido vira `sem_efeito` e retorna `ja_escalada`).
- **Efeito**: aceitar → `aguardando_lider`; recusar → `recusado_indicada`.

### `decidir_troca_lider(p_pedido uuid, p_aprova boolean, p_ciente boolean default false)` → jsonb
- **Quem**: gestor do ministério da escala.
- **Retorno ao aprovar**: igual a `salvar_vaga`: se há avisos (aptidão da indicada para a função;
  outro ministério no mesmo dia) e `p_ciente` é falso, devolve `{ "decidido": false, "avisos": [...] }`
  sem alterar nada (FR-034).
- **Efeito (aprovar, tudo na mesma transação — FR-035)**: trava a escala; confere que o pedido está
  `aguardando_lider`, que a escala está publicada e não iniciada, que o solicitante ainda ocupa a
  vaga e que a indicada ainda não tem vaga na escala; então: `vagas_escala.perfil_id = indicada`;
  `respostas_escala` da indicada = `confirmado`; se o solicitante não ocupa mais nenhuma vaga na
  escala, apaga a resposta dele (as outras vagas dele permanecem com a resposta atual); pedido
  `aprovado`; os demais pedidos pendentes da **mesma indicada** nessa escala e os da mesma vaga viram
  `sem_efeito`. Qualquer falha desfaz tudo.
- **Efeito (recusar)**: pedido `recusado_lider`; nada muda na escala.
- **Erros**: `conflito_troca` se o pedido já não está em `aguardando_lider`.

### `cancelar_pedido_troca(p_pedido uuid)` → `pedidos_troca`
- **Quem**: o solicitante ou o gestor. **Regras**: pedido em `aguardando_indicada` ou
  `aguardando_lider` (`conflito_troca`). **Efeito**: `cancelado`; nada muda na escala (FR-031).

### `listar_pedidos_troca()` → tabela
- **Quem**: conta aprovada. Devolve, para a pessoa, os pedidos **feitos** e **recebidos**
  (qualquer situação, mais recentes primeiro) e, para quem é gestor, os pedidos
  `aguardando_lider` dos ministérios que gerencia (`papel_na_lista`: `solicitante`, `indicada`,
  `gestor`). Campos: pedido, ministério, evento, data, horário, função/rótulo da vaga, nome do
  solicitante e da indicada (nunca email), situação **efetiva** (um pedido pendente de escala já
  iniciada ou cancelada aparece como `sem_efeito`), `pode_decidir` (calculado).
- **Observação**: o gestor vê apenas os que aguardam a sua aprovação e os que ele mesmo fez/recebeu,
  não o histórico de terceiros.

### `listar_candidatas_troca(p_vaga uuid)` → tabela (`id`, `nome`)
- **Quem**: quem ocupa a vaga. Participantes do ministério, sem vaga na escala e diferentes de quem
  pede. Nunca email.

## Ajustes em funções da 002 (migrações novas)

| Função | Mudança |
|--------|---------|
| `desativar_ministerio` | além de desativar, cancela as escalas **não canceladas com `data >= hoje_sp()`** do ministério, na mesma transação (FR-020) |
| `participacoes_ministerio` (gatilho `after delete`) | `liberar_vagas_futuras(perfil, ministerio)` (FR-019) |
| `perfis` (gatilho `after update` de `situacao`) | quando deixa de ser `aprovado`, `liberar_vagas_futuras(perfil, null)` |

### `liberar_vagas_futuras(p_perfil uuid, p_ministerio uuid)` (interna, sem acesso público)
- Para vagas da pessoa em escalas não canceladas com `data >= hoje_sp()` (do ministério, ou de todos
  quando `p_ministerio` é nulo): `perfil_id = null`; apaga a resposta dela nessas escalas; marca como
  `sem_efeito` os pedidos de troca pendentes em que ela é solicitante ou indicada nessas escalas.
  Escalas passadas ficam intactas.

## Testes obrigatórios por função (resumo)

Para cada função: negado sem permissão (anônimo, membro de outro ministério, líder de outro
ministério); caminho feliz; cada código de erro acima; e os efeitos listados. Específicos:
relógio fixado redefinindo `agora_sp()` na transação do teste (hoje, ontem, amanhã, mesmo dia depois do horário); troca atômica com
falha forçada; duas ações concorrentes sobre a mesma escala; privacidade das respostas; cascata de
remoção e de perda de acesso; cancelamento de escalas ao desativar ministério.
