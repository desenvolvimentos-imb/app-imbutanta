# Especificação da Funcionalidade: Disponibilidade dos Participantes dos Ministérios

**Branch da Funcionalidade**: `004-disponibilidade-participantes`

**Criada em**: 2026-11-24

**Status**: Rascunho

**Entrada**: Descrição do usuário: "Disponibilidade dos participantes dos ministérios: o líder de um ministério pede aos participantes que informem em quais datas podem ser escalados e acompanha as respostas em uma só tela. Substitui o formulário externo que a igreja usa hoje. Serve a qualquer ministério."

## Objetivo

Permitir que o líder de um ministério peça aos participantes que informem em quais datas podem ser escalados e acompanhe as respostas em uma só tela. A funcionalidade substitui o formulário externo usado hoje pela igreja e serve a qualquer ministério. A geração automática de escalas e as regras específicas de cada ministério são funcionalidades futuras.

## Definições

- **Consulta de disponibilidade** (ou "consulta"): pedido do líder para que os participantes de um ministério informem em quais datas podem ser escalados. Cada consulta pertence a um único ministério.
- **Data da consulta**: uma das datas propostas pelo líder na consulta.
- **Resposta**: a situação de uma pessoa em uma data da consulta: "disponível", "indisponível" ou "sem resposta" (padrão enquanto a pessoa não marcar nada). "Sem resposta" nunca é tratado como "indisponível".
- **Líder**: quem lidera o ministério em questão. O administrador pode fazer tudo o que o líder faz, em qualquer ministério.
- **Função e aptidão**: conceitos já existentes na funcionalidade de escalas (003): a função é o papel dentro do ministério e a aptidão registra em quais funções cada participante é apto.

## Cenários de Usuário e Testes *(obrigatório)*

### História 1 - Líder cria e gerencia uma consulta (Prioridade: P1)

O líder (ou um administrador) cria uma consulta com título, datas, prazo e mensagem opcionais, e a mantém: altera, fecha, reabre e consulta o histórico.

**Por que esta prioridade**: sem a consulta não há o que responder nem acompanhar.

**Teste Independente**: Pode ser testada criando uma consulta com várias datas, editando-a, fechando e reabrindo, sem nenhuma resposta ainda; já entrega valor ao organizar o pedido de disponibilidade em um só lugar.

**Cenários de Aceitação**:

1. **Dado** que sou líder do ministério X, **Quando** crio uma consulta com título "Escala de dezembro" e pelo menos uma data de hoje ou futura, **Então** ela é criada "aberta" e aparece na lista de consultas de X.
2. **Dado** que estou criando uma consulta, **Quando** deixo o título em branco, não informo nenhuma data ou informo uma data anterior a hoje, **Então** o app recusa com mensagem clara.
3. **Dado** que estou escolhendo datas, **Quando** uso o atalho "todos os domingos de dezembro" (um dia da semana em um mês), **Então** todas as datas daquele dia da semana naquele mês (que não sejam anteriores a hoje) são adicionadas, e posso ajustar a lista antes de salvar.
4. **Dado** uma data adicionada, **Quando** informo um rótulo (ex.: "Culto especial"), **Então** o rótulo aparece junto da data para líderes e participantes.
5. **Dado** que a data 14/12 já está em outra consulta de X, **Quando** tento incluí-la em uma consulta de X, **Então** o app recusa e indica em qual consulta ela já está; **Quando** a incluo em consulta de outro ministério, **Então** o app permite.
6. **Dado** uma consulta aberta, **Quando** altero título, mensagem ou prazo, **Então** as alterações são salvas.
7. **Dado** uma consulta aberta, **Quando** adiciono uma data, **Então** ela começa "sem resposta" para todos os participantes.
8. **Dado** uma consulta aberta com uma data que já tem respostas, **Quando** removo essa data, **Então** o app pede confirmação avisando que as respostas serão descartadas, e só remove após eu confirmar.
9. **Dado** uma consulta aberta, **Quando** a fecho, **Então** ela passa a "fechada" e os participantes deixam de poder respondê-la; **Quando** a reabro, **Então** volta a "aberta".
10. **Dado** uma consulta fechada, **Quando** a abro para edição, **Então** a única ação disponível é reabri-la.
11. **Dado** uma consulta com prazo, **Quando** termina o dia do prazo, **Então** ela passa a valer como fechada.
12. **Dado** uma consulta fechada por prazo vencido, **Quando** tento reabri-la sem alterar o prazo, **Então** o app exige que eu informe um novo prazo ou remova o prazo.
13. **Dado** uma consulta, **Quando** tento apagá-la, **Então** o app não oferece essa ação; as fechadas permanecem no histórico do ministério.
14. **Dado** que sou líder de Y (não de X) ou membro comum, **Quando** tento criar ou alterar consultas de X, por tela ou por acesso direto, **Então** o app barra a ação.
15. **Dado** que um ministério é desativado, **Quando** ele tinha consultas abertas, **Então** elas passam a fechadas.

