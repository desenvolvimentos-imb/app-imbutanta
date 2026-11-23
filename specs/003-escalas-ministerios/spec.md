# Especificação da Funcionalidade: Escalas dos Ministérios

**Branch da Funcionalidade**: `003-escalas-ministerios`

**Criada em**: 2026-11-23

**Status**: Implementada e validada em desenvolvimento em 2026-11-23 (validação manual em celular e PR pendentes)

**Entrada**: Descrição do usuário: "Escalas dos ministérios: o líder monta a escala de cada evento (quem ocupa cada vaga, em qual data e horário); as pessoas escaladas veem a escala, confirmam ou recusam e pedem para ser substituídas por outra pessoa do ministério. Inclui funções e aptidões por ministério, avisos de conflito ao líder, tela Minhas escalas e tela Pedidos de troca."

## Definições

- **Função**: tipo de papel dentro de um ministério (ex.: vocal, violão, bateria, recepção).
- **Vaga**: uma posição dentro de uma escala. Cada vaga é de uma função e é ocupada por no máximo uma pessoa.
- **Escala**: o conjunto de vagas de um ministério para um evento, com data e horário de início.
- **Escalado**: pessoa que ocupa pelo menos uma vaga de uma escala.
- **Líder**: quem lidera o ministério em questão. O administrador pode fazer tudo o que o líder faz, em qualquer ministério.

## Cenários de Usuário e Testes *(obrigatório)*

### História 1 - Líder cadastra as funções e as aptidões do ministério (Prioridade: P1)

O líder (ou um administrador) define as funções do ministério (ex.: vocal, violão) e registra, para cada participante, em quais funções ele é apto, marcando cada uma como "principal" ou "secundária".

**Por que esta prioridade**: sem funções não há vagas, e sem aptidões o app não consegue avisar o líder de que alguém não está apto para uma vaga.

**Teste Independente**: Pode ser testada criando, editando e desativando funções e cadastrando aptidões de um participante, entregando valor sozinha: o ministério passa a ter o catálogo dos seus papéis e quem sabe fazer o quê.

**Cenários de Aceitação**:

1. **Dado** que sou líder do ministério X, **Quando** crio a função "Vocal", **Então** ela aparece na lista de funções ativas de X.
2. **Dado** que X já tem a função ativa "Vocal", **Quando** tento criar ou renomear outra função ativa de X para "vocal" (sem diferenciar maiúsculas de minúsculas), **Então** o app recusa com mensagem clara.
3. **Dado** que X tem uma função desativada "Vocal", **Quando** crio uma nova função "Vocal", **Então** o app permite, pois só não podem coexistir duas ativas com o mesmo nome.
4. **Dado** uma função usada em vagas de escalas passadas e futuras, **Quando** a desativo, **Então** as vagas existentes e as escalas passadas continuam intactas, e a função não pode ser escolhida em novas vagas.
5. **Dado** um participante de X, **Quando** registro que ele é apto em "Vocal" como principal e em "Violão" como secundária, **Então** as duas aptidões ficam registradas e ambas contam como "apto".
6. **Dado** que sou líder de X (e não de Y) ou membro comum, **Quando** tento criar funções ou alterar aptidões de Y, por tela ou por acesso direto, **Então** o app barra a ação.

---

### História 2 - Líder monta e publica a escala de um evento (Prioridade: P1)

O líder cria uma escala informando evento, data, horário de início e observação opcional, adiciona as vagas (função, rótulo opcional e pessoa), recebe avisos de conflito e a publica quando estiver pronta.

**Por que esta prioridade**: é o objetivo central da funcionalidade; sem ela nada mais tem o que mostrar.

**Teste Independente**: Pode ser testada criando uma escala em rascunho, preenchendo vagas, publicando e conferindo que os participantes do ministério a veem.

**Cenários de Aceitação**:

