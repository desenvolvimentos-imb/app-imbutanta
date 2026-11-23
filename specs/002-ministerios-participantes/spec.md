# Especificação da Funcionalidade: Ministérios e Participantes

**Branch da Funcionalidade**: `002-ministerios-participantes`

**Criada em**: 2026-11-19

**Status**: Implementada e validada em desenvolvimento em 2026-11-23 (publicação em produção pendente)

**Entrada**: Descrição do usuário: "Ministérios e participantes do app IM Butantã: cadastro de ministérios pelo administrador, vínculo de pessoas a ministérios como participante ou líder (por ministério), pedidos de entrada decididos pelo líder, ajuste na aprovação de novos usuários e a tela Meus ministérios."

## Cenários de Usuário e Testes *(obrigatório)*

### História 1 - Administrador cadastra e mantém os ministérios (Prioridade: P1)

O administrador cria os ministérios da igreja (por exemplo, Louvor e Recepção) com nome e uma descrição curta, edita esses dados e desativa um ministério que deixou de existir, sem perder o histórico.

**Por que esta prioridade**: sem ministérios cadastrados não há a quem vincular pessoas nem, no futuro, escalas. É a base de tudo.

**Teste Independente**: Pode ser testada criando, editando e desativando um ministério como administrador, e entregando valor sozinha: a igreja passa a ter a lista oficial dos seus ministérios.

**Cenários de Aceitação**:

1. **Dado** que sou administrador, **Quando** crio um ministério informando nome e descrição curta, **Então** ele aparece na lista de ministérios ativos.
2. **Dado** que já existe um ministério ativo chamado "Louvor", **Quando** tento criar ou renomear outro ministério ativo para "Louvor" (ignorando diferença de maiúsculas, minúsculas e acentos), **Então** o app recusa com mensagem clara.
3. **Dado** um ministério ativo com participantes, **Quando** o desativo, **Então** ele sai da lista de ministérios ativos, não recebe novos pedidos e seus participantes e vínculos continuam registrados, apenas deixando de valer na prática.
4. **Dado** um ministério desativado, **Quando** crio um novo ministério com o mesmo nome, **Então** o app permite, pois só não podem coexistir dois ativos com o mesmo nome.
5. **Dado** que sou membro ou líder (sem ser administrador), **Quando** tento criar, editar ou desativar um ministério, por tela ou por acesso direto, **Então** o app barra a ação.

---

### História 2 - Gerenciar participantes e líderes de um ministério (Prioridade: P1)

O administrador e o líder de um ministério adicionam e removem pessoas desse ministério e definem se cada uma é "participante" ou "líder". Todo ministério tem sempre pelo menos um líder.

**Por que esta prioridade**: é o vínculo que as escalas vão usar para saber quem pode ser escalado onde, e é também o que dá autoridade aos líderes para decidir pedidos.

**Teste Independente**: Pode ser testada adicionando uma pessoa aprovada a um ministério como participante, promovendo-a a líder e tentando remover o último líder.

**Cenários de Aceitação**:

1. **Dado** que sou administrador ou líder do ministério X, **Quando** adiciono uma pessoa com conta ativa como participante, **Então** ela passa a constar na lista de participantes de X.
2. **Dado** uma pessoa participante de X, **Quando** a promovo a líder de X, **Então** ela passa a poder gerenciar X, mas continua sem poderes de líder em outros ministérios.
3. **Dado** que X tem apenas um líder, **Quando** tento removê-lo ou rebaixá-lo a participante, **Então** o app impede e explica que o ministério precisa de pelo menos um líder.
4. **Dado** que sou líder de X (e não de Y), **Quando** tento adicionar ou remover participantes de Y, **Então** o app barra a ação.
5. **Dado** uma pessoa que participa de Louvor e Recepção, **Quando** removo ela de Louvor, **Então** ela continua participante de Recepção.
6. **Dado** um ministério sem nenhum líder (recém-criado), **Quando** o administrador o cria, **Então** o app exige definir um líder inicial já na criação.

---

### História 3 - Pedir para entrar em ministérios no cadastro (Prioridade: P1)