---

### História 2 - Participante responde a uma consulta (Prioridade: P1)

Cada participante vê, na tela "Disponibilidade", as consultas abertas dos seus ministérios e marca, para cada data, "disponível" ou "indisponível", podendo deixar uma observação.

**Por que esta prioridade**: é a informação que a funcionalidade existe para coletar.

**Teste Independente**: Pode ser testada com uma consulta aberta e um participante que responde, salva parcialmente, altera e deixa observação.

**Cenários de Aceitação**:

1. **Dado** que participo ativamente de X e existe uma consulta aberta de X, **Quando** abro "Disponibilidade", **Então** vejo essa consulta com título, mensagem, prazo (se houver) e as datas com seus rótulos.
2. **Dado** que existe consulta aberta de X com datas ainda sem resposta minha, **Quando** abro a tela inicial, **Então** ela indica que há consulta aguardando minha resposta; **Quando** respondo todas as datas (ou não há consulta aberta), **Então** a indicação não aparece.
3. **Dado** uma consulta aberta, **Quando** marco "disponível" em algumas datas, "indisponível" em outras e salvo, **Então** as respostas ficam registradas e as datas não marcadas continuam "sem resposta".
4. **Dado** que já respondi, **Quando** altero minhas respostas enquanto a consulta está aberta, **Então** as novas respostas valem.
5. **Dado** uma consulta aberta, **Quando** escrevo uma observação de até 300 caracteres, **Então** ela é salva; **Quando** escrevo mais de 300 caracteres, **Então** o app recusa com mensagem clara.
6. **Dado** uma consulta fechada (por ação do líder ou por prazo vencido), **Quando** a abro, **Então** vejo minhas respostas sem poder alterá-las.
7. **Dado** que passei a participar de X depois da abertura de uma consulta aberta, **Quando** abro "Disponibilidade", **Então** posso respondê-la normalmente.
8. **Dado** que não participo (ou deixei de participar) de X, **Quando** tento ver ou responder consultas de X, por tela ou por acesso direto, **Então** o app barra a ação.
9. **Dado** outro participante de X, **Quando** tento ver as respostas ou a observação dele, **Então** o app barra a ação: cada pessoa vê somente as próprias respostas.

---

### História 3 - Líder acompanha as respostas em uma grade (Prioridade: P1)

O líder vê, para cada consulta do ministério, uma grade com um participante por linha, uma data por coluna e a resposta em cada célula, mais as observações, os totais e os destaques.

**Por que esta prioridade**: reunir as respostas em uma só tela é o ganho central em relação ao formulário externo.

**Teste Independente**: Pode ser testada com uma consulta com respostas variadas, conferindo células, totais, destaques, observações e o uso no celular.

**Cenários de Aceitação**:

1. **Dado** uma consulta de X com respostas, **Quando** o líder a abre, **Então** vê a grade com cada participante ativo em uma linha, cada data em uma coluna e, em cada célula, "disponível", "indisponível" ou "sem resposta" distinguíveis entre si sem depender só da cor.
2. **Dado** a grade, **Quando** o líder a observa, **Então** cada data mostra quantos participantes estão disponíveis.
3. **Dado** participantes que não marcaram nenhuma data, **Quando** o líder vê a grade, **Então** essas pessoas aparecem destacadas como "ainda não responderam".
4. **Dado** participantes com observação, **Quando** o líder vê a grade, **Então** as observações aparecem junto de cada pessoa.
5. **Dado** que a consulta e as funções do ministério têm aptidões cadastradas, **Quando** o líder vê uma data, **Então** vê quantos disponíveis há por função, e uma função com zero disponíveis fica visivelmente destacada.
6. **Dado** que uso o app no celular, **Quando** abro a grade, **Então** consigo ler e usar todas as informações (por rolagem horizontal com a coluna do nome fixa ou por visão alternativa organizada por data), sem precisar ampliar a tela.
7. **Dado** uma pessoa que deixou o ministério, **Quando** o líder vê a grade, **Então** as respostas dela não aparecem e não entram nas contagens.
8. **Dado** que sou administrador, **Quando** abro as consultas, **Então** vejo as de todos os ministérios; **Quando** sou líder de X, vejo apenas as de X.
9. **Dado** que sou membro comum sem liderança no ministério, **Quando** tento abrir a grade de X, por tela ou por acesso direto, **Então** o app barra a ação.