1. **Dado** que sou líder de X, **Quando** crio uma escala com nome do evento, data de hoje ou futura e horário de início, **Então** ela é criada como rascunho, visível só para líderes de X e administradores.
2. **Dado** que estou criando uma escala, **Quando** deixo o nome do evento em branco ou informo data anterior a hoje, **Então** o app recusa com mensagem clara.
3. **Dado** uma escala em rascunho, **Quando** adiciono vagas de funções ativas, com ou sem rótulo (ex.: "Vocal 1"), inclusive várias da mesma função, e escolho pessoas participantes de X, **Então** as vagas ficam registradas com as pessoas escolhidas.
4. **Dado** uma vaga sem pessoa escolhida, **Quando** publico a escala, **Então** a publicação é permitida e a vaga aparece como "em aberto".
5. **Dado** que tento escalar alguém que não participa de X, **Quando** salvo a vaga, **Então** o app recusa.
6. **Dado** uma escala em que a mesma pessoa ocupa "Vocal" e "Violão", **Quando** o app a exibe, **Então** mostra a pessoa uma só vez como escalada, com as duas vagas listadas.
7. **Dado** que escolho para uma vaga uma pessoa que já confirmou presença em escala publicada de outro ministério no mesmo dia, **Quando** salvo, **Então** o app mostra o aviso "participante já escalado em outro ministério neste mesmo dia", com ministério, evento e horário de início da outra escala, e me deixa continuar.
8. **Dado** que a pessoa só está em outra vaga da mesma escala, ou em outra escala do mesmo ministério no mesmo dia, **Quando** salvo, **Então** o app não mostra esse aviso.
9. **Dado** que escolho uma pessoa que não é apta para a função da vaga, **Quando** salvo, **Então** o app mostra o aviso de falta de aptidão e me deixa continuar.
10. **Dado** que sou líder de Y (não de X) ou membro comum, **Quando** tento criar ou editar uma escala de X, por tela ou por acesso direto, **Então** o app barra a ação.
11. **Dado** uma escala publicada, **Quando** o líder a cancela, **Então** ela não é apagada: continua visível para quem estava escalado, marcada como cancelada.

---

### História 3 - Pessoa escalada vê, confirma ou recusa (Prioridade: P1)

Cada pessoa tem a tela "Minhas escalas" com as escalas publicadas em que está escalada e, nelas, confirma ou recusa a participação, com motivo opcional na recusa.

**Por que esta prioridade**: é o que torna a escala útil para quem serve e dá ao líder a informação de que precisa para se organizar.

**Teste Independente**: Pode ser testada publicando uma escala com uma pessoa e conferindo que ela a vê em "Minhas escalas" e consegue confirmar e recusar.

**Cenários de Aceitação**:

1. **Dado** que estou escalado em escalas publicadas, **Quando** abro "Minhas escalas", **Então** vejo as próximas em ordem de data, com acesso às passadas, e cada item mostra ministério, evento, função (ou funções), data, horário e a situação da minha resposta.
2. **Dado** que acabei de ser escalado, **Quando** abro a escala, **Então** minha resposta está "pendente".
3. **Dado** uma escala publicada em que estou escalado, **Quando** confirmo, **Então** minha resposta passa a "confirmado" para todas as minhas vagas nessa escala.
4. **Dado** que estou escalado, **Quando** recuso informando um motivo (ou sem motivo), **Então** minha resposta passa a "recusado", e as minhas vagas continuam comigo, mas aparecem destacadas para o líder.
5. **Dado** que já respondi, **Quando** mudo a resposta antes do horário de início do evento, **Então** a nova resposta vale; **Quando** tento mudá-la depois do horário de início, **Então** o app impede.
6. **Dado** uma escala em rascunho em que estou escalado, **Quando** abro "Minhas escalas", **Então** ela não aparece.
7. **Dado** uma escala cancelada em que eu estava escalado, **Quando** abro "Minhas escalas", **Então** ela aparece marcada como cancelada e não permite responder.

---

### História 4 - Líder acompanha respostas e reorganiza a escala (Prioridade: P1)

O líder vê todas as escalas do ministério, inclusive rascunhos, com as respostas e os motivos de recusa, e troca pessoas das vagas quando precisa.