Ao criar a conta, a pessoa pode, se quiser, marcar os ministérios de que participa. Cada marcação é apenas um pedido. Se ainda não houver ministérios cadastrados, essa escolha não aparece.

**Por que esta prioridade**: evita que os líderes tenham de cadastrar à mão a participação de todos e liga o cadastro de novos usuários aos líderes certos.

**Teste Independente**: Pode ser testada criando uma conta marcando dois ministérios e conferindo que a pessoa não vira participante de nenhum até um líder decidir.

**Cenários de Aceitação**:

1. **Dado** que existem ministérios ativos, **Quando** crio minha conta, **Então** vejo a lista de ministérios para marcar opcionalmente e posso concluir o cadastro sem marcar nenhum.
2. **Dado** que não existe nenhum ministério ativo, **Quando** crio minha conta, **Então** a escolha de ministérios não aparece.
3. **Dado** que marquei Louvor e Recepção no cadastro, **Quando** a conta é criada, **Então** existem dois pedidos pendentes, um para cada ministério, e eu não sou participante de nenhum.
4. **Dado** que me cadastrei por Google, **Quando** completo o cadastro, **Então** também consigo escolher os ministérios, com o mesmo comportamento.

---

### História 4 - Líder decide pedidos de entrada e aprova novos usuários (Prioridade: P1)

O líder vê os pedidos de entrada do(s) ministério(s) que lidera e aceita ou recusa cada um separadamente. Para uma conta nova pendente, o pedido aceito por um líder também ativa a conta. O administrador pode decidir qualquer pedido.

**Por que esta prioridade**: é o fluxo que tira do administrador a carga de aprovar todo mundo e que transforma pedidos em participações reais.

**Teste Independente**: Pode ser testada com uma conta nova que pediu um ministério: o líder aceita e a conta fica ativa, já participante.

**Cenários de Aceitação**:

1. **Dado** uma conta nova pendente que pediu Louvor, **Quando** o líder do Louvor aceita o pedido, **Então** a conta fica ativa e a pessoa passa a ser participante do Louvor.
2. **Dado** uma conta nova pendente que pediu Louvor e Recepção, **Quando** o líder do Louvor aceita, **Então** a conta fica ativa e o pedido da Recepção continua pendente para o líder da Recepção.
3. **Dado** uma conta nova pendente que pediu Louvor, **Quando** o líder do Louvor recusa o pedido, **Então** a conta continua pendente (não é recusada nem bloqueada) e aguarda outro ministério pedido ou um administrador.
4. **Dado** uma conta nova pendente que não pediu nenhum ministério, **Quando** o líder de qualquer ministério abre as telas de aprovação, **Então** essa pessoa não aparece para ele; somente administradores a veem e aprovam.
5. **Dado** uma conta já ativa que pediu Recepção, **Quando** o líder da Recepção recusa, **Então** a conta segue ativa e sem nenhum bloqueio.
6. **Dado** um pedido já decidido por outro líder ou administrador enquanto abro a tela, **Quando** tento decidi-lo, **Então** o app avisa que a situação mudou e mostra o estado atual.
7. **Dado** que sou líder do Louvor, **Quando** tento decidir um pedido da Recepção, por tela ou acesso direto, **Então** o app barra a ação.

---

### História 5 - Membro vê "Meus ministérios" e pede para entrar em outros (Prioridade: P2)

Cada pessoa tem uma tela "Meus ministérios" com os ministérios de que participa (e seu papel em cada um), quem faz parte deles e os pedidos que ela fez. Dali pode pedir para entrar em outros ministérios a qualquer momento. A tela existe, inclusive vazia, para quem não participa de nenhum.

**Por que esta prioridade**: dá visibilidade ao membro e permite entrar em ministérios depois do cadastro, mas o núcleo já funciona sem ela.

**Teste Independente**: Pode ser testada com um membro sem ministério (tela vazia com orientação) que pede para entrar em um e acompanha o pedido.

**Cenários de Aceitação**:

1. **Dado** que não participo de nenhum ministério, **Quando** abro "Meus ministérios", **Então** vejo uma mensagem amigável explicando que não participo de nenhum e como pedir para entrar, e a tela não dá erro.
2. **Dado** que participo do Louvor, **Quando** abro "Meus ministérios", **Então** vejo o Louvor com meu papel e a lista de quem faz parte dele (nomes e papéis).
3. **Dado** que sou membro com conta ativa, **Quando** peço para entrar na Recepção, **Então** o pedido fica pendente e consigo ver essa situação na tela.
4. **Dado** que já tenho um pedido pendente ou já sou participante de um ministério, **Quando** tento pedir de novo, **Então** o app não cria duplicidade e explica a situação.
5. **Dado** que meu pedido foi recusado, **Quando** abro "Meus ministérios", **Então** vejo que foi recusado e posso fazer um novo pedido depois.
6. **Dado** um pedido pendente meu, **Quando** desisto, **Então** posso cancelá-lo.

---

### História 6 - Visibilidade por papel (Prioridade: P2)

O administrador vê todos os ministérios, participantes e pedidos. O líder vê os participantes e os pedidos dos ministérios que lidera. O participante vê seus ministérios e quem faz parte deles. Quem não participa de um ministério não vê a lista de participantes dele.

**Por que esta prioridade**: protege os dados dos membros (LGPD) e define claramente quem enxerga o quê.

**Teste Independente**: Pode ser testada com três pessoas (administrador, líder do Louvor, participante da Recepção) e conferindo o que cada uma enxerga.

**Cenários de Aceitação**:

1. **Dado** que sou administrador, **Quando** abro a área de ministérios, **Então** vejo todos os ministérios (ativos e desativados) com participantes e pedidos pendentes.
2. **Dado** que sou líder do Louvor, **Quando** abro a área de ministérios, **Então** vejo participantes e pedidos do Louvor, mas não os da Recepção, da qual não faço parte.
3. **Dado** que sou participante da Recepção, **Quando** consulto o Louvor, por tela ou acesso direto, **Então** não vejo seus participantes.
4. **Dado** que sou membro sem ministério, **Quando** consulto a lista de ministérios para pedir entrada, **Então** vejo apenas nome e descrição curta, sem participantes.

---

### Casos de Borda

- Dois pedidos de aceitação simultâneos para o mesmo pedido ou dois líderes removendo ao mesmo tempo o último líder: a regra do "pelo menos um líder" e a decisão única do pedido devem se manter; a segunda ação é avisada.
- Desativar um ministério com pedidos pendentes: os pedidos deixam de poder ser decididos; se algum era o único pedido de uma conta nova pendente, essa conta volta a depender de um administrador.
- Desativar um ministério cujos participantes não têm outro vínculo: eles continuam com conta ativa, apenas sem ministério.
- Pessoa que teve o acesso removido, recusada ou que excluiu a conta (LGPD): sai das listas de participantes e de pedidos; o ministério que ficaria sem líder por isso exige que um administrador defina outro líder, e o app avisa o administrador.
- Pessoa com conta pendente sendo adicionada diretamente por um líder: não é possível; só contas ativas podem ser adicionadas por busca.
- Nome do ministério vazio, só com espaços ou excessivamente longo; descrição excessivamente longa: o cadastro é rejeitado com mensagem clara.
- Perda de conexão durante criação, aceite de pedido ou remoção: a ação não pode ficar pela metade; a pessoa vê mensagem e pode tentar de novo.
- Reativar um ministério desativado cujo nome agora conflita com um ativo: o app impede e pede novo nome.
- Aceitar o pedido de uma conta pendente que mudou de situação (por exemplo, já recusada por um administrador) enquanto o líder tinha a tela aberta: o app avisa e não ativa a conta.
- Papel de líder alterado enquanto a pessoa está conectada: o novo alcance passa a valer sem exigir novo login.

## Requisitos *(obrigatório)*

### Requisitos Funcionais

**Ministérios**

