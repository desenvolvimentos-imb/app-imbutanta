# Pesquisa e Decisões: Disponibilidade dos Participantes

Nenhum item ficou "a esclarecer" no Contexto Técnico: a stack e as convenções vêm da 001–003. Esta
pesquisa registra as decisões de desenho novas. Formato: Decisão, Justificativa, Alternativas.

<a id="decisao-1"></a>
## Decisão 1: "Sem resposta" é a ausência de linha

- **Decisão**: `respostas_disponibilidade` só tem linhas para datas já marcadas (`disponivel` ou
  `indisponivel`). Quem não tem linha numa data está "sem resposta".
- **Justificativa**: o tipo da resposta nem tem o valor "sem resposta", então é impossível tratá-la
  como "indisponível" por engano (RF-017). Adicionar data nova (RF-009) não exige criar nada para
  ninguém; remover a data apaga as linhas por cascata; quem entra depois no ministério já está "sem
  resposta" por definição. Mesmo princípio do "pendente" da 003 ([decisão 1](../003-escalas-ministerios/research.md#decisao-1)).
- **Alternativas**: criar uma linha `sem_resposta` para cada pessoa × data. Rejeitada: obrigaria
  conciliar linhas a cada pessoa que entra ou sai e a cada data adicionada.
- **Regra derivada**: a pessoa pode "desmarcar" uma data (voltar a "sem resposta"); isso apaga a
  linha. Um líder corrigindo resposta também pode limpar uma data.

<a id="decisao-2"></a>
## Decisão 2: "Aberta" é calculada: não fechada e prazo não vencido

- **Decisão**: a consulta guarda `fechada` (boolean, ação do líder ou do desativar ministério) e
  `prazo` (date, anulável). Está **aberta** quando `fechada = false` e (`prazo` é nulo ou
  `hoje_sp() <= prazo`). O "fim do dia do prazo" é consequência de comparar datas no fuso de
  America/Sao_Paulo (usa `hoje_sp()` da 003).
- **Justificativa**: nenhuma tarefa agendada; um prazo vencido já vale como fechado na própria
  leitura e na validação da escrita (RF-007). Reabrir com prazo vencido exige novo prazo ou remover o
  prazo (RF-008): a função recusa com `prazo_vencido` se, após aplicar o pedido, o prazo continuar
  vencido.
- **Testabilidade**: os testes substituem `agora_sp()` dentro da transação, como na 003.
- **Alternativas**: coluna `situacao` atualizada por cron. Rejeitada: serviço extra, risco de
  divergência entre a coluna e a realidade (custo zero e YAGNI).

<a id="decisao-3"></a>
## Decisão 3: Unicidade de data por ministério garantida por índice

- **Decisão**: `datas_consulta` repete `ministerio_id` (com chave estrangeira composta
  `(consulta_id, ministerio_id)` para a consulta, de modo que nunca divirja) e tem índice único
  `(ministerio_id, data)`.
- **Justificativa**: RF-005 vale mesmo se dois líderes (ou um líder e um administrador) criarem
  consultas ao mesmo tempo; nenhuma checagem em função resolve corrida sem trava global. A função
  captura a violação do índice e a converte em `data_duplicada`, informando o título da consulta que
  já tem a data (consulta extra de leitura no caminho do erro).
- **Consequência aceita**: datas de consultas fechadas continuam "ocupadas" (a spec as mantém no
  histórico e não permite apagar). Para reaproveitar a data, o líder remove-a da consulta antiga
  (só é possível enquanto aquela consulta estiver aberta; reabra, remova e feche de novo, se preciso).
- **Alternativas**: checar na função com trava do ministério. Rejeitada: mais código e trava mais
  ampla; o índice resolve de forma simples e total.

<a id="decisao-4"></a>
## Decisão 4: Escritas e leituras por funções; sem acesso direto às tabelas

- **Decisão**: as quatro tabelas têm RLS ligada e **nenhum** `select/insert/update/delete` para
  `anon`/`authenticated`. Todo o resto passa por funções `security definer` que validam `auth.uid()`
  por dentro.