**Por que esta prioridade**: sem enxergar recusas e pendências, o líder não consegue garantir que o evento terá todas as vagas ocupadas.

**Teste Independente**: Pode ser testada com uma escala publicada com respostas variadas, conferindo os destaques e trocando a pessoa de uma vaga recusada.

**Cenários de Aceitação**:

1. **Dado** uma escala com vagas confirmadas, pendentes, recusadas e em aberto, **Quando** o líder a abre, **Então** vê a resposta de cada escalado e os motivos de recusa, e as vagas recusadas, sem resposta (pendentes) ou em aberto aparecem em destaque.
2. **Dado** uma escala publicada, **Quando** o líder troca a pessoa de uma vaga, **Então** a nova pessoa fica com resposta "pendente" e a anterior deixa de estar escalada nessa vaga (e na escala, se não tiver outras vagas).
3. **Dado** uma escala publicada, **Quando** o líder muda a data ou o horário, **Então** todas as respostas voltam para "pendente" e os pedidos de troca pendentes são cancelados.
4. **Dado** uma escala cuja data já passou (a partir do dia seguinte), **Quando** qualquer pessoa tenta alterá-la, **Então** o app impede: ela fica somente para leitura.
5. **Dado** uma pessoa removida do ministério X, **Quando** a remoção é feita, **Então** as vagas futuras dela em X passam a "em aberto" e o líder é avisado ao abrir o ministério ou as escalas afetadas.

---

### História 5 - Pessoa escalada pede troca e o fluxo é decidido (Prioridade: P2)

Uma pessoa escalada que não poderá comparecer pede que outra participante do ministério assuma uma de suas vagas. A pessoa indicada aceita ou recusa; se aceitar, o líder aprova ou recusa. Só depois da aprovação a vaga muda de mãos.

**Por que esta prioridade**: resolve o problema real de imprevistos sem depender de mensagens soltas, mas a escala já tem valor sem ele.

**Teste Independente**: Pode ser testada com duas pessoas e um líder: pedido, aceite, aprovação e conferência de que a vaga mudou e a resposta do novo ocupante é "confirmado".

**Cenários de Aceitação**:

1. **Dado** que estou escalado em escala publicada cujo horário de início ainda não passou, **Quando** peço troca de uma das minhas vagas indicando uma participante do mesmo ministério que ainda não está escalada nessa escala, **Então** o pedido é criado como pendente e nada muda na escala.
2. **Dado** um pedido pendente, **Quando** a pessoa indicada aceita, **Então** o pedido passa a aguardar a decisão do líder; **Quando** ela recusa, **Então** o pedido é encerrado e a vaga continua com quem pediu.
3. **Dado** um pedido aceito pela indicada, **Quando** o líder (ou um administrador) aprova, **Então** a vaga passa para a indicada com resposta "confirmado" e quem pediu deixa de ocupá-la; se quem pediu tem outras vagas nessa escala, elas permanecem com ela.
4. **Dado** um pedido aceito, **Quando** o líder recusa, **Então** nada muda na escala e o pedido é encerrado.
5. **Dado** um pedido ainda não aprovado, **Quando** quem pediu ou o líder o cancela, **Então** o pedido é encerrado e nada muda.
6. **Dado** uma vaga com pedido pendente, **Quando** alguém tenta criar outro pedido para a mesma vaga, **Então** o app impede.
7. **Dado** um pedido pendente, **Quando** a escala é cancelada, o horário de início passa ou o líder troca a pessoa dessa vaga, **Então** o pedido perde efeito automaticamente.
8. **Dado** que o líder vai aprovar um pedido, **Quando** a indicada não é apta para a função ou já confirmou escala publicada de outro ministério no mesmo dia, **Então** o app mostra o aviso correspondente e o líder decide se aprova.
9. **Dado** uma aprovação em andamento, **Quando** ocorre qualquer falha, **Então** a vaga fica exatamente como estava (a troca é tudo ou nada).
10. **Dado** que abro "Pedidos de troca", **Quando** a tela carrega, **Então** vejo os pedidos que fiz e os que recebi; como líder, vejo também os pedidos aguardando a minha aprovação.