- **RF-001**: O administrador MUST poder criar um ministério informando nome e descrição curta, e MUST definir pelo menos um líder inicial (pessoa com conta ativa) na criação.
- **RF-002**: O administrador MUST poder editar nome e descrição de um ministério.
- **RF-003**: O administrador MUST poder desativar um ministério; a desativação MUST preservar o ministério, os vínculos e o histórico, apenas retirando-o do uso (sem novos pedidos nem novas participações).
- **RF-004**: O administrador MUST poder reativar um ministério desativado, respeitando a regra de nome único entre ativos.
- **RF-005**: O sistema MUST impedir dois ministérios ativos com o mesmo nome, comparando sem diferenciar maiúsculas, minúsculas, acentos ou espaços nas pontas, com mensagem clara.
- **RF-006**: O sistema MUST rejeitar nome vazio ou inválido e limitar o tamanho de nome e descrição, informando o que corrigir.
- **RF-007**: Apenas administradores MUST poder criar, editar, desativar ou reativar ministérios.

**Participantes e papéis por ministério**

- **RF-008**: Uma pessoa MUST poder participar de vários ministérios ao mesmo tempo ou de nenhum; ter conta no app MUST NOT exigir participação em ministério.
- **RF-009**: Em cada ministério, a pessoa MUST ter exatamente um dos papéis: "participante" ou "líder".
- **RF-010**: O papel de líder MUST valer apenas no ministério em que foi atribuído; ser líder de um ministério MUST NOT conceder poderes de líder em outro.
- **RF-011**: O administrador e o líder de um ministério MUST poder adicionar a esse ministério pessoas com conta ativa, remover participantes e alterar o papel entre participante e líder.
- **RF-012**: O sistema MUST garantir que todo ministério ativo tenha pelo menos um líder, impedindo remover ou rebaixar o último líder, e MUST explicar o motivo ao usuário.
- **RF-013**: Quando a saída de uma pessoa do app (exclusão da conta, remoção de acesso) deixaria um ministério sem líder, o sistema MUST preservar a regra do item anterior, exigindo antes que um administrador defina outro líder ou sinalizando o ministério ao administrador.
- **RF-014**: O líder MUST NOT poder alterar participantes ou pedidos de ministérios que não lidera.

**Pedidos de entrada**

- **RF-015**: No cadastro, a pessoa MUST poder, opcionalmente, marcar os ministérios ativos de que participa; a escolha MUST NOT aparecer quando não houver ministérios ativos, e o cadastro MUST poder ser concluído sem marcar nenhum.
- **RF-016**: Cada ministério marcado MUST gerar um pedido de entrada pendente; a pessoa MUST NOT virar participante antes de o pedido ser aceito.
- **RF-017**: Pessoas com conta ativa, ou ainda pendente (caso de quem entrou por Google e escolhe os ministérios na tela de espera), MUST poder pedir para entrar em ministérios ativos de que ainda não participam, a qualquer momento, e MUST poder cancelar um pedido pendente. Contas recusadas ou com acesso removido MUST NOT poder pedir.
- **RF-018**: O sistema MUST impedir pedidos duplicados (pedido pendente ou participação já existente para a mesma pessoa e ministério).
- **RF-019**: Cada pedido MUST ser decidido (aceito ou recusado) separadamente pelo líder do respectivo ministério ou por um administrador; ao aceitar, a pessoa MUST virar participante com o papel "participante".
- **RF-020**: Recusar um pedido MUST NOT bloquear nem alterar a situação da conta da pessoa; depois de recusado, a pessoa MUST poder pedir de novo.
- **RF-021**: O sistema MUST evitar decisões conflitantes: se o pedido foi decidido por outra pessoa desde que o decisor abriu a tela, ele MUST ser avisado e ver a situação atual.
- **RF-022**: Quando um ministério é desativado, seus pedidos pendentes MUST deixar de poder ser decididos.

**Aprovação de novos usuários (ajuste da funcionalidade 001)**

