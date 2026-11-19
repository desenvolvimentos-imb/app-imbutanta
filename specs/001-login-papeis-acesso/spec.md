# Especificação da Funcionalidade: Login e Papéis de Acesso

**Branch da Funcionalidade**: `001-login-papeis-acesso`

**Criada em**: 2026-11-18

**Status**: Rascunho

**Entrada**: Descrição do usuário: "Login e papéis de acesso do app IM Butantã (Igreja Metodista no Butantã): entrar com Google ou email e senha, cadastro com aprovação, papéis (administrador, líder de ministério e membro), tela inicial por papel, recuperação de acesso, saída e exclusão de conta (LGPD)."

## Cenários de Usuário e Testes *(obrigatório)*

### História 1 - Criar conta e aguardar aprovação (Prioridade: P1)

Uma pessoa da igreja abre o app pela primeira vez e cria uma conta, usando a conta Google ou um email e senha, informando o nome. Depois de criar a conta, ela vê uma tela clara dizendo que o cadastro está aguardando aprovação e que ainda não tem acesso ao conteúdo.

**Por que esta prioridade**: sem cadastro e controle de entrada não existe app. É a porta de entrada para todas as outras funcionalidades.

**Teste Independente**: criar uma conta pelos dois métodos e verificar que, em ambos, a pessoa fica "pendente" e só enxerga a tela de espera, sem acesso a nenhum conteúdo.

**Cenários de Aceitação**:

1. **Dado** uma pessoa sem conta, **Quando** ela escolhe entrar com Google e informa/confirma o nome, **Então** a conta é criada com situação "pendente" e ela vê a tela de aguardando aprovação.
2. **Dado** uma pessoa sem conta, **Quando** ela informa nome, email e senha válidos, **Então** a conta é criada com situação "pendente" e ela vê a tela de aguardando aprovação.
3. **Dado** uma pessoa com conta pendente, **Quando** ela tenta abrir qualquer página de conteúdo (diretamente pelo endereço, por exemplo), **Então** o acesso é negado e ela é levada de volta à tela de espera.
4. **Dado** um email já cadastrado, **Quando** outra pessoa tenta criar conta com o mesmo email, **Então** vê uma mensagem compreensível em português, sem revelar dados da conta existente.
5. **Dado** uma senha fraca ou um campo obrigatório vazio, **Quando** a pessoa envia o cadastro, **Então** vê mensagem clara indicando o que corrigir.

---

### História 2 - Entrar, ver a tela inicial do seu papel e sair (Prioridade: P1)

Uma pessoa aprovada entra no app (Google ou email e senha) e vê uma tela inicial adequada ao seu papel. Ela pode sair do app quando quiser e continua conectada entre uma visita e outra enquanto não sair.

**Por que esta prioridade**: é o uso diário do app e o que prova que os papéis funcionam.

**Teste Independente**: com uma conta de cada papel (administrador, líder, membro), entrar e verificar que cada uma vê uma tela inicial diferente e só as ações permitidas ao seu papel.

**Cenários de Aceitação**:

1. **Dado** uma pessoa aprovada como membro, **Quando** ela entra, **Então** vê a tela inicial de membro, sem opções de aprovação nem de gestão de usuários.
2. **Dado** uma pessoa aprovada como líder de ministério, **Quando** ela entra, **Então** vê a tela inicial de líder, com acesso à aprovação de novos usuários.
3. **Dado** uma pessoa administradora, **Quando** ela entra, **Então** vê a tela inicial de administrador, com acesso à aprovação e à gestão de usuários e papéis.
4. **Dado** uma pessoa conectada, **Quando** ela escolhe sair, **Então** a sessão é encerrada e qualquer página protegida passa a pedir login.
5. **Dado** email ou senha incorretos, **Quando** a pessoa tenta entrar, **Então** vê mensagem genérica de falha, sem indicar qual dos dois está errado.
6. **Dado** uma pessoa que tem conta tanto por Google quanto por email e senha com o mesmo email, **Quando** ela entra por qualquer um dos métodos, **Então** acessa a mesma conta e o mesmo papel.

---

### História 3 - Aprovar ou recusar novos usuários (Prioridade: P1)

