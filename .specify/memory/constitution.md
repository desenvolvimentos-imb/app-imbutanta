<!--
Sync Impact Report
- Version change: 1.0.0 → 1.1.0
- Modified principles: nenhum renomeado
- Added sections: Princípio VII (Documentação Completa em pt-BR); fluxo de branches
  main/develop/feature em "Fluxo de Desenvolvimento"
- Modified sections: "Fluxo de Desenvolvimento" (regra genérica de branch principal
  substituída pelo fluxo main/develop/feature); "Restrições Técnicas" (idioma ampliado)
- Removed sections: nenhum
- Follow-up TODOs: criar CONTRIBUTING.md (passo a passo de branches/PR), configurar branch
  protection no GitHub e criar docs/decisions/ para registros de decisão. Stack concreta
  adiada para /speckit-plan.
-->
# Imbutanta Constitution

App web da Igreja Metodista no Butantã: escalas dos ministérios, informativos da igreja e
área de estudos (vídeos, fotos e quiz).

## Core Principles

### I. Usabilidade Primeiro, Mobile-First (NON-NEGOTIABLE)
- Toda tela MUST ser projetada primeiro para celular e funcionar bem em telas pequenas.
- O app MUST ser um PWA instalável na tela inicial e MUST estar em português do Brasil.
- Fluxos principais (ver a própria escala, ler um informativo, abrir um estudo) MUST ser
  concluídos em no máximo 3 toques a partir da tela inicial.
- Textos, botões e contraste MUST seguir boas práticas de acessibilidade (WCAG AA), pois o
  público inclui pessoas de todas as idades.

Racional: a adoção pela igreja depende de o app ser mais fácil que um grupo de mensagens.

### II. Simplicidade e YAGNI
- Cada funcionalidade MUST ser a solução mais simples que atende à especificação.
- Abstrações, bibliotecas e serviços novos MUST ser justificados por uma necessidade atual,
  não hipotética.
- O código MUST ser legível por uma pessoa com boa base em TI, mas sem rotina de
  desenvolvimento: nomes claros, funções curtas, comentários onde a intenção não é óbvia.
- Preferir recursos prontos de plataforma (autenticação, armazenamento, banco gerenciado) a
  código próprio.

Racional: o projeto é mantido por uma única pessoa; complexidade vira dívida de manutenção.

### III. Robustez Onde Importa
- Regras críticas MUST ter tratamento explícito de erros e validação de entrada:
  escalas (conflitos, duplicidades, datas), permissões e login, e pontuação do quiz.
- Falhas MUST exibir mensagens compreensíveis em português, nunca erros técnicos crus.
- Dados de escalas e conteúdo MUST ser consistentes: nenhuma ação parcial pode deixar uma
  escala em estado inválido.

Racional: robusto não significa grande; significa confiável nos pontos em que um erro
prejudica a rotina da igreja.

### IV. Testes Automatizados para Regras Críticas (NON-NEGOTIABLE)
- Escalas, permissões/login e quiz MUST ter testes automatizados que passem antes de
  qualquer merge.
- Para essas áreas, os testes MUST ser escritos antes ou junto da implementação e MUST
  falhar quando a regra for violada.
- Correção de bug MUST incluir um teste que reproduza o bug.
- Telas puramente visuais ou de conteúdo estático MAY ficar sem testes automatizados; nesse
  caso, a verificação manual MUST ser descrita no PR.
- Todo conceito de teste usado MUST ser explicado de forma didática no plano ou no PR,
  porque o mantenedor está aprendendo a prática.

Racional: são as áreas em que um erro silencioso afeta pessoas reais (voluntários não
avisados, acesso indevido, nota errada).

### V. Privacidade e Dados Mínimos (LGPD)
- O app MUST coletar apenas o necessário: nome e credenciais de login. Qualquer dado
  adicional MUST ser justificado na especificação.
- O acesso MUST seguir papéis (no mínimo: administrador, líder de ministério e membro), e
  cada papel MUST ver e alterar apenas o que lhe cabe. Regras de acesso MUST ser aplicadas no
  servidor/banco, não só na interface.
- Segredos (chaves, tokens, senhas) MUST NOT ser versionados no repositório.
- Senhas MUST NOT ser armazenadas em texto puro nem implementadas manualmente; usar o
  serviço de autenticação da plataforma.
- Titulares MUST poder pedir correção ou exclusão dos seus dados.

Racional: o app guarda dados de membros de uma comunidade; confiança é essencial.

