# Pesquisa e Decisões: Escalas dos Ministérios

Nenhum item ficou "a esclarecer" no Contexto Técnico: a stack e as convenções vêm da 001 e da 002.
Esta pesquisa registra as decisões de desenho novas. Formato: Decisão, Justificativa, Alternativas.

<a id="decisao-1"></a>
## Decisão 1: Resposta "pendente" é a ausência de linha

- **Decisão**: `respostas_escala` só tem linhas para quem já respondeu (`confirmado` ou `recusado`).
  Quem está escalado e não tem linha está "pendente".
- **Justificativa**: "voltar tudo para pendente" (mudança de data/horário, FR-015) vira apagar as
  linhas; "a nova pessoa fica pendente" (FR-014) não exige criar nada; a pessoa trocada deixa de
  estar escalada e, se não tem mais vagas, sua linha é apagada. Menos estados para sincronizar.
- **Alternativas**: criar uma linha `pendente` para cada pessoa escalada. Rejeitada: exigiria criar,
  apagar e conciliar linhas a cada vaga adicionada, removida ou trocada.
- **Regra derivada**: se a pessoa já respondeu e o líder lhe dá **outra** vaga na mesma escala, a
  resposta existente é mantida (é uma participação só, FR-010).

<a id="decisao-2"></a>
## Decisão 2: O tempo é calculado na leitura, no fuso America/Sao_Paulo

- **Decisão**: a escala guarda `data` (date) e `horario` (time). Uma função imutável
  `inicio_da_escala(data, horario)` devolve o instante de início em America/Sao_Paulo. Regras:
  - **Criar**: `data >= hoje` (hoje em São Paulo).
  - **Somente leitura**: `hoje > data` (a partir do dia seguinte).
  - **Responder / pedir troca / decidir troca**: só se `agora < inicio_da_escala`.
- **Justificativa**: nenhuma tarefa agendada (cron) é necessária: um pedido pendente de uma escala
  iniciada é tratado como "sem efeito" nas leituras e recusado nas decisões, sem precisar ser
  atualizado no banco. Evita um serviço extra (custo zero, YAGNI) e é testável.
- **Testabilidade**: o "agora" vem de uma única função `agora_sp()`, que em produção é só `now()`
  e **não tem nenhum gancho de teste**. Os testes pgTAP a substituem **dentro da própria transação**
  com `create or replace function public.agora_sp()` devolvendo um instante fixo (ex.:
  `'2026-12-10 09:30-03'::timestamptz`); como todo teste termina em `rollback`, a função original
  volta sozinha. As demais funções de tempo (`hoje_sp`, `inicio_da_escala` e as regras) só chamam
  `agora_sp()`, nunca `now()` direto. Assim os testes de data são determinísticos.
- **Por que não uma configuração de sessão** (ex.: `app.agora_teste`): ela existiria no código de
  produção e, se algum caminho permitisse defini-la, quem o fizesse mudaria "hoje" e "já começou"
  (risco para os princípios III e V da constitution). Substituir a função no teste não deixa nada
  disso no app.
- **Alternativas**: coluna `inicia_em timestamptz` gerada. Rejeitada: a conversão de fuso numa coluna
  gerada exigiria funções não imutáveis; a função imutável própria resolve com menos risco. Cron
  para "expirar" pedidos: rejeitado (complexidade e serviço extra).

<a id="decisao-3"></a>
## Decisão 3: Escritas e leituras por funções; sem acesso direto às tabelas

- **Decisão**: as seis tabelas têm RLS ligada e **nenhum** `select/insert/update/delete` para
  `anon`/`authenticated`, exceto `funcoes_ministerio` (lida por participantes via RLS, pois só tem
  nome). Todo o resto passa por funções `security definer` que validam `auth.uid()` por dentro.
- **Justificativa**: as vagas mostram nomes (dado de `perfis`), e as respostas só podem ser vistas
  pela própria pessoa e por líderes. Funções devolvem exatamente o recorte permitido, sem email
  (ADR 0006, constitution V). Mesmo padrão já provado na 002.
- **Alternativas**: RLS por linha nas tabelas + visão para nomes. Rejeitada: RLS não filtra colunas
  e um erro de política vazaria respostas ou emails.

<a id="decisao-4"></a>
## Decisão 4: Travar a escala em toda alteração

- **Decisão**: toda função que muda vagas, respostas, data/horário, situação ou trocas começa com
  `select ... from escalas where id = ... for update`. Só depois lê o estado e decide.
- **Justificativa**: garante FR-035 e SC-004 (troca tudo-ou-nada, sem estado intermediário, mesmo com
  ações simultâneas, como o líder trocando a pessoa enquanto outro líder aprova a troca).
- **Como se prova**: o pgTAP roda em uma só conexão, então prova a **ordem sequencial** (a segunda
  ação enxerga o resultado da primeira e é recusada). A trava em si é provada por um teste de
  integração com **duas sessões reais** (duas sessões `supabase-js` de usuários diferentes chamando
  as funções ao mesmo tempo, repetidas várias vezes) contra o Supabase local, verificando que o
  estado final nunca é misto. Sem biblioteca nova.
- **Alternativas**: nível de isolamento serializável com repetição de tentativas. Rejeitada: o app
  teria que tratar erros de serialização; a trava por linha é mais simples e suficiente aqui.

<a id="decisao-5"></a>
## Decisão 5: Avisos devolvidos pelo servidor, confirmação explícita para continuar

- **Decisão**: `salvar_vaga(..., p_ciente boolean default false)` calcula os avisos (FR-017, FR-018).
  Se houver avisos e `p_ciente` for falso, **não grava** e devolve `{salvo:false, avisos:[...]}`.
  A interface mostra os avisos e, se o líder escolher "Continuar mesmo assim", repete a chamada com
  `p_ciente = true`. O mesmo vale em `decidir_troca_lider` ao aprovar (FR-034).