- **Justificativa**: a grade mostra nomes (dado de `perfis`), e respostas e observações só podem ser
  vistas pela própria pessoa e por líderes/administradores (ADR 0006, constitution V). Funções
  devolvem exatamente o recorte permitido, sem email. Mesmo padrão provado na 002 e na 003.
- **Alternativas**: RLS por linha + visão para nomes. Rejeitada: RLS não filtra colunas e um erro de
  política vazaria respostas ou observações.

<a id="decisao-5"></a>
## Decisão 5: Travar a consulta em toda alteração

- **Decisão**: toda função que muda a consulta, suas datas ou respostas começa com
  `select … from consultas_disponibilidade where id = … for update`, e só então avalia se está aberta.
- **Justificativa**: "pessoa salva resposta" × "líder fecha a consulta" (e "líder remove data" ×
  "pessoa responde") nunca se atropelam: a segunda ação enxerga o resultado da primeira. Mesma
  técnica da 003 ([decisão 4](../003-escalas-ministerios/research.md#decisao-4)).
- **Alternativas**: sem trava. Rejeitada: uma resposta poderia ser gravada depois do fechamento.

<a id="decisao-6"></a>
## Decisão 6: Confirmação para remover data com respostas, devolvida como dado

- **Decisão**: `remover_data_consulta(p_data, p_confirmado default false)`. Se a data tem respostas e
  `p_confirmado` é falso, devolve `{ "removida": false, "confirmacao_necessaria": true,
  "respostas": N }` **sem gravar**. Com `p_confirmado` verdadeiro, remove a data e (por cascata) as
  respostas, na mesma transação.
- **Justificativa**: mesmo padrão dos avisos de `salvar_vaga` (003, decisão 5): o app mostra o
  diálogo e reenvia com confirmação, sem estado temporário no servidor. A contagem mostrada no
  diálogo considera toda resposta existente (inclusive de quem saiu do ministério), pois todas serão descartadas.
- **Alternativas**: confirmar só no navegador. Rejeitada: o banco é a garantia (constitution III).

<a id="decisao-7"></a>
## Decisão 7: Responder em bloco, com observação, numa única chamada

- **Decisão**: `responder_disponibilidade(p_consulta, p_respostas jsonb, p_observacao text)` recebe
  a lista de `{ data_id, resposta }` (`resposta` nulo = limpar) e a observação, e grava tudo ou nada.
  O mesmo formato serve a `preencher_disponibilidade` (líder), que acrescenta `p_perfil`.
- **Justificativa**: a tela salva "respostas parciais" com um botão; uma chamada atômica evita
  estados intermediários (metade das datas salvas) e reduz idas ao servidor no celular.
- **Datas já passadas**: o participante não altera resposta de data que já passou (`data_encerrada`);
  o líder pode corrigi-la (spec, casos limite). Em lote, uma data inválida recusa o lote inteiro.
- **Alternativas**: uma chamada por data. Rejeitada: mais lenta e permite estados parciais.

<a id="decisao-8"></a>
## Decisão 8: Quem saiu do ministério some por junção, não por exclusão

- **Decisão**: todas as leituras (grade, contagens, avisos, disponibilidade da escala) juntam
  `participacoes_ministerio` e `perfis.situacao = 'aprovado'`. As linhas de resposta não são
  apagadas ao sair.
- **Justificativa**: RF-019 pede que as respostas "deixem de aparecer"; preservá-las faz a volta ao
  ministério restaurar o histórico sem trabalho e evita gatilhos novos sobre a 002.
- **Exclusão de conta**: cascata em `perfis` apaga respostas e observações (LGPD, constitution V).
- **Alternativas**: gatilho que apaga respostas ao sair. Rejeitada: perde dado que pode voltar a
  valer e adiciona gatilho em tabela da 002.

<a id="decisao-9"></a>
## Decisão 9: Contagem por função usa as aptidões da 003

- **Decisão**: para cada data e cada função **ativa** do ministério, a grade conta participantes
  ativos com resposta "disponível" e aptidão (principal ou secundária) naquela função. Quem é apto em
  mais de uma função conta em cada uma. Funções com zero disponíveis vêm marcadas (`faltando`).
- **Justificativa**: é exatamente o "apto" definido na 003 (FR-004); calcular no banco em uma só
  chamada evita montar a conta no navegador a partir de dados que o líder não deveria precisar baixar
  em separado.
- **Sem funções ou aptidões**: o campo vem vazio e a interface mostra "Cadastre as funções e
  aptidões para ver a contagem por função" ao gestor.

<a id="decisao-10"></a>
## Decisão 10: Integração com escalas por avisos novos e leitura própria

- **Decisão**:
  1. `avisos_para_vaga` (003) é redefinida por migração nova e passa a incluir
     `{ "tipo": "sem_disponibilidade", "resposta": "indisponivel" | "sem_resposta" }` quando a data da
     escala pertence a uma consulta do **mesmo ministério** e a pessoa não está "disponível".
     Respeita as mesmas regras de aviso: só dispara quando a pessoa ou a função da vaga muda e a
     pessoa ainda não ocupa outra vaga na escala. Aprovar troca (que já usa `avisos_para_vaga`) herda
     o aviso.
  2. Nova função `disponibilidade_da_escala(p_escala)` (gestor) devolve, por pessoa escalável, a
     resposta na data da escala ou nulo quando a data não está em consulta. A interface usa na
     escolha da pessoa (RF-028) e como indicação permanente ao lado da pessoa escalada (RF-029).
  3. `ler_escala` e `listar_candidatos_escala` **não mudam** (evita recriar funções com assinatura
     de retorno diferente).
- **Justificativa**: o aviso não bloqueia (RF-029), exatamente como os avisos existentes; a leitura
  separada mantém a 003 estável e permite carregar a indicação sem reabrir a escala toda.
- **Consulta fechada ou prazo vencido** continua valendo para a integração: a resposta existente é
  mostrada mesmo com a consulta fechada (a data continua "pertencendo" à consulta).
- **Alternativas**: embutir a resposta dentro de `ler_escala`. Rejeitada: obriga reescrever a função
  grande e seus testes; a leitura separada é mais simples de testar.

<a id="decisao-11"></a>
## Decisão 11: Grade com duas visões, sem biblioteca

- **Decisão**: a grade tem duas apresentações do mesmo dado: **tabela** (pessoa por linha, data por
  coluna, primeira coluna fixa e rolagem horizontal da tabela) e **visão por data** (um cartão por
  data com as pessoas agrupadas em "Disponíveis", "Indisponíveis" e "Sem resposta" e a contagem por
  função). Em telas estreitas a visão por data é a padrão; um botão alterna.
- **Justificativa**: cobre RF-024 e o critério CS-007 (360 px sem rolagem horizontal da página)
  sem dependência nova. A tabela mantém a visão geral no computador.
- **Alternativas**: apenas rolagem horizontal. Rejeitada: a pessoa perde a data ao rolar e o nome
  some sem coluna fixa.

<a id="decisao-12"></a>
## Decisão 12: Escolha de datas com campo nativo e atalho de mês

- **Decisão**: o seletor adiciona datas pelo campo de data nativo (uma a uma) e por um atalho com
  mês (campo de mês) + dia da semana, que gera as datas do mês (sem as anteriores a hoje) numa lista
  editável antes de salvar. A lista mostra data por extenso, campo de rótulo e botão "Remover".
- **Justificativa**: acessível, funciona em celular e dispensa biblioteca de calendário (constitution
  II). A função que gera as datas é pura e testada no Vitest.
- **Limite**: no máximo 31 datas por consulta (validado no banco), para manter a grade legível.
- **Alternativas**: biblioteca de calendário. Rejeitada: peso e manutenção sem necessidade atual.