### VI. Custo Zero
- Toda dependência de infraestrutura (hospedagem, banco, autenticação, armazenamento) MUST
  operar dentro de plano gratuito.
- Antes de adotar um serviço, o plano MUST registrar seus limites gratuitos e o que acontece
  ao ultrapassá-los.
- Vídeos MUST ser incorporados de plataformas externas (por exemplo, YouTube) em vez de
  hospedados no app, e fotos MUST ser otimizadas antes do envio, para respeitar os limites.
- Nenhum recurso que exija pagamento recorrente MAY ser adotado sem emenda a esta
  constitution.

Racional: a igreja não tem orçamento previsto para tecnologia.

### VII. Documentação Completa em pt-BR
- Tudo MUST estar documentado de forma que qualquer pessoa, no futuro, entenda **o que**
  foi feito, **como** e **por quê**.
- Idioma: código (nomes, comentários), commits, PRs, issues e documentação MUST ser em
  português do Brasil. Palavras-chave de linguagens, bibliotecas e prefixos do Conventional
  Commits (feat:, fix:) permanecem como são.
- No código: comentários MUST explicar a intenção e o porquê, não repetir o que a linha faz.
- No git: commits MUST ter mensagem descritiva, e PRs MUST explicar o contexto, a mudança e a
  motivação.
- Decisões importantes (escolha de serviço, mudança de arquitetura, exceção a um princípio)
  MUST ser registradas em `docs/decisions/`, com contexto, decisão e consequências.
- O README MUST permitir que alguém novo rode e entenda o projeto sem ajuda externa.

Racional: o projeto sobreviverá a quem o criou; a memória deve estar no repositório.

## Restrições Técnicas e de Dados

- Plataforma: aplicação web responsiva (PWA), acessada online pelo navegador.
- Stack concreta (framework, banco, hospedagem): definida em /speckit-plan, MUST respeitar
  os princípios II e VI; opções consideradas incluem serviços como Supabase e Vercel.
- Desempenho: telas principais MUST carregar de forma utilizável em conexão móvel comum;
  mídia pesada MUST ser carregada sob demanda.
- Idioma: interface, mensagens, código e documentação em pt-BR (ver princípio VII); datas e horários no formato brasileiro e fuso
  America/Sao_Paulo.
- Conteúdo: informativos e estudos MUST poder ser publicados por administradores sem alterar
  código.

## Fluxo de Desenvolvimento

- Repositório: GitHub da igreja; o desenvolvimento é feito pelo mantenedor como colaborador.
- Fluxo de branches:
  - `main` é a branch de **produção**. MUST receber alterações apenas por merge de `develop`.
  - `develop` é a branch de **integração e testes**. MUST receber as funcionalidades prontas
    e ser validada antes de ser enviada à `main`.
  - Cada funcionalidade ou correção MUST ter uma branch própria, criada a partir de
    `develop`, e voltar para `develop` por Pull Request ao fim do desenvolvimento.
    As branches numeradas do Spec Kit (ex.: `001-escalas`) seguem essa mesma regra.
  - Commits diretos em `main` e `develop` MUST NOT ser feitos, mesmo trabalhando sozinho.
    Ambas MUST ter branch protection no GitHub (PR obrigatório e testes passando).
- Commits: seguir Conventional Commits (feat:, fix:, docs:, test:, chore:), com descrição em
  pt-BR.
- Quality gates: um PR só MUST ser mergeado com testes passando, lint sem erros e checklist
  de acessibilidade/mobile verificado para telas novas.
- Fluxo Spec Kit: funcionalidades novas MUST seguir specify → plan → tasks → implement,
  com a especificação aprovada antes de implementar.
- Pequenos passos: preferir PRs pequenos e focados em uma única funcionalidade.

## Governance

- Esta constitution prevalece sobre outras práticas e preferências do projeto.
- Emendas MUST ser feitas por PR que descreva a mudança, o motivo e o impacto em
  especificações, planos e tarefas existentes, atualizando o Sync Impact Report.
- Versionamento semântico: MAJOR para remoção ou redefinição incompatível de princípios;
  MINOR para novo princípio/seção ou expansão material; PATCH para esclarecimentos e
  correções de redação.
- Conformidade: todo PR MUST ser conferido contra os princípios; desvios MUST ser
  justificados por escrito na seção de complexidade do plano ou na descrição do PR.
- Revisão periódica: a constitution MUST ser revisada a cada novo marco do projeto ou ao
  menos a cada seis meses.

**Version**: 1.1.0 | **Ratified**: 2026-11-18 | **Last Amended**: 2026-11-18