- **Justificativa**: o servidor é a fonte dos avisos (consistente com o estado real do banco no
  instante de salvar); uma só ida e volta no caso comum (sem aviso).
- **Alternativas**: a interface chamar uma função de aviso e depois outra de gravação. Rejeitada: dá
  margem a "aviso desatualizado" entre as duas chamadas.
- **Detalhe do aviso de outro ministério**: considera só escalas **publicadas**, de **outro**
  ministério, **na mesma data**, onde a pessoa ocupa vaga **e sua resposta é `confirmado`** (FR-017;
  pendente, recusada, rascunho e cancelada não contam). O horário não é comparado.
  Devolve ministério, evento e horário de início de cada uma.
- **Aptidão**: pessoa sem nenhuma aptidão cadastrada para a função conta como "não apta".

<a id="decisao-6"></a>
## Decisão 6: Efeitos em cascata por gatilhos e ajuste das funções da 002

- **Decisão**:
  - **Remover participante** (FR-019): um gatilho `after delete` em `participacoes_ministerio`
    chama `liberar_vagas_futuras(perfil, ministerio)`: põe `perfil_id = null` nas vagas de escalas
    **não canceladas com data >= hoje** daquele ministério, apaga a resposta da pessoa nessas
    escalas e marca como "sem efeito" os pedidos de troca pendentes ligados a essas vagas (feitos
    por ela ou indicando-a).
  - **Perder acesso ao app** (conta deixa de ser `aprovado`, ou é excluída): gatilho em `perfis`
    chama a mesma função para **todos** os ministérios; na exclusão, `on delete set null` na vaga
    preserva o histórico passado sem a pessoa (LGPD).
  - **Desativar ministério** (FR-020): `desativar_ministerio` (da 002) passa a cancelar escalas
    futuras (rascunhos e publicadas, data >= hoje) na mesma transação; `contar_escalas_futuras` dá o
    número para o aviso de confirmação do administrador. Substituída por **migração nova** (a
    migração antiga já aplicada não é editada, constituição 1.3.0).
- **Justificativa**: garantir a regra no banco, venha a mudança da tela, de outra função ou do
  Supabase; a interface não precisa lembrar de chamar nada.
- **"Líder é avisado"**: sem notificações (fora do escopo); o aviso é visual: vagas em aberto em
  destaque na escala e um aviso "N escalas com vagas em aberto" na página do ministério (função
  `contar_escalas_com_vagas_abertas`).
- **Alternativas**: o app chamar `liberar_vagas_futuras` depois de remover. Rejeitada: o cascade de
  exclusão de conta e a perda de acesso não passam pelo app.

<a id="decisao-7"></a>
## Decisão 7: Pedido de troca com estados explícitos

- **Decisão**: `situacao_troca` = `aguardando_indicada`, `aguardando_lider`, `aprovado`,
  `recusado_indicada`, `recusado_lider`, `cancelado`, `sem_efeito`. "Pendente" (para a regra de no
  máximo um por vaga) significa `aguardando_indicada` ou `aguardando_lider`, garantido por índice
  único parcial.
- **Justificativa**: o fluxo tem dois decisores em sequência; estados explícitos tornam as telas
  ("recebidos", "feitos", "aguardando minha aprovação") simples consultas por situação.
- **Quando um pedido vira `sem_efeito`** (no banco, na hora do evento): escala cancelada, mudança de
  pessoa da vaga, mudança de data/horário, vaga removida, remoção/perda de acesso de uma das duas
  pessoas, aprovação de outro pedido que escalou a indicada. Quando o horário de início passa,
  a leitura trata como sem efeito sem gravar (Decisão 2).
- **Alternativas**: um só "estado pendente" com flag de aceite. Rejeitada: obscurece o histórico
  mostrado em "Pedidos de troca".

<a id="decisao-8"></a>
## Decisão 8: Quem pode ser indicada e quem pode ser escalada

- **Decisão**: só contas `aprovado` que participam do ministério **ativo** (qualquer papel, inclusive
  líder). Para a troca, a indicada ainda não pode ocupar nenhuma vaga na escala (FR-029); quem pede
  não pode indicar a si mesma.
- **Busca de pessoas** para vagas e trocas: reutiliza a ideia de `buscar_pessoas` da 002, mas sobre
  participantes do ministério: função `listar_candidatos_escala(p_ministerio)` devolve id e nome
  (nunca email) para quem é líder/admin; para a troca, `listar_candidatas_troca(p_vaga)` devolve as
  participantes elegíveis à pessoa que ocupa a vaga.

## Decisão 9: Telas e navegação

- **Decisão**: `Minhas escalas` e `Pedidos de troca` ficam a **um toque** da tela inicial; confirmar
  ou recusar acontece **no próprio item** da lista (sem abrir outra tela), cumprindo SC-002. Telas de
  líder ficam sob `ministerios/[id]/`, em linha com a 002. Destaques usam **ícone + texto + cor**
  (nunca só cor), por acessibilidade (constitution I).
- **Alternativas**: aba nova na navegação. Rejeitada: o app ainda não tem navegação por abas; segue
  o padrão de atalhos na tela inicial da 001/002.

## Decisão 10: Limites técnicos

- 50 vagas por escala; nome do evento de 2 a 80 caracteres; observação até 300; rótulo da vaga até
  40; motivo de recusa até 200; nome da função de 2 a 40. Salvaguardas contra abuso e telas
  quebradas, não regras de negócio. Pedidos e respostas não expiram (ficam como registro).
