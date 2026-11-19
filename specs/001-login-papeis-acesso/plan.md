# Plano de Implementação: Login e Papéis de Acesso

**Branch**: `001-login-papeis-acesso` | **Data**: 2026-11-19 | **Spec**: [spec.md](spec.md)

**Entrada**: Especificação em `specs/001-login-papeis-acesso/spec.md`

## Resumo

Primeira funcionalidade do app Imbutanta: cadastro e login (Google e email/senha), fila de
aprovação, três papéis (administrador, líder de ministério, membro), tela inicial por papel,
recuperação de senha, saída e exclusão de conta (LGPD).

Abordagem técnica (definida pelo dono do projeto: **Supabase + Vercel**):

- **Next.js (App Router, TypeScript)** hospedado na **Vercel**, instalável como PWA.
- **Supabase Auth** cuida de Google, email/senha, confirmação de email, recuperação de senha e
  sessão. Nenhuma senha passa pelo nosso código (constitution V).
- **Supabase Postgres** guarda o perfil (`perfis`) com situação e papel. As regras de acesso
  são aplicadas por **RLS** (Row Level Security) e por **funções SQL** (aprovar, mudar papel,
  excluir conta); a interface apenas reflete essas regras (RF-020).
- O papel é lido do banco a cada requisição (não vai "congelado" no token), então mudanças
  valem na hora (RF-026).

Detalhes das decisões em [research.md](research.md).

## Contexto Técnico

**Linguagem/Versão**: TypeScript 5.x em Node.js 22 LTS; SQL (Postgres 15+ do Supabase)

**Dependências principais**: Next.js 16 (App Router), React 19, `@supabase/supabase-js`,
`@supabase/ssr`, Tailwind CSS, Zod (validação de formulários)

**Armazenamento**: Supabase Postgres (tabela `perfis` + `auth.users` gerenciada pelo Supabase)

**Testes**: Vitest (unitários), pgTAP via `supabase test db` (regras de RLS/funções no
banco), Playwright (ponta a ponta em celular emulado, com email/senha). Entrada via Google
não é automatizável; tem roteiro manual (ver [quickstart.md](quickstart.md)).

**Plataforma alvo**: navegadores móveis modernos (Chrome Android, Safari iOS) e desktop; PWA

**Tipo de projeto**: aplicação web única (frontend + backend no mesmo projeto Next.js; o
"backend" é o Supabase)

**Metas de desempenho**: tela inicial utilizável em < 10 s em conexão móvel comum (CS-002);
nenhuma consulta pesada (a escala é de dezenas a poucas centenas de usuários)

**Restrições**: custo zero (planos gratuitos); somente online; pt-BR; fuso America/Sao_Paulo;
WCAG AA; mobile-first

**Escala/Escopo**: membresia de uma igreja (≈ dezenas a centenas de usuários); ~10 telas
nesta funcionalidade

### Limites gratuitos e o que acontece ao ultrapassar (constitution VI)

