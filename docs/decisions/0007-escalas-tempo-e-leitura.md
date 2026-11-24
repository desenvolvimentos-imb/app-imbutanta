# 0007 — Escalas: tempo calculado, resposta como ausência de linha e leitura só por funções

- **Data**: 2026-11-23
- **Situação**: Aceita e implementada
- **Origem**: plano de `003-escalas-ministerios` ([research](../../specs/003-escalas-ministerios/research.md))

## Contexto

A funcionalidade 003 cria escalas, vagas, respostas e pedidos de troca. Quatro pontos pediam uma
decisão que vale para o resto do projeto:

1. Várias regras dependem do **tempo**: a escala não pode ser criada no passado, vira somente
   leitura no dia seguinte, e ninguém responde nem pede troca depois do horário de início.
2. "Voltar todas as respostas para pendente" (mudança de data ou horário) e "a nova pessoa fica
   pendente" precisam ser baratos e sem risco de esquecer um caso.
3. As vagas mostram **nomes** de pessoas, e as respostas e os motivos de recusa só podem ser vistos
   pelo líder e pela própria pessoa. A tabela `perfis` tem email e continua fechada a líderes e
   participantes (ADR 0006).
4. A troca de vaga e a mudança de pessoa podem acontecer ao mesmo tempo, por pessoas diferentes.

## Decisão

1. **O tempo é calculado na leitura, no fuso America/Sao_Paulo.** Não há tarefa agendada (cron). O
   "agora" passa por uma única função, `agora_sp()`, que em produção é só `now()`. Um pedido de
   troca pendente de uma escala que foi cancelada ou já começou vale como "sem efeito" ao ser lido e
   é recusado ao ser decidido, sem ninguém atualizar a linha. Os testes fixam o relógio
   **redefinindo `agora_sp()` dentro da transação do teste** (que termina em `rollback`); **não** há
   configuração de sessão nem gancho de teste no código de produção, para ninguém conseguir "mudar
   o hoje" pela API.
2. **A resposta "pendente" é a ausência de linha** em `respostas_escala`. Só existe linha para quem
   já confirmou ou recusou e ainda ocupa alguma vaga da escala. Mudar data ou horário é apagar as
   linhas; a pessoa que sai da última vaga perde a linha.
3. **As tabelas de escalas não aceitam leitura nem escrita diretas** (exceto a lista de funções, que
   só tem nomes). Tudo passa por funções `security definer` que devolvem exatamente o recorte
   permitido: nomes sem email, e respostas só para o líder e para a própria pessoa.
4. **Toda alteração trava a escala** (`for update`) antes de decidir. Troca de pessoa, mudança de
   horário, cancelamento, resposta e aprovação de troca acontecem uma depois da outra, nunca
   misturadas, e a aprovação é tudo ou nada. A integridade extra mora no banco: chave estrangeira
   composta `(vaga, escala)` nos pedidos, índice único de um pedido pendente por vaga e gatilho que
   só deixa participantes do ministério ocuparem vagas.

## Consequências

- Nenhum serviço novo nem custo (constituição VI); menos peças para a pessoa que mantém o app.
- As regras valem mesmo para chamadas diretas à API; os testes pgTAP as provam sem a interface.
- A concorrência é provada por um teste de integração com duas sessões reais
  (`npm run test:integracao`, exige o Supabase local), além dos testes sequenciais.
- Cada função nova de leitura tem de lembrar de usar `agora_sp()` e nunca `now()` para regras de
  data (os testes de data falhariam se alguém esquecesse).
- Escalas antigas não são arquivadas: o volume é pequeno (ver limites no plano). Se crescer,
  arquivar escalas passadas é uma decisão futura.