Um administrador ou líder de ministério abre a tela de aprovação, vê a lista de pessoas pendentes (nome e data do cadastro) e aprova ou recusa cada uma. Ao ser aprovada, a pessoa passa a acessar o app como membro.

**Por que esta prioridade**: sem aprovação, ninguém além do primeiro administrador consegue usar o app. O primeiro administrador é o dono do projeto (Arthur), previamente definido.

**Teste Independente**: com uma conta pendente e uma conta aprovadora, aprovar e recusar contas e verificar o efeito no acesso de cada pessoa.

**Cenários de Aceitação**:

1. **Dado** pessoas pendentes, **Quando** um administrador ou líder abre a tela de aprovação, **Então** vê a lista com todas elas.
2. **Dado** uma pessoa pendente na lista, **Quando** o aprovador a aprova, **Então** ela sai da lista e, na próxima vez que abrir o app, entra como membro.
3. **Dado** uma pessoa pendente na lista, **Quando** o aprovador a recusa, **Então** ela sai da lista e passa a ver, ao abrir o app, uma mensagem de que o cadastro não foi aprovado, sem acesso a conteúdo.
4. **Dado** um membro comum ou uma pessoa pendente, **Quando** tenta abrir a tela de aprovação (inclusive pelo endereço direto), **Então** o acesso é negado.
5. **Dado** dois aprovadores abrindo a mesma pessoa pendente, **Quando** o primeiro aprova e o segundo tenta recusar depois, **Então** o segundo é avisado de que a situação dela já mudou, e nada é sobrescrito sem aviso.
6. **Dado** a primeira instalação do app, **Quando** o dono do projeto (Arthur) entra, **Então** ele já tem o papel de administrador, sem depender de aprovação de outra pessoa.

---

### História 4 - Recuperar acesso à conta (Prioridade: P2)

Quem esqueceu a senha pede a recuperação informando o email, recebe uma mensagem com um link seguro e define uma nova senha. Quem entra só por Google recupera o acesso pela própria conta Google.

**Por que esta prioridade**: evita depender de um administrador para cada senha esquecida, mas não bloqueia o primeiro uso.

**Teste Independente**: pedir recuperação com um email cadastrado, usar o link recebido, definir nova senha e entrar com ela.

**Cenários de Aceitação**:

1. **Dado** um email cadastrado, **Quando** a pessoa pede recuperação de senha, **Então** recebe uma mensagem com link para definir nova senha.
2. **Dado** um email não cadastrado, **Quando** a pessoa pede recuperação, **Então** vê a mesma mensagem de confirmação neutra (sem revelar se o email existe).
3. **Dado** um link de recuperação expirado ou já usado, **Quando** a pessoa o abre, **Então** vê mensagem clara e pode pedir um novo link.
4. **Dado** uma nova senha definida com sucesso, **Quando** a pessoa volta ao app, **Então** consegue entrar com a nova senha e a senha antiga deixa de funcionar.

---

### História 5 - Excluir a própria conta e os dados (LGPD) (Prioridade: P2)

Uma pessoa logada pode pedir a exclusão da sua conta e dos seus dados pessoais, depois de confirmar a decisão. Após a exclusão, ela não consegue mais entrar e seus dados deixam de existir no app.

**Por que esta prioridade**: é obrigação de privacidade (LGPD) e princípio da constitution do projeto, mas pode ser entregue logo após o fluxo principal.

**Teste Independente**: excluir uma conta de teste e verificar que o login deixa de funcionar e que a pessoa não aparece mais em nenhuma lista.

**Cenários de Aceitação**:

1. **Dado** uma pessoa logada, **Quando** ela pede a exclusão da conta e confirma, **Então** a conta e os dados pessoais são removidos e a sessão é encerrada.
2. **Dado** o pedido de exclusão, **Quando** a pessoa ainda não confirmou, **Então** nada é apagado e ela pode desistir.
3. **Dado** uma conta excluída, **Quando** a pessoa tenta entrar, **Então** o acesso falha como se a conta não existisse e ela pode criar uma nova conta, que começa como pendente.
4. **Dado** que a pessoa é o único administrador, **Quando** ela pede a exclusão da própria conta, **Então** o app impede e explica que é preciso antes passar o papel de administrador a outra pessoa.

