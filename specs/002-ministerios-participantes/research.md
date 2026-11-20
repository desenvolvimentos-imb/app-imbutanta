# Pesquisa e Decisões: Ministérios e Participantes

Não restou nenhum "NEEDS CLARIFICATION": a stack e o modelo de acesso já foram decididos na 001
([research.md](../001-login-papeis-acesso/research.md)). Abaixo estão as decisões **novas**.
Nenhum serviço novo foi adotado, então não há limites gratuitos novos a registrar.

## Decisão 1: Liderança por ministério substitui o papel global "líder" {#decisao-1}

- **Decisão**: "líder" deixa de ser um valor de `perfis.papel`. Passa a ser **derivado**: a pessoa
  é líder se tem uma participação com papel `lider` em um ministério **ativo** e a conta está
  `aprovado`. `perfis.papel` fica só com `membro` e `administrador`.
- **Justificativa**: RF-010 exige que a liderança valha por ministério ("líder do Louvor não é
  líder da Recepção"). Manter dois conceitos (papel global e papel por ministério) criaria
  contradições, por exemplo um "líder global" que aprova qualquer pessoa. Uma única fonte da
  verdade (a participação) é mais simples e mais segura.
- **Como migrar** (RF-027): uma migração converte `papel = 'lider'` em `membro` e acrescenta uma
  constraint `papel <> 'lider'`. O valor `lider` **permanece no tipo** (o Postgres não permite
  remover valores de enumeração sem recriar o tipo). Essas pessoas voltam a ser líderes quando um
  administrador as vincular a ministérios (premissa do spec). Antes de aplicar em produção, listar
  quem tem `papel = 'lider'` para o administrador saber quem precisa ser revinculado (ver
  [quickstart.md](quickstart.md)).
- **Alternativas**: (a) manter o papel global e acrescentar o por ministério — conflito de regras;
  (b) apagar e recriar o tipo `papel_usuario` — arriscado em tabela em uso e sem ganho real;
  (c) migrar cada líder global para todos os ministérios — não existem ministérios ainda e daria
  poder indevido.

## Decisão 2: Modelo de dados em três tabelas

- **Decisão**: `ministerios` (nome, descrição, ativo), `participacoes_ministerio` (pessoa,
  ministério, papel `participante`/`lider`) e `pedidos_entrada_ministerio` (pessoa, ministério,
  situação, decisor). Escritas somente por funções SQL; leitura direta só do que é seguro.
- **Justificativa**: a 001 já previa uma tabela de participações (RF-019 da 001). O pedido é um
  conceito diferente (tem estado e decisor) e precisa de tabela própria para não misturar
  "quem é participante" com "quem quer ser". Ministérios nunca são apagados, apenas desativados
  (RF-003), então as chaves para `ministerios` usam `on delete restrict`. Vínculos e pedidos
  referenciam `perfis` com `on delete cascade`, o que dá a exclusão LGPD de graça (RF-037).
- **Alternativas**: coluna `ministerios uuid[]` em `perfis` (não permite papel por ministério nem
  RLS decente); pedido como participação "pendente" (mistura estados e enfraquece a regra de que só
  o aceite cria participação).

## Decisão 3: Colegas se enxergam por funções, só nome e papel {#decisao-3}

- **Decisão**: líder e participante **não** ganham leitura na tabela `perfis`. Veem os colegas
  por funções `security definer` (`listar_participantes`, `listar_pedidos_pendentes`,
  `buscar_pessoas`) que devolvem apenas `id`, `nome` e dados do vínculo. O administrador continua
  lendo `perfis` inteiro (como na 001).
- **Justificativa**: a RLS libera **linhas inteiras** e `perfis` tem `email`. Abrir a tabela a todos
  os participantes exporia o email de cada membro a colegas (constitution V: dados mínimos; RF-031
  pede ver "quem faz parte", não o contato). Funções com a regra de acesso dentro entregam só o
  necessário e continuam valendo contra chamadas diretas.
- **Consequência aceita**: `buscar_pessoas` deixa líderes e administradores consultarem **nomes**
  de membros aprovados (limite de 20 resultados e mínimo de 2 letras) para adicionar participantes.
  É necessário para RF-011 e restrito a quem lidera.
- **Alternativas**: política de leitura em `perfis` (vazaria email); view com `security_invoker`
  (a view herda a RLS da tabela, então não resolve o problema de colunas).

## Decisão 4: Nome único entre ministérios ativos, sem diferenciar acento e caixa

- **Decisão**: índice único **parcial** (`where ativo`) sobre o nome normalizado, calculado por
  uma função imutável `normalizar_nome_ministerio(texto)` = `lower(unaccent(btrim(...)))` com
  espaços internos repetidos reduzidos a um. O app traduz a violação em "Já existe um ministério
  ativo com esse nome".
- **Justificativa**: RF-005 pede esse comparador e a unicidade só entre ativos (RF-004: ministério
  desativado pode ter o nome reusado). Um índice no banco vale mesmo com duas pessoas criando ao
  mesmo tempo, o que uma checagem na tela não garante.
- **Detalhe técnico**: `unaccent` não é marcada como imutável, então o índice usa um *wrapper*
  imutável (padrão conhecido no Postgres) que fixa o dicionário. A extensão é gratuita e já vem
  disponível no Supabase.
- **Alternativas**: `citext` (resolve só caixa, não acento); comparar na aplicação (corrida entre
  duas criações simultâneas).

## Decisão 5: "Pelo menos um líder" garantido por gatilhos

- **Decisão**: gatilho `proteger_ultimo_lider` em `participacoes_ministerio` (antes de `update` e
  `delete`) e outro em `perfis` (quando a situação deixa de ser `aprovado`). Ambos levantam
  `ultimo_lider` se o ministério ativo ficaria sem líder **válido** (participação `lider` + conta
  `aprovado`). Os gatilhos travam os líderes do ministério (`for update`) para impedir duas remoções
  simultâneas.
- **Justificativa**: RF-012 e RF-013 e CS-006 exigem que nenhum ministério ativo fique sem líder em
  nenhuma situação. O gatilho cobre também a exclusão de conta (a cascata apaga a participação e
  dispara o gatilho) e a remoção de acesso. Segue o padrão do "último administrador" da 001.
- **Consequência**: se a pessoa é a única líder de um ministério, o app impede excluí-la ou remover
  seu acesso e mostra o nome do ministério; um administrador define outro líder antes. Por isso não
  existe estado "ministério sem líder" a sinalizar (o requisito RF-013 é cumprido por prevenção).
- **Exceção deliberada**: ministérios **desativados** não exigem líder (ficam como histórico).
  Reativar exige haver líder válido, ou informar um na reativação.
- **Alternativa**: rebaixar/promover automaticamente — decisão silenciosa demais para ser segura.

## Decisão 6: Pedidos no cadastro (email) e na tela de espera (Google) {#decisao-6}

- **Decisão**: no cadastro por **email e senha**, os ministérios marcados vão em
  `options.data.ministerios` (metadados do cadastro, como o `nome` já vai). O gatilho
  `sincronizar_perfil_auth` (da 001), ao criar o perfil, cria um pedido pendente para cada
  ministério ativo válido, sem nunca falhar o cadastro (ids inválidos ou inativos são ignorados).
  No cadastro por **Google** não há formulário, então a escolha acontece na tela
  `/aguardando-aprovacao`, que oferece "Pedir ministérios" enquanto a conta está pendente.
  Em ambos os casos o pedido nasce igual e a pessoa não vira participante sem aceite.
- **Justificativa**: o cadastro por email não tem sessão até a confirmação do email, então os
  pedidos precisam viajar nos metadados. Para o Google, a pessoa só passa a ter perfil depois do
  retorno do Google, e a tela de espera é o primeiro lugar onde ela já está identificada. Reusa a
  mesma função `pedir_entrada_ministerio` que serve a quem já tem conta (RF-017).
- **Segurança**: metadados do cadastro são controlados pelo usuário, então o gatilho valida cada id
  (formato de UUID, ministério existente e ativo) e limita a quantidade (máx. 30 por cadastro).
  Ele só roda no `insert` da conta; alterar metadados depois não cria pedidos.
- **Ajuste do spec**: RF-017 fala em "conta ativa"; a função aceita também conta **pendente** (para
  o fluxo Google) e recusa conta `recusado`/`acesso_removido`. Registrado nas Premissas do spec.
- **Alternativas**: tela intermediária obrigatória após o Google (adiciona um passo para todos);
  guardar a escolha em cookie (frágil e perderia o pedido ao trocar de aparelho).

## Decisão 7: Aprovar a conta pelo pedido, em uma operação só

- **Decisão**: `decidir_pedido_entrada` faz tudo atomicamente quando o pedido é aceito: marca o
  pedido como `aceito`, cria a participação como `participante` e, se a conta estiver `pendente`
  (com email confirmado), a ativa como `membro` registrando quem decidiu. Recusar só marca o pedido
  como `recusado`, sem tocar na conta.
- **Justificativa**: RF-019, RF-020, RF-023 e RF-024. Se fossem passos separados, uma falha no meio
  deixaria a pessoa ativa sem participação, ou participante de conta pendente (constitution III).
- **Quem decide**: administrador ou líder **válido do ministério do pedido** (ministério ativo,
  líder com conta aprovada). Ninguém decide o próprio pedido (mesma regra de "ninguém decide sobre
  si mesmo" da 001).
- **`decidir_cadastro` (001)**: passa a ser exclusiva do administrador, pois o papel global de líder
  deixou de existir. É o caminho para quem não pediu ministério (RF-025).
- **Efeitos ao recusar/remover conta**: um gatilho cancela os pedidos pendentes de uma pessoa cuja
  conta passa a `recusado` ou `acesso_removido`, para não restarem pedidos "órfãos" na fila de
  líderes.

## Decisão 8: Ministério desativado

- **Decisão**: desativar muda `ativo` para `false` e grava `desativado_em`; participações e pedidos
  **não** são apagados nem alterados. Tudo o que depende do ministério passa a exigir `ativo`:
  adicionar participantes, pedir entrada, decidir pedidos, e a liderança do ministério (líder de
  ministério desativado não conta como líder para nada). Pedidos pendentes permanecem pendentes
  (voltam a poder ser decididos se o ministério for reativado).
- **Justificativa**: RF-003 e RF-022; preserva o histórico (spec: "Desativar não apaga o histórico")
  sem criar um estado novo de pedido.
- **Consequência**: uma conta pendente cujo único pedido está em ministério desativado não aparece
  mais para líder algum; só o administrador a aprova (RF-025).

## Decisão 9: Leitura "Meus ministérios" por consulta direta

- **Decisão**: as telas de "Meus ministérios" leem `participacoes_ministerio` e
  `pedidos_entrada_ministerio` diretamente, protegidas por RLS que só entrega **as próprias linhas**
  (e todas ao administrador). A lista de ministérios ativos é legível por qualquer pessoa logada
  **e também pelo visitante do cadastro**, só com nome e descrição.
- **Justificativa**: simples e seguro, pois essas linhas não carregam dado de terceiros. A lista
  pública de ministérios é necessária para mostrar as opções na tela de cadastro (RF-015); nome e
  descrição curta de um ministério não são dado pessoal. Aceito como exceção ao RF-024 da 001
  (todas as páginas pedem login), restrita a essa leitura e registrada na ADR 0006.
- **Alternativas**: pedir login antes de mostrar os ministérios (contraria o fluxo do spec:
  marcar no cadastro); duplicar a lista no código (desatualiza quando o administrador edita).

## Decisão 10: Navegação e telas

- **Decisão**: tela inicial ganha atalhos "Meus ministérios" (todos) e "Ministérios" (todos; o
  administrador gerencia); `/aprovacoes` passa a se chamar "Pedidos e aprovações" na interface e
  mostra duas seções: **Cadastros pendentes** (só administrador; contas sem decisão) e **Pedidos de
  entrada** (administrador: todos; líder: dos seus ministérios). A rota continua `/aprovacoes`.
- **Justificativa**: mantém o endereço já conhecido, evita criar duas filas separadas para o líder
  e cumpre CS-002 (aceitar em ≤ 3 toques: Início → Pedidos → Aceitar = 2 toques).
- **Contagem na tela inicial**: soma de pedidos pendentes visíveis ao usuário (e, para o
  administrador, também os cadastros pendentes).

## Decisão 11: Testes e dados de teste

- **Decisão**: o `seed.sql` passa a criar o ministério "Louvor" (líder: Lucas) e "Recepção"
  (líder: Ana, a administradora). Os testes pgTAP que citam o papel `lider` (003, 004, 006, 008)
  são ajustados; novos arquivos 009 a 019 cobrem as regras novas; o e2e `papeis`/`aprovacao`
  passam a usar liderança por ministério.
- **Justificativa**: constitution IV (regras críticas testadas antes ou junto) e CS-005 a CS-007.