- **RF-023**: A conta nova pendente MUST ficar ativa quando um administrador a aprovar, ou quando o líder de um dos ministérios que a pessoa pediu aceitar o pedido de entrada correspondente; nesse caso a pessoa MUST receber o papel de membro e MUST virar participante desse ministério.
- **RF-024**: Recusa de pedido por um líder MUST NOT recusar nem ativar a conta; a conta pendente continua aguardando.
- **RF-025**: Contas pendentes que não pediram nenhum ministério (ou cujos pedidos deixaram de ser decidíveis) MUST ser aprovadas apenas por administradores, e MUST NOT aparecer para líderes.
- **RF-026**: A conta pendente MUST continuar vendo a tela de aguardando aprovação já existente, sem acesso a conteúdo, até a ativação.
- **RF-027**: O papel global "líder de ministério" da funcionalidade 001 MUST ser substituído pela liderança por ministério: o alcance de aprovação e de leitura do líder passa a depender dos ministérios que ele lidera. Quem lidera ao menos um ministério MUST ver as telas de líder.
- **RF-028**: A tela de aprovação de pendentes MUST passar a mostrar, para o líder, apenas as pessoas pendentes que pediram algum ministério que ele lidera, indicando qual ministério foi pedido; o administrador MUST ver todas.

**Visibilidade e telas**

- **RF-029**: O administrador MUST ver todos os ministérios (ativos e desativados), participantes e pedidos.
- **RF-030**: O líder MUST ver os participantes e os pedidos pendentes apenas dos ministérios que lidera.
- **RF-031**: O participante MUST ver os seus ministérios e a lista de quem faz parte deles (nome e papel); MUST NOT ver participantes de ministérios de que não faz parte. Pessoas cuja conta não está ativa (recusada, com acesso removido ou excluída) MUST NOT aparecer nessas listas.
- **RF-032**: Qualquer pessoa com conta ativa MUST ver a lista de ministérios ativos (nome e descrição curta) para poder pedir entrada.
- **RF-033**: Cada pessoa com conta ativa MUST ter uma tela "Meus ministérios", com os ministérios de que participa e seu papel, os pedidos feitos e seu estado; MUST existir e funcionar inclusive vazia, com mensagem orientadora.
- **RF-034**: Mudanças de participação, papel e pedidos MUST passar a valer sem exigir que a pessoa saia e entre novamente.

**Dados, privacidade e qualidade**

- **RF-035**: As regras de acesso por ministério MUST ser aplicadas no servidor e no banco de dados, e não só escondendo opções na interface: quem não tem permissão MUST ser barrado mesmo por acesso direto.
- **RF-036**: A funcionalidade MUST coletar apenas o que já existe (nome) mais os vínculos e pedidos de ministério; nenhum dado pessoal novo MUST ser pedido.
- **RF-037**: Ao excluir a conta (LGPD), os vínculos e pedidos da pessoa MUST ser removidos; registros que não identificam a pessoa podem ser mantidos.
- **RF-038**: Todas as telas MUST ser projetadas primeiro para celular, em português do Brasil e com acessibilidade WCAG AA, e as falhas MUST ser mostradas com mensagens compreensíveis, sem erros técnicos crus (constitution, princípios I e III).
- **RF-039**: As regras de permissão, de pedidos, de aprovação por líder e de "pelo menos um líder" MUST ter testes automatizados que falhem quando a regra for violada (constitution, princípio IV).

### Entidades-Chave *(incluir se a funcionalidade envolver dados)*

- **Ministério**: grupo de serviço da igreja. Atributos: nome, descrição curta, situação (ativo ou desativado). Possui participantes e pedidos de entrada.
- **Participação**: liga uma pessoa a um ministério. Atributos: papel naquele ministério (participante ou líder) e data de entrada. Uma pessoa pode ter várias; cada ministério ativo tem pelo menos um líder.
- **Pedido de Entrada**: solicitação de uma pessoa para entrar em um ministério. Atributos: pessoa, ministério, situação (pendente, aceito, recusado, cancelado), data, quem decidiu e quando, e se nasceu no cadastro.
- **Pessoa/Usuário** *(existente, ajustado)*: passa a ter, além do papel global (administrador ou membro), zero ou mais participações em ministérios; a condição de líder deixa de ser global.

## Critérios de Sucesso *(obrigatório)*

### Resultados Mensuráveis