Resumo; números e fontes em [research.md](research.md#limites-gratuitos).

| Serviço | Limite relevante (plano gratuito) | Ao ultrapassar / risco |
|---------|-----------------------------------|------------------------|
| Supabase | 50 mil usuários ativos/mês, 500 MB de banco, 2 projetos; **pausa o projeto após ~1 semana sem uso** | Projeto pausado (restaurável pelo painel); acima das cotas o serviço restringe ou exige plano pago. Muito acima da nossa escala |
| Supabase (email padrão) | Envio de email nativo é **muito limitado** e só entrega a membros da equipe do projeto | **Inviável para o app real**: exige SMTP próprio (ver abaixo) |
| Vercel Hobby | Gratuito, uso pessoal/não comercial; cotas mensais de banda e execuções | Deploys/funções bloqueados até o mês virar; sem cobrança automática |
| Resend (SMTP) | ~3.000 emails/mês, 100/dia, 1 domínio | Envios recusados até o dia/mês virar |
| Google Cloud (OAuth) | Gratuito para login básico (email, perfil) | Sem custo; app precisa estar "Em produção" na tela de consentimento |

**Pendência que depende do dono do projeto**: o envio de email de confirmação e de
recuperação precisa de um SMTP próprio, e provedores gratuitos exigem **um domínio verificado**
(DNS). Se a igreja não tiver domínio, será preciso um (custo anual, fora do "custo zero") ou
um provedor que aceite remetente sem domínio próprio. Registrado como risco em
[research.md](research.md#decisao-4); não bloqueia o início, mas bloqueia a entrada em produção
do fluxo de email.

## Verificação da Constitution

*Portão: deve passar antes da Fase 0. Reavaliado após o design da Fase 1.*

| Princípio | Avaliação | Como o plano atende |
|-----------|-----------|---------------------|
| I. Mobile-first, PWA, pt-BR, WCAG AA | ✅ | Next.js + Tailwind desenhado primeiro para celular; `manifest` + service worker mínimo; textos em pt-BR; checklist de acessibilidade no PR; fluxos de ≤ 3 toques (CS-002, CS-003) |
| II. Simplicidade e YAGNI | ✅ | Autenticação e banco prontos (Supabase); sem biblioteca de UI pesada, sem gerenciador de estado, sem ORM; ministérios e informativos **não** são modelados agora |
| III. Robustez onde importa | ✅ | Validação com Zod; erros do Supabase traduzidos para pt-BR; operações críticas em funções SQL atômicas (aprovar, trocar papel, excluir) com verificação de conflito |
| IV. Testes automatizados | ✅ | pgTAP para RLS/regras, Vitest para validação/mapeamento de erros, Playwright para fluxos; testes escritos junto/antes; conceitos explicados na seção abaixo |
| V. Privacidade/LGPD | ✅ | Só nome e email; RLS no banco; chave `service_role` **não é usada** pelo app (exclusão via função SQL); segredos só em variáveis de ambiente |
| VI. Custo zero | ✅ com ressalva | Tudo em plano gratuito; ressalva do domínio para SMTP (acima) |
| VII. Documentação pt-BR | ✅ | ADR em `docs/decisions/`, comentários com o porquê, README atualizado na implementação |
| Fluxo de branches | ✅ | Trabalho na branch da feature → PR para `develop` → `main`; ver nota abaixo |

**Resultado do portão**: aprovado, sem violações. Seção de Complexidade vazia.

**Reavaliação pós-design (Fase 1)**: mantida a aprovação. O design adicionou apenas uma tabela
(`perfis`), uma tabela de configuração (`administradores_iniciais`) e funções SQL; nada além
do necessário.

> **Nota sobre branches**: a constitution manda criar branches de feature a partir de
> `develop`. O repositório hoje só tem `main` e esta branch saiu dela. Antes do primeiro PR é
> preciso criar `develop` e apontar o PR para ela.

## Estrutura do Projeto

### Documentação (esta funcionalidade)

```text
specs/001-login-papeis-acesso/
├── plan.md              # Este arquivo
├── research.md          # Fase 0: decisões e alternativas
├── data-model.md        # Fase 1: tabelas, estados, regras de RLS
├── quickstart.md        # Fase 1: como rodar e validar de ponta a ponta
├── contracts/
│   ├── rotas.md         # Rotas/telas e quem pode acessar cada uma
│   └── banco-rpc.md     # Funções SQL (RPC) chamadas pelo app e suas regras
└── tasks.md             # Fase 2 (gerado por /speckit-tasks, não por este comando)
```

### Código-fonte (raiz do repositório)

```text
src/
├── app/
│   ├── (publico)/               # sem login: entrar, cadastrar, recuperar, redefinir
│   │   ├── entrar/
│   │   ├── cadastrar/
│   │   ├── recuperar-senha/
│   │   └── redefinir-senha/
│   ├── (situacao)/              # logado, mas sem acesso a conteúdo
│   │   ├── aguardando-aprovacao/
│   │   ├── cadastro-recusado/
│   │   └── acesso-removido/
│   ├── (app)/                   # exige conta aprovada
│   │   ├── inicio/              # tela inicial muda conforme o papel
│   │   ├── aprovacoes/          # admin e líder
│   │   ├── usuarios/            # somente admin
│   │   └── conta/               # sair e excluir conta
│   ├── auth/
│   │   ├── callback/route.ts    # retorno do Google (OAuth/PKCE)
│   │   └── confirmar/route.ts   # links de email (confirmação e recuperação)
│   ├── manifest.ts              # manifesto do PWA
│   └── layout.tsx
├── proxy.ts                     # renova a sessão e redireciona quem não tem login
├── lib/
│   ├── supabase/                # clientes: navegador, servidor, proxy
│   ├── auth/
│   │   ├── sessao.ts            # lê usuário + perfil; decide para onde cada situação vai
│   │   ├── permissoes.ts        # papel → o que pode ver (fonte única para a interface)
│   │   ├── validacao.ts         # esquemas Zod (nome, email, senha)
│   │   └── mensagens-erro.ts    # erro do Supabase → mensagem em pt-BR
│   └── ...
└── components/                  # formulários, botões, cabeçalho, listas

public/
├── sw.js                        # service worker mínimo (instalação do PWA)
└── icons/

supabase/
├── config.toml                  # Auth, senha mínima, URLs de retorno, Google
├── migrations/                  # SQL versionado: tabelas, RLS, funções, gatilhos
├── seed.sql                     # contas de teste (somente ambiente local)
└── tests/                       # pgTAP: um arquivo por regra crítica

tests/
├── unit/                        # Vitest
└── e2e/                         # Playwright

docs/decisions/
└── 0001-stack-supabase-vercel.md
```

**Decisão de estrutura**: projeto único Next.js. Não há API própria: o navegador/servidor do
Next conversa direto com o Supabase, e as regras vivem no banco. Rotas agrupadas por situação
da pessoa (`(publico)`, `(situacao)`, `(app)`) para que a proteção seja aplicada por grupo, em
um único lugar (`layout.tsx` de cada grupo + `proxy.ts`), em vez de página por página.

## Como os testes funcionam (didático, constitution IV)

- **Teste unitário (Vitest)**: roda uma função pequena isolada e confere o resultado. Ex.:
  "nome só com espaços é rejeitado". Rápido, sem internet.
- **Teste de banco (pgTAP)**: roda dentro do Postgres local e confere regras como "um membro
  não consegue ler perfis alheios" ou "não dá para rebaixar o último administrador". É o teste
  mais importante aqui: garante que a segurança vale **mesmo** se alguém ignorar a interface.
- **Teste ponta a ponta (Playwright)**: abre um navegador de verdade (com tela de celular),
  cria conta, aprova, entra. Lento, então só cobre os fluxos principais.
- **Escrever antes**: para cada regra crítica, primeiro escreve-se o teste, vê-se falhar
  ("vermelho"), implementa-se a regra e vê-se passar ("verde"). Se o teste nunca falhou, não
  prova nada.
- **CI**: o GitHub Actions roda tudo a cada PR; sem tudo verde, não há merge.

## Rastreabilidade dos requisitos

| Requisitos | Onde é atendido |
|------------|-----------------|
| RF-001/002/005 | Supabase Auth (Google + senha), vinculação automática por email verificado |
| RF-003/006/007 | `validacao.ts`, `config.toml` (senha mínima), `mensagens-erro.ts` |
| RF-008–014 | `perfis` + gatilho de criação, `(situacao)`, `aprovacoes/`, função `decidir_cadastro`, `administradores_iniciais` |
| RF-015–023, RF-026 | enums `papel_usuario`/`situacao_conta`, RLS, `permissoes.ts`, `inicio/` |
| RF-020 | RLS + funções `security definer`; testes pgTAP |
| RF-021/022 | `usuarios/`, funções `alterar_papel`/`alterar_situacao`, gatilho "último administrador" |
| RF-024 | `proxy.ts` + `layout.tsx` por grupo |
| RF-025/019 | Apenas previstos no modelo (ver data-model.md); nada criado agora |
| RF-027/028 | Fluxos Supabase de recuperação; Google recupera pelo próprio Google |
| RF-029 | Sessão Supabase (cookies renovados pelo `proxy.ts`) |
| RF-030/031 | Função `excluir_minha_conta` |
| RF-032 | Limites de taxa do Supabase Auth + mensagem para HTTP 429 (limite por IP; ver research) |
| RF-033–036 | Constitution: PWA/acessibilidade, erros amigáveis, testes, `.env` fora do git |

## Acompanhamento de Complexidade

Sem violações da constitution; nada a justificar.