---

### História 6 - Gerenciar papéis de usuários (Prioridade: P3)

O administrador vê a lista de usuários aprovados e pode alterar o papel de cada um (membro, líder de ministério ou administrador) e remover o acesso de alguém.

**Por que esta prioridade**: é necessária para designar líderes e outros administradores, mas, no início, poucas pessoas precisam disso e o dono do projeto pode atuar sozinho.

**Teste Independente**: promover um membro a líder, verificar que ele passa a ver a aprovação de usuários, e rebaixá-lo de volta.

**Cenários de Aceitação**:

1. **Dado** um administrador na tela de usuários, **Quando** ele altera o papel de uma pessoa, **Então** o novo papel vale na próxima vez que ela abrir ou atualizar o app.
2. **Dado** um líder ou membro, **Quando** tenta abrir a gestão de usuários e papéis (inclusive pelo endereço direto), **Então** o acesso é negado.
3. **Dado** o último administrador existente, **Quando** o administrador tenta rebaixar a si mesmo ou remover o próprio acesso, **Então** o app impede e explica o motivo.
4. **Dado** que cada pessoa pode participar de vários ministérios, **Quando** os ministérios forem criados em funcionalidade futura, **Então** o modelo de usuário já permite associar a pessoa a mais de um ministério (nesta funcionalidade só se prevê essa capacidade).

---

### Casos de Borda

- Pessoa tenta criar conta com Google e depois com email e senha usando o mesmo email: deve cair na mesma conta, sem duplicidade.
- Pessoa pendente ou recusada tenta criar nova conta com o mesmo email: não deve burlar a recusa.
- Nome em branco, só com espaços ou excessivamente longo: o cadastro deve ser rejeitado com mensagem clara.
- Sessão expirada no meio do uso: a pessoa é levada ao login, sem perder o que não dependia do servidor, e volta à página que tentava acessar.
- Papel alterado enquanto a pessoa está conectada: o novo papel passa a valer sem exigir novo login e nunca depois de um tempo longo.
- Perda de conexão durante o cadastro, a aprovação ou a exclusão: a ação não pode ficar pela metade; a pessoa vê mensagem e pode tentar de novo.
- Tentativas repetidas de login com senha errada: o app deve limitar as tentativas e avisar com mensagem clara.
- Pessoa aprovada que teve o acesso removido: vê tela de acesso removido e não consegue acessar conteúdo.
- Informativo marcado como público: nesta funcionalidade apenas a marcação existe; qualquer tela sem login só será criada em funcionalidade futura, então nenhum conteúdo é exposto sem login por enquanto.

## Requisitos *(obrigatório)*

### Requisitos Funcionais

**Entrada e cadastro**

- **RF-001**: O sistema MUST permitir criar conta e entrar com a conta Google.
- **RF-002**: O sistema MUST permitir criar conta e entrar com email e senha.
- **RF-003**: O sistema MUST coletar, além das credenciais de login, apenas o nome da pessoa, e MUST rejeitar nome vazio ou inválido.
- **RF-004**: O sistema MUST permitir que qualquer pessoa crie uma conta, sem convite prévio.
- **RF-005**: O sistema MUST tratar o mesmo email como uma única conta, independentemente do método de entrada usado.
- **RF-006**: O sistema MUST exigir senha com requisitos mínimos de segurança e MUST informar claramente o que corrigir quando a senha for rejeitada.
- **RF-007**: Mensagens de erro de login e de recuperação MUST ser em português e MUST NOT revelar se um email está ou não cadastrado.

**Situação da conta e aprovação**