---

### História 6 - Visibilidade por papel e efeitos em ministérios (Prioridade: P2)

Participantes veem as escalas publicadas do seu ministério (sem as respostas dos outros); administradores veem tudo; quem não participa não vê nada. Remover alguém de um ministério ou desativar um ministério reflete nas escalas futuras.

**Por que esta prioridade**: garante privacidade e consistência, mas depende das histórias anteriores.

**Teste Independente**: Pode ser testada com um participante, um não participante, um líder e um administrador olhando a mesma escala.

**Cenários de Aceitação**:

1. **Dado** que participo de X, **Quando** abro as escalas de X, **Então** vejo as publicadas, com o nome de quem ocupa cada vaga (ou "em aberto"), sem respostas nem motivos de recusa dos outros; vejo apenas a minha própria resposta.
2. **Dado** que não participo de X, **Quando** tento ver escalas de X, por tela ou por acesso direto, **Então** o app não mostra nada.
3. **Dado** que sou administrador, **Quando** abro qualquer ministério, **Então** vejo todas as escalas, inclusive rascunhos, com respostas e motivos.
4. **Dado** que sou administrador e vou desativar um ministério com escalas futuras, **Quando** peço a desativação, **Então** o app informa quantas escalas futuras serão canceladas e só desativa após minha confirmação; ao confirmar, essas escalas ficam canceladas.

---

### Casos de Borda

- Escala criada para hoje com horário de início já passado: permitida (a data não é anterior a hoje), mas nesse caso as respostas e os pedidos de troca já estão encerrados, pois o horário de início passou.
- Escala cuja data é hoje: continua editável pelo líder até o fim do dia; a partir do dia seguinte fica somente para leitura.
- Pessoa escalada que perde o acesso ao app (conta removida ou recusada): deixa de aparecer nas listas, e as vagas futuras dela ficam "em aberto".
- Líder que também está escalado na própria escala: age como líder e como escalado, sem restrições entre os dois papéis.
- Pessoa indicada para troca que passa a ser escalada na mesma escala (pelo líder) antes de aceitar: o pedido perde a validade ao tentar aceitar, e o app explica.
- Duas pessoas pedindo troca de vagas diferentes para a mesma indicada: ambos os pedidos podem existir; quando um for aprovado, o outro perde a validade, pois a indicada já estará escalada.
- Líder troca a pessoa de uma vaga enquanto outra aprova um pedido sobre ela ao mesmo tempo: só uma das ações prevalece, e a outra recebe aviso de que a escala mudou.
- Aprovação ou recusa de pedido já decidido, cancelado ou sem efeito: o app informa que o pedido não está mais pendente.
- Função desativada em vaga já existente: a vaga continua válida e visível; só não pode ser escolhida em vagas novas.
- Remover uma vaga que tem pessoa, resposta ou pedido pendente: permitido ao líder em escala editável; a resposta continua válida só se a pessoa ainda ocupar outra vaga, e o pedido pendente da vaga removida é cancelado.
- Escala sem nenhuma vaga: pode existir como rascunho, mas não pode ser publicada.
- Pessoa com a resposta "recusado" e que é trocada pelo líder: deixa de estar escalada, e a resposta some junto com a vaga.

## Requisitos *(obrigatório)*

### Requisitos Funcionais

**Funções e aptidões**

- **FR-001**: O líder do ministério, ou um administrador, MUST poder criar, editar e desativar as funções desse ministério; nenhuma outra pessoa MUST poder fazê-lo.
- **FR-002**: O app MUST impedir duas funções ativas com o mesmo nome no mesmo ministério, sem diferenciar maiúsculas de minúsculas; funções de ministérios diferentes e funções desativadas não conflitam.
- **FR-003**: Desativar uma função MUST NOT apagar nem alterar escalas passadas ou vagas já existentes, mas a função MUST deixar de poder ser escolhida em novas vagas.
- **FR-004**: O líder MUST poder cadastrar e alterar, para cada participante do ministério, a lista de funções em que é apto, marcando cada uma como "principal" ou "secundária". Ambas MUST contar como "apto" nesta funcionalidade.