---

### História 4 - Líder preenche ou corrige a resposta de um participante (Prioridade: P2)

O líder (ou um administrador) registra ou corrige a resposta de qualquer participante, inclusive com a consulta fechada, para os casos em que a pessoa respondeu por outro meio.

**Por que esta prioridade**: cobre a transição e quem não usa o app, mas a funcionalidade já funciona sem ela.

**Teste Independente**: Pode ser testada preenchendo as respostas de um participante que não respondeu e corrigindo as de outro, em consultas abertas e fechadas.

**Cenários de Aceitação**:

1. **Dado** uma consulta de X, aberta ou fechada, **Quando** o líder preenche ou corrige a resposta de um participante em uma data, **Então** a nova resposta vale e o app indica ao líder que ela foi preenchida por ele.
2. **Dado** uma resposta preenchida pelo líder, **Quando** o próprio participante a altera (consulta aberta), **Então** a resposta passa a ser dele e a indicação de preenchimento pelo líder deixa de aparecer.
3. **Dado** que sou líder de Y (não de X) ou membro comum, **Quando** tento preencher a resposta de alguém em consulta de X, **Então** o app barra a ação.
4. **Dado** uma pessoa que não é participante ativa de X, **Quando** o líder tenta preencher resposta dela, **Então** o app recusa.

---

### História 5 - Disponibilidade visível ao montar a escala (Prioridade: P2)

Ao escolher uma pessoa para uma vaga de uma escala, o líder vê a resposta dela para a data da escala e recebe um aviso quando ela não está disponível.

**Por que esta prioridade**: fecha o ciclo com a funcionalidade de escalas (003), evitando escalar quem disse que não pode.

**Teste Independente**: Pode ser testada com uma consulta contendo a data de uma escala e pessoas com respostas diferentes.

**Cenários de Aceitação**:

1. **Dado** que a data da escala faz parte de uma consulta do mesmo ministério, **Quando** escolho uma pessoa para uma vaga, **Então** o app mostra a resposta dela nessa data.
2. **Dado** que a resposta é "indisponível" ou "sem resposta", **Quando** salvo a vaga, **Então** o app avisa que a pessoa não confirmou disponibilidade e me deixa continuar.
3. **Dado** uma pessoa escalada com resposta "indisponível" ou "sem resposta", **Quando** vejo a escala, **Então** a indicação continua visível ao lado dela, apenas para líderes e administradores.
4. **Dado** que a data da escala não pertence a nenhuma consulta do ministério, **Quando** escolho uma pessoa, **Então** nenhuma indicação de disponibilidade é mostrada.
5. **Dado** uma consulta de outro ministério com a mesma data, **Quando** escolho uma pessoa para a escala de X, **Então** essa consulta não é considerada.

---

### Casos Limite

- Líder remove todas as datas de uma consulta aberta: o app recusa, pois toda consulta mantém ao menos uma data.
- Prazo anterior a hoje ao criar a consulta: o app recusa; prazo igual a hoje é válido e fecha a consulta ao fim do dia.
- Data da consulta que já passou: deixa de aceitar respostas dos participantes, mas o líder ainda pode corrigi-la (História 4) e ela permanece na grade como histórico.
- Pessoa deixa o ministério e volta: as respostas anteriores voltam a aparecer, pois não foram descartadas, apenas ocultadas.
- Participante responde ao mesmo tempo em que o líder fecha a consulta: respostas enviadas depois do fechamento são recusadas com mensagem clara, sem perder as já salvas.
- Líder e participante alteram a mesma resposta quase ao mesmo tempo: vale a última gravada, sem erro nem duplicidade.
- Consulta em que todos os participantes responderam "indisponível" em uma data: a data aparece com zero disponíveis e o destaque por função.
- Ministério sem funções ou sem aptidões cadastradas: a grade funciona normalmente e a contagem por função fica ausente ou indica que não há aptidões cadastradas.
- Ministério desativado: suas consultas ficam fechadas e visíveis no histórico; ele não recebe novas consultas.
- Remoção de uma data que está em escala existente: a escala não é afetada; ela apenas deixa de mostrar a indicação de disponibilidade.
- Participantes sem nenhuma consulta aberta: a tela "Disponibilidade" mostra estado vazio claro, sem erro.