- **RF-008**: Toda conta nova MUST começar com situação "pendente" e MUST NOT dar acesso a nenhum conteúdo do app.
- **RF-009**: Pessoas com conta pendente MUST ver uma tela clara explicando que o cadastro aguarda aprovação.
- **RF-010**: Pessoas com cadastro recusado MUST ver uma tela clara informando que o cadastro não foi aprovado, sem acesso a conteúdo.
- **RF-011**: O sistema MUST oferecer uma tela de aprovação, acessível apenas a administradores e líderes de ministério, que lista as pessoas pendentes (nome e data do cadastro).
- **RF-012**: O aprovador MUST poder aprovar ou recusar cada pessoa pendente; ao aprovar, a pessoa MUST receber o papel de membro.
- **RF-013**: O sistema MUST evitar decisões conflitantes: se a situação da pessoa mudou desde que o aprovador abriu a lista, ele MUST ser avisado.
- **RF-014**: O primeiro administrador MUST ser o dono do projeto (Arthur), definido previamente, sem passar pela fila de aprovação.

**Papéis e permissões**

- **RF-015**: O sistema MUST ter três papéis: administrador, líder de ministério e membro.
- **RF-016**: O administrador MUST poder realizar todas as ações do app, incluindo gerenciar usuários e papéis.
- **RF-017**: O líder de ministério MUST poder aprovar novos usuários e MUST ter acesso de leitura a conteúdos, informativos e estudos; a montagem de escalas do seu ministério será entregue em funcionalidade futura, e este requisito apenas reserva essa permissão.
- **RF-018**: O membro MUST poder ver as suas escalas, os informativos e os estudos (a serem entregues em funcionalidades futuras), sem acesso a aprovação nem gestão de usuários.
- **RF-019**: O modelo de usuário MUST permitir que uma mesma pessoa participe de vários ministérios ao mesmo tempo (a criação de ministérios é futura).
- **RF-020**: As regras de acesso por papel MUST ser aplicadas no servidor e no banco de dados, e não apenas escondendo opções na interface: uma pessoa sem permissão MUST ser barrada mesmo ao acessar pelo endereço direto ou por chamadas diretas.
- **RF-021**: O administrador MUST poder listar os usuários aprovados, alterar o papel de cada um e remover o acesso de alguém.
- **RF-022**: O sistema MUST impedir que fique sem nenhum administrador (rebaixamento, remoção de acesso ou exclusão do último administrador).

**Tela inicial e acesso**

- **RF-023**: Após entrar, a pessoa MUST ver uma tela inicial que muda conforme o seu papel, mostrando somente as ações permitidas a ele.
- **RF-024**: Todas as páginas do app, exceto cadastro, login, recuperação de conta, as telas de situação da conta e as páginas legais públicas (Política de Privacidade e Termos de Uso), MUST exigir login. *(Páginas legais acrescentadas em 2026-11-19: o Google exige links públicos para publicar o login e a LGPD pede transparência; nenhum conteúdo do app é exposto sem login.)*
- **RF-025**: O modelo de informativos futuros MUST prever a marcação "público" definida no momento da criação; nesta funcionalidade nenhuma tela pública é criada nem conteúdo é exposto sem login.
- **RF-026**: Mudanças de papel ou de situação da conta MUST passar a valer sem exigir que a pessoa saia e entre novamente.

**Recuperação, saída e exclusão**

- **RF-027**: A pessoa MUST poder pedir recuperação de senha pelo email e definir uma nova senha por um link seguro, com validade limitada e de uso único.
- **RF-028**: Quem entra por Google MUST conseguir recuperar o acesso pela própria conta Google, sem necessidade de intervenção de administrador.
- **RF-029**: A pessoa MUST poder sair do app a qualquer momento e permanecer conectada entre visitas enquanto não sair, até a sessão expirar.
- **RF-030**: A pessoa MUST poder pedir a exclusão da própria conta e dos seus dados pessoais, com confirmação explícita antes de apagar.
- **RF-031**: Depois da exclusão, o sistema MUST remover nome, email e credenciais da pessoa e MUST impedir novo login com a conta apagada.
- **RF-032**: O sistema MUST limitar tentativas repetidas de login e MUST avisar a pessoa com mensagem compreensível.

**Qualidade e constitution**

- **RF-033**: Todas as telas MUST ser projetadas primeiro para celular, instaláveis como PWA, em português do Brasil e com acessibilidade WCAG AA (constitution, princípio I).
- **RF-034**: Falhas MUST ser mostradas com mensagens compreensíveis em português, sem erros técnicos crus (constitution, princípio III).
- **RF-035**: Regras de login, papéis e permissões MUST ter testes automatizados que falhem quando a regra for violada (constitution, princípio IV).
- **RF-036**: Nenhum segredo (chaves, tokens) MUST ser versionado, e senhas MUST ser tratadas apenas pelo serviço de autenticação da plataforma (constitution, princípio V).

