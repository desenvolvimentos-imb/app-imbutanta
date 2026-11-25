# Modelo de Dados: Disponibilidade dos Participantes

Nomes em português, conforme constitution VII. SQL completo fica nas migrações
(`supabase/migrations/`), não aqui. Parte dos modelos anteriores:
[001](../001-login-papeis-acesso/data-model.md), [002](../002-ministerios-participantes/data-model.md)
e [003](../003-escalas-ministerios/data-model.md).

## Tipo enumerado (novo)

| Tipo | Valores |
|------|---------|
| `resposta_disponibilidade` | `disponivel`, `indisponivel` ("sem resposta" = sem linha; ver [Decisão 1](research.md#decisao-1)) |

As funções de tempo `agora_sp()` e `hoje_sp()` são as da 003.

## Tabela `consultas_disponibilidade`

Pedido do líder a um ministério (RF-001, RF-006 a RF-013).

| Campo | Tipo | Regras |
|-------|------|--------|
| `id` | uuid, chave primária | `gen_random_uuid()` |
| `ministerio_id` | uuid | referencia `ministerios(id)`, `on delete restrict` |
| `titulo` | texto, obrigatório | 2 a 80 caracteres, sem espaços nas pontas |
| `mensagem` | texto | até 500 caracteres; padrão vazio |
| `prazo` | date, anulável | último dia para responder; ao fim desse dia a consulta vale como fechada |
| `fechada` | booleano | padrão `false`; `true` quando o líder fecha ou o ministério é desativado |
| `criada_por` | uuid, anulável | referencia `perfis(id)`, `on delete set null` |
| `criada_em`, `atualizada_em` | timestamptz | padrão `now()`; `atualizada_em` muda a cada alteração |

Chave única `(id, ministerio_id)` (alvo da chave composta de `datas_consulta`). Índice
`(ministerio_id, criada_em desc)`.

**Situação efetiva** (calculada, nunca gravada): `aberta` quando `fechada = false` e (`prazo` nulo ou
`hoje_sp() <= prazo`); caso contrário `fechada`. Motivo da situação exibida: "Fechada pelo líder",
"Prazo encerrado" ou "Ministério desativado" (deduzido de `fechada`, `prazo` e `ministerios.ativo`).

**Estados e transições** (RF-006 a RF-011):

| De | Para | Quem/como |
|----|------|-----------|
| (nova) | aberta | `criar_consulta` |
| aberta | fechada | `fechar_consulta` (líder/administrador); ou prazo vencido (automático); ou ministério desativado |
| fechada | aberta | `reabrir_consulta`: se o prazo está vencido, exige novo prazo (hoje ou depois) ou remoção do prazo; ministério precisa estar ativo |

Não há exclusão: nenhuma função apaga consultas e as tabelas não aceitam `delete` direto.

## Tabela `datas_consulta`

Datas propostas na consulta (RF-002 a RF-005, RF-009, RF-010).

| Campo | Tipo | Regras |
|-------|------|--------|
| `id` | uuid, chave primária | `gen_random_uuid()` |
| `consulta_id` | uuid | referencia `consultas_disponibilidade(id)`, `on delete cascade` |
| `ministerio_id` | uuid | igual ao da consulta; chave estrangeira composta `(consulta_id, ministerio_id)` garante que bate |
| `data` | date, obrigatório | ao criar/adicionar: `>= hoje_sp()` |
| `rotulo` | texto | até 40 caracteres; padrão vazio (ex.: "Culto especial") |
| `criada_em` | timestamptz | padrão `now()` |

**Índice único** `(ministerio_id, data)`: a mesma data não entra em duas consultas do mesmo ministério,
mas pode se repetir em ministérios diferentes ([Decisão 3](research.md#decisao-3)). Índice
`(consulta_id, data)`. Máximo de 31 datas por consulta (validado pelas funções de escrita). Toda
consulta mantém ao menos uma data (`remover_data_consulta` recusa a última).

## Tabela `respostas_disponibilidade`

Resposta de uma pessoa numa data (RF-014 a RF-017, RF-021).

| Campo | Tipo | Regras |
|-------|------|--------|
| `data_id` | uuid | referencia `datas_consulta(id)`, `on delete cascade` (remover a data descarta as respostas) |
| `perfil_id` | uuid | referencia `perfis(id)`, `on delete cascade` (exclusão de conta apaga) |
| `resposta` | `resposta_disponibilidade` | `disponivel` ou `indisponivel` |
| `preenchida_por` | uuid, anulável | quando preenchida/corrigida pelo líder: quem foi; `on delete set null`. Nulo = a própria pessoa respondeu |
| `atualizada_em` | timestamptz | padrão `now()` |

Chave primária `(data_id, perfil_id)`. Índice `(perfil_id)`. **Sem linha = "sem resposta".**
`preenchida_por` guarda quem alterou a resposta por último e só muda quando a resposta muda: quando o líder
preenche, recebe o id dele; quando a própria pessoa muda o valor depois, volta a nulo (RF-021).
Repetir a mesma resposta não altera a marca. Ao deixar o ministério, **nada é apagado**: a linha só não é lida
([Decisão 8](research.md#decisao-8)).

## Tabela `observacoes_disponibilidade`

Observação opcional por pessoa e consulta (RF-018).

| Campo | Tipo | Regras |
|-------|------|--------|
| `consulta_id` | uuid | referencia `consultas_disponibilidade(id)`, `on delete cascade` |
| `perfil_id` | uuid | referencia `perfis(id)`, `on delete cascade` |
| `texto` | texto, obrigatório | 1 a 300 caracteres; observação vazia apaga a linha |
| `atualizada_em` | timestamptz | padrão `now()` |

Chave primária `(consulta_id, perfil_id)`. Só o autor e líderes/administradores a leem. O líder
**não** edita a observação de outra pessoa.

## Regras de acesso (RLS e funções)

| Tabela | `anon` | `authenticated` | Observação |
|--------|--------|-----------------|------------|
| as quatro | nenhum acesso | nenhum acesso direto | RLS ligada; todo acesso por funções `security definer` ([Decisão 4](research.md#decisao-4)) |

Quem pode o quê (aplicado dentro das funções):

| Ação | Participante ativo | Líder do ministério | Administrador | Outros |
|------|--------------------|---------------------|---------------|--------|
| ver consultas abertas e responder | sim (só as próprias respostas) | sim, como participante | só se for participante | não |
| ver consulta fechada própria (somente leitura) | sim | sim | sim | não |
| criar/alterar/fechar/reabrir consulta e datas | não | sim (do seu ministério) | sim | não |
| ver grade, respostas alheias, observações | não | sim | sim | não |
| preencher/corrigir resposta de outra pessoa | não | sim (inclusive consulta fechada) | sim | não |

Toda **escrita** exige ministério ativo (`ministerio_inativo`), inclusive para o administrador; as
**leituras** de consultas de ministério desativado continuam permitidas (histórico).

## Mudanças em estruturas anteriores

- `desativar_ministerio` (002/003): passa também a marcar `fechada = true` nas consultas abertas do
  ministério, na mesma transação (RF-013).
- `avisos_para_vaga` (003): novo tipo de aviso `sem_disponibilidade`
  ([Decisão 10](research.md#decisao-10)). Os avisos existentes não mudam.
- Nenhuma tabela da 001–003 é alterada; nenhum gatilho novo sobre elas.

## Migrações previstas

Ordem em `supabase/migrations/` (prefixo `20261124…`, nunca editar migração aplicada):

1. `…120001_disponibilidade_tipos_e_tabelas.sql`: tipo, tabelas, índices, restrições
2. `…120002_disponibilidade_acesso.sql`: RLS ligada sem permissões e auxiliares (`consulta_esta_aberta`, `exigir_gestor_consulta`, `exigir_participante_consulta`)
3. `…120003_disponibilidade_consultas.sql`: criar, editar, datas, fechar, reabrir, listar consultas do ministério
4. `…120004_desativar_ministerio_consultas.sql`: `desativar_ministerio` redefinida
5. `…120005_disponibilidade_respostas.sql`: responder, minhas consultas, contador da tela inicial
6. `…120006_disponibilidade_grade.sql`: grade do líder
7. `…120007_disponibilidade_preencher.sql`: preenchimento pelo líder
8. `…120008_disponibilidade_escalas.sql`: `avisos_para_vaga` redefinida e `disponibilidade_da_escala`