## Requisitos *(obrigatório)*

### Requisitos Funcionais

**Consultas**

- **RF-001**: O sistema DEVE permitir que líderes do ministério e administradores criem consultas com título obrigatório, pelo menos uma data, prazo opcional e mensagem opcional.
- **RF-002**: O sistema DEVE permitir escolher datas uma a uma em um calendário e também por um atalho que adiciona todos os dias de um mesmo dia da semana em um mês escolhido.
- **RF-003**: O sistema DEVE permitir um rótulo opcional por data da consulta.
- **RF-004**: O sistema DEVE recusar datas anteriores a hoje (ao criar a consulta ou ao adicionar datas) e prazos anteriores a hoje.
- **RF-005**: O sistema DEVE impedir que uma mesma data esteja em duas consultas do mesmo ministério, informando em qual consulta ela já está, e DEVE permitir a mesma data em consultas de ministérios diferentes.
- **RF-006**: O sistema DEVE criar toda consulta como "aberta" e permitir ao líder fechá-la e reabri-la a qualquer momento.
- **RF-007**: O sistema DEVE tratar como fechada a consulta cujo prazo terminou, ao fim do dia do prazo (no fuso de Brasília), sem depender de ação do líder.
- **RF-008**: O sistema DEVE exigir, para reabrir uma consulta com prazo vencido, que o líder informe um novo prazo ou remova o prazo.
- **RF-009**: Em consulta aberta, o sistema DEVE permitir alterar título, mensagem e prazo, adicionar datas (iniciando "sem resposta" para todos) e remover datas, mantendo sempre ao menos uma data.
- **RF-010**: Ao remover uma data que já tem respostas, o sistema DEVE pedir confirmação explícita e, confirmada a remoção, descartar as respostas dessa data.
- **RF-011**: Em consulta fechada, o sistema DEVE permitir apenas reabri-la (e o preenchimento de respostas pelo líder, conforme RF-021).
- **RF-012**: O sistema NÃO DEVE permitir apagar consultas; as fechadas DEVEM permanecer acessíveis no histórico do ministério.
- **RF-013**: Quando um ministério for desativado, o sistema DEVE passar a fechadas todas as suas consultas abertas.

**Respostas dos participantes**

- **RF-014**: O sistema DEVE permitir que apenas participantes ativos do ministério respondam às consultas abertas dele.
- **RF-015**: O sistema DEVE oferecer a cada pessoa a tela "Disponibilidade" com as consultas abertas dos seus ministérios, e a tela inicial DEVE indicar quando existir consulta aberta com datas ainda sem resposta da pessoa.
- **RF-016**: O sistema DEVE permitir marcar, por data, "disponível" ou "indisponível", salvar respostas parciais, manter "sem resposta" nas datas não marcadas e alterar respostas enquanto a consulta estiver aberta.
- **RF-017**: O sistema DEVE tratar "sem resposta" como situação distinta de "indisponível" em toda a funcionalidade (grade, contagens e avisos).
- **RF-018**: O sistema DEVE permitir uma observação opcional por pessoa e por consulta, de até 300 caracteres, visível apenas ao próprio autor, aos líderes do ministério e aos administradores.
- **RF-019**: O sistema DEVE permitir que quem passa a participar do ministério depois da abertura de uma consulta aberta a responda, e DEVE deixar de exibir, na grade, nas contagens e nas escalas, as respostas de quem deixa o ministério, sem descartá-las.
- **RF-020**: O sistema DEVE garantir que cada pessoa veja somente as próprias respostas, observação e situação.
- **RF-021**: O sistema DEVE permitir que líderes do ministério e administradores preencham ou corrijam a resposta de qualquer participante ativo, inclusive com a consulta fechada, e DEVE indicar ao líder que a resposta foi preenchida por ele; a indicação deixa de valer quando o próprio participante altera a resposta.

**Acompanhamento pelo líder**

