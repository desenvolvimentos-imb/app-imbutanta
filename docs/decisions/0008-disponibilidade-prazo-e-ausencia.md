# 0008 — Disponibilidade: prazo calculado, "sem resposta" como ausência de linha e integração por avisos

- **Data**: 2026-11-24
- **Situação**: Aceita e implementada
- **Origem**: plano de `004-disponibilidade-participantes` ([research](../../specs/004-disponibilidade-participantes/research.md))

## Contexto

A funcionalidade 004 deixa o líder pedir aos participantes as datas em que podem ser escalados e
acompanhar as respostas. Cinco pontos pediam uma decisão que vale para o resto do projeto:

1. A consulta fecha sozinha ao fim do dia do prazo, sem ninguém agir.
2. "Sem resposta" **nunca** pode ser confundida com "indisponível" (uma pessoa que não respondeu não
   disse que não pode).
3. A mesma data não pode estar em duas consultas do mesmo ministério, mesmo se dois líderes criarem
   ao mesmo tempo.
4. Respostas e observações só podem ser vistas pela própria pessoa e por líderes/administradores
   (a tabela `perfis` tem email e continua fechada, ADR 0006).
5. Escalar alguém indisponível deve avisar o líder, sem bloquear e sem reescrever as funções de
   escala já entregues.

## Decisão

1. **"Aberta" é calculada**: a consulta guarda `fechada` (ação do líder ou desativação do
   ministério) e `prazo`; está aberta quando não está fechada e `hoje_sp() <= prazo`. Nenhuma tarefa
   agendada, o mesmo princípio da ADR 0007 (relógio único `agora_sp()`, fixado nos testes).
2. **"Sem resposta" é a ausência de linha** em `respostas_disponibilidade`; o tipo da resposta só
   tem `disponivel` e `indisponivel`. Não existe valor errado para gravar por engano; adicionar data
   ou entrar no ministério não exige criar nada; remover a data apaga as respostas por cascata.
3. **A unicidade da data é um índice** `(ministerio_id, data)` em `datas_consulta`, com
   `ministerio_id` repetido e chave estrangeira composta para nunca divergir da consulta. As funções
   convertem a violação em `data_duplicada`, citando a consulta que já tem a data.
4. **Tabelas fechadas a acesso direto**; leitura e escrita só por funções `security definer`, que
   devolvem o recorte permitido (sem email). Toda escrita trava a consulta (`for update`), então
   "pessoa responde" e "líder fecha" nunca se atropelam (teste de integração com duas sessões).
5. **Quem sai do ministério some por junção**, não por exclusão: as respostas ficam gravadas e
   reaparecem se a pessoa voltar. A exclusão da conta apaga tudo (cascata, LGPD).
6. **A integração com escalas é aditiva**: `avisos_para_vaga` ganhou o aviso `sem_disponibilidade`
   (por `create or replace` em migração nova, os avisos antigos e sua ordem não mudam) e a função
   `disponibilidade_da_escala` alimenta a indicação ao lado da pessoa. Só consultas do mesmo
   ministério contam; data fora de consulta não mostra nada.
7. **"Preenchido pelo líder"** guarda quem alterou a resposta por último: só muda quando a resposta
   muda, então salvar a tela inteira sem mexer numa data não apaga a marca dela.

## Consequências

- Nenhum serviço novo nem custo (constituição VI).
- As regras valem para chamadas diretas à API; os testes pgTAP (040 a 054) as provam sem a interface.
- Datas de consultas fechadas continuam "ocupadas": para reaproveitar uma data o líder a remove da
  consulta antiga (reabrindo-a, se preciso). É consequência direta de "consultas não são apagadas".
- A grade usa duas visões do mesmo dado (por data e tabela) para ser legível a 360 px. A tabela
  precisa de `position: relative` na área rolável: sem isso, textos só para leitor de tela
  (`sr-only`) ficam fora dela e alargam a página.
- Se o volume crescer, consultas antigas podem ser arquivadas (fora do escopo agora).