### Entidades-Chave *(incluir se a funcionalidade envolver dados)*

- **Pessoa/Usuário**: representa quem usa o app. Atributos: nome, email, método(s) de entrada, situação da conta (pendente, aprovada, recusada, acesso removido), papel (administrador, líder de ministério, membro), data do cadastro e, quando houver, quem decidiu a aprovação e quando.
- **Papel**: define o que a pessoa pode ver e fazer (administrador, líder de ministério, membro). Cada pessoa aprovada tem exatamente um papel.
- **Participação em Ministério** *(prevista, uso futuro)*: relaciona uma pessoa a um ministério; uma pessoa pode ter várias. Os ministérios em si serão criados em funcionalidade futura.
- **Marcação de Visibilidade de Informativo** *(prevista, uso futuro)*: indica se um informativo é público ou restrito a quem tem login; definida no momento da criação do informativo.

## Critérios de Sucesso *(obrigatório)*

### Resultados Mensuráveis

- **CS-001**: Uma pessoa nova consegue criar a conta e chegar à tela de aguardando aprovação em menos de 2 minutos, pelos dois métodos de entrada.
- **CS-002**: Uma pessoa aprovada consegue entrar e ver a sua tela inicial em até 3 toques a partir da abertura do app e em menos de 10 segundos em conexão móvel comum.
- **CS-003**: Um aprovador consegue aprovar ou recusar uma pessoa pendente em até 3 toques a partir da sua tela inicial.
- **CS-004**: 100% das tentativas de acesso a conteúdo ou a telas administrativas por pessoas sem permissão (pendentes, recusadas, membros, líderes em áreas de administrador) são bloqueadas, verificadas por testes automatizados.
- **CS-005**: 90% das pessoas conseguem recuperar a senha esquecida sozinhas, sem ajuda de um administrador, na primeira tentativa.
- **CS-006**: Após um pedido de exclusão confirmado, 100% dos dados pessoais da pessoa deixam de estar acessíveis no app e o login com a conta apagada deixa de funcionar.
- **CS-007**: O administrador consegue promover um membro a líder em menos de 1 minuto.
- **CS-008**: Nenhuma situação do app permite ficar sem pelo menos um administrador.
- **CS-009**: Todas as telas desta funcionalidade são utilizáveis em celular e atendem ao nível AA de acessibilidade, verificado no checklist de PR.

## Premissas

- O público é a membresia da Igreja Metodista no Butantã, com todas as faixas etárias, usando principalmente o celular; o app exige internet.
- Ao ser aprovada, a pessoa recebe o papel de membro; promoções a líder ou administrador são feitas depois por um administrador.
- Em cadastros por email e senha, a pessoa precisa confirmar que o email é dela antes de aparecer na fila de aprovação, para evitar cadastros falsos ou de terceiros; cadastros por Google já chegam com email verificado.
- Pessoa recusada não vê conteúdo; poderá ser reavaliada por um administrador, que pode reabrir o cadastro (reaprovar) pela tela de usuários.
- Ao excluir a conta, os dados pessoais são apagados; registros históricos que não identificam a pessoa podem ser mantidos nas funcionalidades futuras.
- O dono do projeto (Arthur) é definido como o primeiro administrador por configuração prévia do ambiente, não por cadastro aberto.
- O líder de ministério pode aprovar qualquer pessoa pendente, independentemente do ministério; vincular o líder a ministérios específicos acontecerá com o cadastro de ministérios.
- O aviso ao aprovador sobre novos pendentes dentro do app é suficiente; notificações por email ou push ficam fora do escopo.
- Fora do escopo desta funcionalidade: cadastro de ministérios, montagem de escalas, informativos, estudos, quiz e a tela pública de informativos.
- Dependências: serviço gratuito de autenticação e de envio de email de recuperação, conforme a constitution (custo zero); a escolha concreta será feita em `/speckit-plan`.