**Escalas**

- **FR-005**: Uma escala MUST ter ministério, nome do evento (obrigatório), data, horário de início e observação opcional.
- **FR-006**: Somente o líder do ministério, ou um administrador, MUST poder criar, editar e cancelar escalas desse ministério.
- **FR-007**: O app MUST recusar a criação de escala com data anterior a hoje. A partir do dia seguinte à data da escala, ela MUST ficar somente para leitura, e ninguém MUST poder alterá-la.
- **FR-008**: O líder MUST poder adicionar e remover vagas, escolher a função de cada uma entre as funções ativas do ministério, dar um rótulo opcional e escolher a pessoa. Pode haver várias vagas da mesma função, e uma vaga MAY ficar sem pessoa ("em aberto").
- **FR-009**: Cada vaga MUST ser ocupada por no máximo uma pessoa, e somente participantes do ministério MUST poder ser escalados.
- **FR-010**: A mesma pessoa MAY ocupar mais de uma vaga na mesma escala; isso MUST contar como uma única participação, e o app MUST mostrar todas as vagas dessa pessoa.
- **FR-011**: A escala MUST ter as situações "rascunho", "publicada" e "cancelada". Uma escala sem vagas MUST NOT poder ser publicada; uma escala publicada MAY ter vagas em aberto.
- **FR-012**: Rascunho MUST ser visível apenas para o líder do ministério e administradores. Publicada MUST ser visível para os participantes do ministério. Cancelada MUST NOT ser apagada e MUST continuar visível para quem estava escalado, marcada como cancelada.
- **FR-013**: Ao cancelar uma escala, as respostas e os pedidos de troca pendentes MUST perder efeito.
- **FR-014**: Quando o líder trocar a pessoa de uma vaga de escala publicada, a nova pessoa MUST ficar com resposta "pendente" e a anterior MUST deixar de estar escalada nessa vaga.
- **FR-015**: Quando a data ou o horário de uma escala publicada mudar, todas as respostas MUST voltar para "pendente" e os pedidos de troca pendentes MUST ser cancelados.
- **FR-016**: Os escalados MUST ver sempre a versão atual da escala ao abrir o app; o app MUST NOT depender de notificações.

**Avisos ao líder**

- **FR-017**: Ao escalar uma pessoa que já está escalada em outra escala de **outro** ministério no mesmo dia, **e que esteja publicada e com a resposta dela "confirmado"**, o app MUST mostrar o aviso "participante já escalado em outro ministério neste mesmo dia", com ministério, evento e horário de início da outra escala, e MUST permitir continuar. O horário MUST NOT ser comparado. Ocupar duas vagas na mesma escala, ou estar em duas escalas do mesmo ministério, MUST NOT gerar o aviso. Escalas em rascunho e canceladas MUST NOT entrar nessa verificação.
- **FR-018**: Ao escalar uma pessoa que não é apta para a função da vaga, o app MUST mostrar o aviso de falta de aptidão e MUST permitir continuar.
- **FR-019**: Quando uma pessoa for removida de um ministério, as vagas futuras dela nesse ministério MUST passar a "em aberto" e o líder MUST ser avisado.
- **FR-020**: Ao desativar um ministério, suas escalas futuras MUST ser canceladas; antes de confirmar, o app MUST informar ao administrador quantas escalas serão canceladas. (Ajuste da funcionalidade 002.)

**Visualização**

- **FR-021**: Cada pessoa MUST ter a tela "Minhas escalas" com as escalas publicadas (e as canceladas em que estava escalada) em que está escalada, mostrando as próximas em ordem de data e dando acesso às passadas. Cada item MUST mostrar ministério, evento, função, data, horário e a situação da resposta da pessoa.
- **FR-022**: O participante de um ministério MUST ver as escalas publicadas desse ministério, com o nome de quem ocupa cada vaga, sem ver as respostas nem os motivos de recusa dos outros.
- **FR-023**: O líder MUST ver todas as escalas do seu ministério, inclusive rascunhos, com respostas e motivos de recusa; vagas recusadas, sem resposta ou em aberto MUST aparecer em destaque.
- **FR-024**: O administrador MUST ver todas as escalas de todos os ministérios. Quem não participa de um ministério MUST NOT ver as escalas dele.
- **FR-025**: As regras de visibilidade e de permissão MUST ser aplicadas no servidor/banco, não só na interface.