- **RF-022**: O sistema DEVE exibir ao líder, para cada consulta do seu ministério, uma grade com um participante ativo por linha, uma data por coluna e a resposta em cada célula, além das observações.
- **RF-023**: A grade DEVE mostrar, por data, quantos participantes estão disponíveis, e DEVE destacar as pessoas que ainda não responderam nenhuma data.
- **RF-024**: A grade DEVE ser utilizável em tela de celular, sem perda de informação, sem exigir ampliação e mantendo identificável a quem pertence cada resposta.
- **RF-025**: O sistema DEVE mostrar, por data, quantos disponíveis existem por função, com base nas aptidões cadastradas na funcionalidade de escalas, e destacar funções sem nenhum disponível.
- **RF-026**: O sistema DEVE exibir consultas de todos os ministérios aos administradores e apenas as dos ministérios que lidera aos líderes.
- **RF-027**: O sistema DEVE barrar, por tela e por acesso direto, qualquer ação de criação, alteração, preenchimento ou consulta de grade por quem não for líder do ministério da consulta nem administrador.

**Integração com escalas**

- **RF-028**: Ao escolher uma pessoa para uma vaga, se a data da escala fizer parte de uma consulta do mesmo ministério, o sistema DEVE mostrar a resposta da pessoa nessa data.
- **RF-029**: Se a resposta for "indisponível" ou "sem resposta", o sistema DEVE avisar o líder e permitir que continue, e a indicação DEVE permanecer visível, apenas a líderes e administradores, ao lado da pessoa escalada.
- **RF-030**: Se a data da escala não pertencer a nenhuma consulta do ministério, o sistema NÃO DEVE mostrar nenhuma indicação de disponibilidade.

### Entidades Principais

- **Consulta de disponibilidade**: pedido de um ministério, com título, mensagem opcional, prazo opcional, situação (aberta ou fechada) e criador. Tem uma ou mais datas.
- **Data da consulta**: data proposta dentro de uma consulta, com rótulo opcional. Não se repete entre consultas do mesmo ministério.
- **Resposta**: situação (disponível ou indisponível) de uma pessoa em uma data da consulta; a ausência de registro equivale a "sem resposta". Guarda se foi preenchida pelo líder.
- **Observação da consulta**: texto opcional (até 300 caracteres) de uma pessoa sobre uma consulta, visível ao líder e aos administradores.
- **Ministério, participante, função, aptidão e escala**: já existem nas funcionalidades 002 e 003 e são apenas consultados aqui.

## Critérios de Sucesso *(obrigatório)*

### Resultados Mensuráveis

- **CS-001**: Um líder cria uma consulta com todos os domingos de um mês em menos de 2 minutos.
- **CS-002**: Um participante responde a uma consulta de até 8 datas em menos de 1 minuto, pelo celular.
- **CS-003**: O líder identifica, em uma única tela e em menos de 30 segundos, quem ainda não respondeu e quais datas têm poucos disponíveis ou nenhum para alguma função.
- **CS-004**: Pelo menos 90% dos participantes ativos respondem às consultas da primeira escala feita com o app, sem uso do formulário externo.
- **CS-005**: Nenhuma pessoa consegue ver respostas ou observações de outra pessoa sem ser líder do ministério ou administrador, verificado por testes de acesso direto.
- **CS-006**: Em 100% dos casos em que uma pessoa "indisponível" ou "sem resposta" é escalada em data coberta por consulta, o líder vê o aviso antes de concluir a vaga.
- **CS-007**: A grade e o fluxo de resposta funcionam em telas de celular comuns (largura de 360 px), sem rolagem horizontal da página inteira.

## Premissas

- A funcionalidade depende das anteriores: login e papéis (001), ministérios e participantes (002) e funções, aptidões e escalas (003).
- "Hoje" e "fim do dia do prazo" seguem o fuso de Brasília.
- Participante ativo é quem participa do ministério no momento da ação; quem sai deixa de responder e de aparecer na grade, mas suas respostas são preservadas.
- Datas de consulta que já passaram deixam de aceitar respostas dos participantes, mas continuam corrigíveis pelo líder.
- Não há envio de notificações (e-mail, mensagem ou push); o aviso aos participantes é a indicação na tela inicial e a tela "Disponibilidade". Notificações ficam para funcionalidade futura.
- A contagem por função considera apenas aptidões (principais e secundárias) de participantes ativos que responderam "disponível".
- A grade oferece duas apresentações dos mesmos dados (tabela com rolagem horizontal da própria tabela e visão por data), com alternador; em tela estreita a visão por data é a padrão. Ambas atendem ao requisito RF-024.
- Limites de tamanho: título de 2 a 80 caracteres, mensagem de até 500, rótulo de data de até 40 e no máximo 31 datas por consulta, para manter a grade legível.
- Dados pessoais e observações seguem as regras de privacidade (LGPD) da constituição do projeto.
- Fora do escopo desta funcionalidade, por serem futuras: geração automática de escalas e regras específicas de cada ministério.
