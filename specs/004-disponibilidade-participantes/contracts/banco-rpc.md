# Contrato do Banco: Funções (RPC) e Regras: Disponibilidade

Interface entre o app Next.js e o Supabase. Segue as convenções da 001, 002 e 003
([banco-rpc.md da 003](../../003-escalas-ministerios/contracts/banco-rpc.md)): funções
`security definer` com `search_path` fixo, que **validam `auth.uid()` por dentro** e nunca confiam
num valor possivelmente nulo para decidir permissão; erros com código estável na mensagem; cada
função tem teste pgTAP (constitution IV). O app chama com `supabase.rpc('<nome>', {...})`.

**Convenção de travas**: toda função que altera uma consulta começa travando a linha dela
(`for update`) e só então avalia o estado ([Decisão 5](../research.md#decisao-5)).

**Ministério ativo**: toda **escrita** exige ministério ativo (`ministerio_inativo`), inclusive para
o administrador; as leituras de ministério desativado continuam permitidas.

**Papéis**: "gestor" = administrador aprovado **ou** líder válido do ministério (`eh_gestor_de`,
`exigir_gestor_ministerio` da 002/003); "participante" = conta aprovada com participação no
ministério (`eh_participante_de`).

## Novos códigos de erro

Somam-se aos da 001–003 (`sem_permissao`, `nao_encontrado`, `ministerio_inativo`, `nao_participante`
e `data_passada` já existem).

| Código | Significado | Mensagem ao usuário |
|--------|-------------|---------------------|
| `consulta_invalida` | título, mensagem, rótulo ou observação fora das regras, ou mais de 31 datas | "Confira os dados: título de 2 a 80 caracteres, observação de até 300." |
| `consulta_sem_datas` | criar sem data, ou remover a última data | "A consulta precisa ter pelo menos uma data." |
| `consulta_fechada` | ação que só vale em consulta aberta | "Esta consulta está fechada." |
| `consulta_ja_aberta` | reabrir/editar prazo de consulta que já está aberta | "Esta consulta já está aberta." |
| `prazo_invalido` | prazo anterior a hoje | "O prazo não pode ser anterior a hoje." |
| `prazo_vencido` | reabrir mantendo prazo vencido | "O prazo desta consulta já passou. Informe um novo prazo ou remova o prazo para reabrir." |
| `data_duplicada` | a data já está em outra consulta do mesmo ministério (o `detail` traz o título) | "Essa data já está na consulta “…” deste ministério." |
| `data_encerrada` | participante tenta responder data que já passou | "Esta data já passou e não aceita mais respostas." |
| `resposta_invalida` | resposta ou data fora da consulta, ou valor desconhecido | "Resposta inválida. Atualize a tela e tente de novo." |

A necessidade de confirmação **não** é erro: volta como dado (veja `remover_data_consulta`).

## Auxiliares (internas, sem permissão para `anon`/`authenticated`)

- `consulta_esta_aberta(c consultas_disponibilidade)` → boolean: `not fechada and (prazo is null or hoje_sp() <= prazo)`.
- `exigir_gestor_consulta(p_consulta)`: trava a consulta (`for update`), exige gestor do ministério e
  ministério ativo; devolve a consulta. Levanta `nao_encontrado` se não existir.
- `exigir_participante_consulta(p_consulta)`: exige participante aprovado do ministério da consulta.

## Gestão de consultas (gestor)

### `criar_consulta(p_ministerio uuid, p_titulo text, p_mensagem text, p_prazo date, p_datas jsonb)` → `consultas_disponibilidade`
`p_datas` = `[{ "data": "2026-12-06", "rotulo": "Culto especial" }, …]`. Cria a consulta aberta e
todas as datas na mesma transação. Erros: `sem_permissao`, `ministerio_inativo`, `consulta_invalida`,
`consulta_sem_datas`, `data_passada`, `prazo_invalido`, `data_duplicada` (entre as datas pedidas
repetidas ou já existentes no ministério).

### `editar_consulta(p_consulta uuid, p_titulo text, p_mensagem text, p_prazo date)` → `consultas_disponibilidade`
Só em consulta aberta (`consulta_fechada`). Altera título, mensagem e prazo (nulo remove o prazo).
`prazo_invalido` se anterior a hoje.

### `adicionar_datas_consulta(p_consulta uuid, p_datas jsonb)` → `datas_consulta[]`
Só em consulta aberta. As novas datas começam "sem resposta" para todos. Mesmas validações de
`criar_consulta` para data; total máximo de 31 (`consulta_invalida`).

### `remover_data_consulta(p_data uuid, p_confirmado boolean default false)` → jsonb
Só em consulta aberta. Recusa a última data (`consulta_sem_datas`).
- Sem respostas na data: remove e devolve `{ "removida": true, "respostas_descartadas": 0 }`.
- Com respostas e `p_confirmado` falso: **não grava**; devolve
  `{ "removida": false, "confirmacao_necessaria": true, "respostas": N }`.
- Com respostas e `p_confirmado` verdadeiro: remove a data e descarta as respostas; devolve
  `{ "removida": true, "respostas_descartadas": N }`.

### `fechar_consulta(p_consulta uuid)` → `consultas_disponibilidade`
Marca `fechada = true`. Idempotente se já estiver fechada pelo líder.

### `reabrir_consulta(p_consulta uuid, p_prazo date default null, p_remover_prazo boolean default false)` → `consultas_disponibilidade`
Marca `fechada = false`. Se, após aplicar `p_prazo` (ou remover o prazo com `p_remover_prazo`), o
prazo continuar vencido → `prazo_vencido`. `prazo_invalido` se `p_prazo` for anterior a hoje.
`consulta_ja_aberta` se já estiver aberta. Exige ministério ativo.

## Respostas

### `responder_disponibilidade(p_consulta uuid, p_respostas jsonb, p_observacao text)` → jsonb
Participante ativo do ministério, consulta **aberta**. `p_respostas` =
`[{ "data_id": "…", "resposta": "disponivel" | "indisponivel" | null }, …]` (nulo = voltar a "sem
resposta"). `p_observacao` nula mantém a observação atual; texto vazio a apaga; mais de 300
caracteres → `consulta_invalida`. Tudo ou nada. Zera `preenchida_por` nas linhas gravadas. Datas que
já passaram → `data_encerrada`; data de outra consulta → `resposta_invalida`. Retorna
`{ "salvo": true, "sem_resposta": N }`.

### `preencher_disponibilidade(p_consulta uuid, p_perfil uuid, p_respostas jsonb)` → jsonb
Gestor; consulta aberta **ou fechada**; `p_perfil` precisa ser participante do ministério
(`nao_participante`). Mesmo formato de `p_respostas`; grava `preenchida_por = auth.uid()`. Aceita
datas passadas. Não altera observação. Retorna `{ "salvo": true }`.

## Leituras

Todas devolvem só nome (nunca email) e já filtram quem saiu do ministério.

### `minhas_consultas()` → jsonb
Consultas **abertas** de todos os ministérios em que a pessoa participa, com datas, rótulos, mensagem,
prazo, minhas respostas, minha observação e `sem_resposta` (quantas datas ainda sem marcar). Cada
pessoa vê só o que é seu. Também inclui, em `fechadas_recentes`, as fechadas dos últimos 60 dias
(somente leitura), para a pessoa conferir o que respondeu.

### `contar_consultas_pendentes()` → integer
Quantas consultas abertas, dos ministérios ativos da pessoa, têm ao menos uma data (que ainda aceita
resposta) sem resposta dela. Alimenta o aviso da tela inicial.

### `ler_consulta_participante(p_consulta uuid)` → jsonb
Uma consulta com as respostas e a observação **da própria pessoa**; `null` se não for participante.
Funciona para consulta fechada (somente leitura), com `pode_responder` falso.

### `listar_consultas_ministerio(p_ministerio uuid)` → jsonb
Gestor. Todas as consultas do ministério (abertas primeiro, depois histórico por data), cada uma com
situação efetiva e motivo, prazo, quantidade de datas e de participantes que ainda não responderam
nada. Participante sem liderança recebe `[]`.

### `ler_consulta_gestor(p_consulta uuid)` → jsonb
Gestor. A grade completa:

```json
{
  "consulta": { "id": "…", "ministerio_id": "…", "ministerio": "Louvor", "titulo": "Escala de dezembro",
                "mensagem": "…", "prazo": "2026-11-30", "aberta": true, "motivo_fechada": null },
  "datas": [ { "id": "…", "data": "2026-12-06", "rotulo": "Culto especial", "passada": false,
               "disponiveis": 5, "indisponiveis": 2, "sem_resposta": 3,
               "por_funcao": [ { "funcao_id": "…", "funcao": "Vocal", "disponiveis": 0, "faltando": true } ] } ],
  "participantes": [ { "perfil_id": "…", "nome": "Ana", "nao_respondeu": false,
                       "observacao": "…", "respostas": { "<data_id>": { "resposta": "disponivel", "preenchida_pelo_lider": true } } } ],
  "tem_funcoes": true
}
```

Participantes ativos do ministério, ordenados por nome; `respostas` só traz as datas marcadas (as
ausentes são "sem resposta"); `nao_respondeu` = nenhuma data marcada.

### `disponibilidade_da_escala(p_escala uuid)` → table (`perfil_id uuid`, `resposta text`)
Gestor da escala. Para cada participante ativo do ministério da escala, a resposta na data da escala:
`disponivel`, `indisponivel` ou `sem_resposta`; devolve **zero linhas** quando a data da escala não
pertence a nenhuma consulta do mesmo ministério (a interface então não mostra nada, RF-030).
Consultas de outros ministérios são ignoradas.

## Funções alteradas

### `avisos_para_vaga(p_escala, p_perfil, p_funcao)` (003)
Redefinida por migração nova. Dentro da mesma condição dos avisos de "outro ministério" (pessoa ainda
sem vaga nesta escala), se a data da escala está numa consulta do mesmo ministério e a pessoa não está
"disponível", acrescenta `{ "tipo": "sem_disponibilidade", "resposta": "indisponivel" | "sem_resposta" }`.
Avisos existentes e sua ordem não mudam. Mensagens: "Esta pessoa marcou que está indisponível nesta
data." e "Esta pessoa ainda não respondeu sobre esta data."

### `desativar_ministerio(p_id)` (002/003)
Além do que já faz, `update consultas_disponibilidade set fechada = true` nas abertas do ministério.

## Convenção de permissões das funções

Toda função pública: `revoke execute … from public, anon; grant execute … to authenticated;`. As
auxiliares ficam sem permissão para `anon`/`authenticated`. Cada função tem teste pgTAP de
permissão (visitante, membro de outro ministério, participante comum, líder, líder de outro
ministério, administrador).