**Confirmação e recusa**

- **FR-026**: Quem está escalado em escala publicada MUST poder confirmar ou recusar. A resposta MUST ser única por pessoa por escala e valer para todas as vagas dela nessa escala; a recusa MAY ter motivo opcional.
- **FR-027**: As respostas possíveis MUST ser "pendente" (padrão), "confirmado" e "recusado"; a pessoa MUST poder mudar a resposta até o horário de início do evento, e não depois.
- **FR-028**: Uma vaga recusada MUST continuar com a pessoa até o líder reorganizar a escala, e MUST aparecer destacada para o líder.

**Pedidos de troca**

- **FR-029**: Uma pessoa escalada MUST poder pedir troca de uma de suas vagas em escala publicada cujo horário de início ainda não passou, indicando outra participante do mesmo ministério que ainda não esteja escalada nessa escala. Troca de funções entre duas pessoas já escaladas está fora do escopo.
- **FR-030**: O fluxo MUST seguir três passos: (1) a pessoa indicada aceita ou recusa; (2) se aceitar, o líder (ou um administrador) aprova ou recusa; (3) só após a aprovação a vaga passa para a indicada, com resposta "confirmado", e quem pediu deixa de ocupá-la. Outras vagas de quem pediu na mesma escala MUST permanecer com ela.
- **FR-031**: Enquanto o pedido estiver pendente, nada MUST mudar na escala. Quem pediu e o líder MUST poder cancelar o pedido a qualquer momento antes da aprovação.
- **FR-032**: O pedido MUST perder efeito automaticamente se a escala for cancelada, se o horário de início passar ou se o líder trocar a pessoa dessa vaga.
- **FR-033**: Cada vaga MUST ter no máximo um pedido de troca pendente por vez.
- **FR-034**: Ao aprovar, o app MUST avisar o líder se a pessoa indicada não é apta para a função ou já confirmou escala publicada de outro ministério no mesmo dia, e o líder decide.
- **FR-035**: A aprovação da troca MUST ser atômica: ou a vaga muda por completo ou nada muda.
- **FR-036**: Cada pessoa MUST ter a tela "Pedidos de troca" com os pedidos que fez e os que recebeu; o líder MUST ver também os pedidos aguardando a sua aprovação.

**Geral**

- **FR-037**: Todas as telas MUST ser em português do Brasil, mobile-first e acessíveis, com datas e horários no formato brasileiro e fuso America/Sao_Paulo, e os erros MUST ser exibidos em mensagens compreensíveis.
- **FR-038**: O app MUST NOT coletar dados novos além dos descritos aqui (nome do evento, data, horário, observação, rótulos, respostas, motivos de recusa e pedidos de troca).

### Entidades-Chave *(incluir se a funcionalidade envolver dados)*

- **Função**: papel dentro de um ministério (nome, ativa ou desativada); pertence a um ministério.
- **Aptidão**: ligação entre um participante e uma função do ministério, com o tipo "principal" ou "secundária".
- **Escala**: evento de um ministério com nome, data, horário de início, observação e situação (rascunho, publicada, cancelada).
- **Vaga**: posição de uma escala, com função, rótulo opcional e pessoa (ou em aberto).
- **Resposta**: resposta de uma pessoa a uma escala (pendente, confirmado, recusado) com motivo opcional; uma por pessoa por escala.
- **Pedido de troca**: pedido de quem ocupa uma vaga para que outra pessoa a assuma; guarda quem pediu, a indicada, a vaga, a situação (aguardando a indicada, aguardando o líder, aprovado, recusado pela indicada, recusado pelo líder, cancelado, sem efeito) e quem decidiu e quando.
- **Participante / Ministério / Líder**: já existentes (funcionalidade 002); usados para decidir quem pode ser escalado e quem gerencia.