- **CS-001**: O administrador consegue cadastrar um novo ministério, com líder inicial, em menos de 2 minutos.
- **CS-002**: Um líder consegue aceitar ou recusar um pedido de entrada em até 3 toques a partir da sua tela inicial.
- **CS-003**: Uma pessoa nova consegue criar a conta, marcar ministérios e chegar à tela de aguardando aprovação em menos de 3 minutos.
- **CS-004**: Um membro consegue abrir "Meus ministérios" e pedir para entrar em outro ministério em até 3 toques a partir da tela inicial.
- **CS-005**: 100% das tentativas de uma pessoa agir fora do seu alcance (líder mexendo em ministério alheio, membro vendo participantes de ministério de que não faz parte, não administrador criando ministério) são bloqueadas, verificado por testes automatizados.
- **CS-006**: Nenhum ministério ativo fica sem líder em nenhuma situação do app, verificado por testes automatizados.
- **CS-007**: Nenhum pedido recusado altera a situação da conta da pessoa, e nenhuma pessoa vira participante sem um aceite, verificado por testes automatizados.
- **CS-008**: Pelo menos 80% das contas novas que pedem algum ministério são ativadas por um líder, sem ação de administrador, nos primeiros meses de uso.
- **CS-009**: Todas as telas desta funcionalidade são utilizáveis em celular e atendem ao nível AA de acessibilidade, verificado no checklist de PR.

## Premissas

- O público é o mesmo da funcionalidade 001: membresia da Igreja Metodista no Butantã, principalmente em celular, com internet.
- A funcionalidade 001 está entregue; esta a ajusta onde indicado. O papel global "líder de ministério" passa a derivar da liderança em ministérios; quem já tinha esse papel global e não lidera nenhum ministério ainda vê a tela de membro até um administrador vinculá-lo como líder. A forma de migrar essas pessoas será definida no plano.
- O papel global continua tendo "administrador" e "membro"; a visão de líder aparece automaticamente para quem lidera ao menos um ministério.
- Ao criar um ministério, o administrador escolhe o líder inicial entre as contas ativas; como o administrador já tem acesso total, não precisa ser participante para gerenciar.
- Os pedidos feitos no cadastro valem mesmo se a conta ainda estiver pendente; só o aceite os transforma em participação.
- No cadastro por email e senha, os ministérios são marcados no próprio formulário; no cadastro por Google, que não tem formulário, a pessoa escolhe os ministérios na tela de aguardando aprovação. Por isso, enquanto a conta estiver pendente, ela também pode fazer pedidos de ministério (contas recusadas ou com acesso removido não podem).
- Quando uma conta pendente tem vários pedidos e um líder aceita um deles, a conta é ativada naquele momento; os demais pedidos seguem pendentes para os respectivos líderes.
- Se todos os ministérios pedidos por uma conta pendente forem recusados, a conta continua pendente e passa a depender de um administrador; o app não envia aviso (notificações estão fora do escopo).
- Recusar um pedido não impede novo pedido para o mesmo ministério depois.
- O app não limita o número de ministérios por pessoa nem de participantes por ministério; o porte esperado é pequeno (dezenas de ministérios e algumas centenas de pessoas). Única salvaguarda técnica: um cadastro novo aceita no máximo 30 ministérios marcados, para evitar abuso; depois do cadastro a pessoa pode pedir outros normalmente.
- Quando uma conta perde o acesso (ou é recusada), os vínculos dela com ministérios continuam registrados, mas ela deixa de aparecer nas listas; se um administrador reaprovar a conta, os vínculos voltam a valer com o papel que tinham, e os pedidos pendentes na época foram cancelados.
- Quem tem conta ativa vê a lista de ministérios ativos e suas descrições; a lista de participantes só é visível para quem faz parte do ministério, para o líder dele e para administradores.
- O histórico limitado a este escopo é o que fica nos próprios registros (ministério desativado, pedido decidido com quem decidiu e quando); histórico detalhado de mudanças fica fora.
- Fora do escopo: escalas, funções dentro do ministério (como vocal ou bateria, previstas para a funcionalidade de escalas), notificações por email ou push e pessoas sem conta no app.
- Dependências: usa o serviço de autenticação, o cadastro, a aprovação de usuários e a tela de aguardando aprovação da funcionalidade 001; custo zero conforme a constitution.