## Critérios de Sucesso *(obrigatório)*

### Resultados Mensuráveis

- **SC-001**: Um líder consegue criar uma escala com 6 vagas preenchidas e publicá-la em menos de 5 minutos, em celular, sem ajuda.
- **SC-002**: Uma pessoa escalada vê a escala e responde (confirma ou recusa) em no máximo 3 toques a partir da tela inicial.
- **SC-003**: 100% das tentativas de pessoas sem permissão de ver ou alterar escalas (não participante, participante tentando editar, líder de outro ministério) são barradas, inclusive por acesso direto.
- **SC-004**: 100% das aprovações de troca resultam em estado consistente: a vaga está totalmente com a nova pessoa ou totalmente como antes, nunca em estado intermediário, inclusive com ações simultâneas.
- **SC-005**: O líder identifica em uma única tela, em até 10 segundos, quais vagas de uma escala estão recusadas, sem resposta ou em aberto.
- **SC-006**: Pelo menos 90% das pessoas escaladas em escalas de teste conseguem confirmar, recusar e pedir troca na primeira tentativa, sem instruções.
- **SC-007**: Todas as regras de datas, avisos de conflito, visibilidade e fluxo de troca têm testes automatizados que passam antes do merge.
- **SC-008**: Após a mudança de pessoa, data ou horário por um líder, o escalado vê a versão atualizada na próxima vez que abre o app, sem nenhuma ação manual.

## Premissas

- O público é o mesmo das funcionalidades 001 e 002: membresia da Igreja Metodista no Butantã, principalmente em celular, com internet.
- As funcionalidades 001 (login, papéis e acesso) e 002 (ministérios e participantes) estão entregues; esta usa a participação e a liderança por ministério da 002 e a ajusta apenas nos pontos indicados (remoção de participante e desativação de ministério).
- "Hoje", "dia seguinte" e "horário de início" são avaliados no fuso America/Sao_Paulo.
- A escala tem um único horário (o de início); duração e horário de término ficam fora do escopo.
- "Participante do ministério" inclui o líder dele: o líder pode ser escalado e pode pedir troca como qualquer outro.
- O aviso de conflito considera apenas escalas publicadas, de outros ministérios, no mesmo dia; apenas escalas publicadas em que a pessoa já **confirmou** contam; rascunhos, escalas canceladas e respostas pendentes ou recusadas não geram aviso (decisão do dono do produto).
- O aviso de aptidão e o de conflito nunca bloqueiam: o líder sempre pode continuar. Pessoa sem nenhuma aptidão cadastrada é considerada não apta para qualquer função.
- A confirmação de um pedido de troca aprovado faz a indicada ficar "confirmado" mesmo que o líder tenha continuado após os avisos; nada impede o líder de reorganizar depois.
- Pedidos de troca encerrados (recusados, cancelados, sem efeito ou aprovados) ficam registrados para consulta em "Pedidos de troca", sem prazo de expiração definido nesta funcionalidade.
- Não há limite de número de escalas por ministério nem de vagas por escala; o porte esperado é pequeno (dezenas de vagas por escala, poucas escalas por semana). Uma salvaguarda técnica razoável de 50 vagas por escala será definida no plano.
- Quando uma conta perde o acesso ao app, as vagas futuras dela em todos os ministérios passam a "em aberto", como na remoção de um ministério.
- Escalas passadas guardam quem ocupou cada vaga e as respostas, mesmo se a pessoa sair do ministério depois; só as vagas futuras mudam.
- Fora do escopo: regras específicas de cada ministério, coleta de disponibilidade, geração automática de escalas, notificações por email ou push, troca de funções entre duas pessoas já escaladas, diferença de peso entre aptidão principal e secundária, escalas recorrentes e pessoas sem conta no app.
- Dependências: usa o serviço de autenticação, os papéis e a tela inicial da funcionalidade 001 e os ministérios, participantes e líderes da 002; custo zero conforme a constitution.
