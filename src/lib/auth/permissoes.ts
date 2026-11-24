// Fonte única, para a INTERFACE, de quem pode ver o quê (contracts/rotas.md).
// Atenção: esconder uma opção não é segurança. A segurança de verdade está no banco (RLS e
// funções SQL); isto só decide para onde levar a pessoa e o que mostrar.

export type Situacao = "pendente" | "aprovado" | "recusado" | "acesso_removido";
// Desde a funcionalidade 002 não existe papel global "líder": a liderança é por ministério.
// Quem lidera ao menos um ministério ativo chega às funções abaixo como `lidera = true`
// (derivado das participações, lido do banco a cada requisição).
export type Papel = "membro" | "administrador";

const TELA_DA_SITUACAO: Record<Exclude<Situacao, "aprovado">, string> = {
  pendente: "/aguardando-aprovacao",
  recusado: "/cadastro-recusado",
  acesso_removido: "/acesso-removido",
};

export const INICIO = "/inicio";

export function rotaDaSituacao(situacao: Situacao): string {
  return situacao === "aprovado" ? INICIO : TELA_DA_SITUACAO[situacao];
}

// Rotas restritas. As demais rotas do grupo (app) valem para qualquer pessoa aprovada.
type RegraDeRota = { base: string; permite: (papel: Papel, lidera: boolean) => boolean };

const ADMINISTRADOR = (papel: Papel) => papel === "administrador";
const ADMINISTRADOR_OU_LIDER = (papel: Papel, lidera: boolean) => papel === "administrador" || lidera;

const REGRAS_DE_ROTA: RegraDeRota[] = [
  { base: "/aprovacoes", permite: ADMINISTRADOR_OU_LIDER },
  { base: "/usuarios", permite: ADMINISTRADOR },
  { base: "/ministerios/novo", permite: ADMINISTRADOR },
];

const corresponde = (rota: string, base: string) => rota === base || rota.startsWith(`${base}/`);

// Devolve para onde redirecionar, ou null se a pessoa pode ficar na rota pedida.
export function destinoPara(situacao: Situacao, papel: Papel, rota: string, lidera: boolean): string | null {
  const telasDeSituacao = Object.values(TELA_DA_SITUACAO);

  if (situacao !== "aprovado") {
    const propria = TELA_DA_SITUACAO[situacao];
    return rota === propria ? null : propria;
  }

  if (telasDeSituacao.some((t) => corresponde(rota, t))) return INICIO;

  const regra = REGRAS_DE_ROTA.find((r) => corresponde(rota, r.base));
  if (regra && !regra.permite(papel, lidera)) return INICIO;
  return null;
}

export type Atalho = {
  href: string;
  rotulo: string;
  /** Rótulo curto para a barra de navegação inferior (celular tem pouco espaço). */
  curto: string;
};

// Atalhos de ministérios: valem para toda pessoa aprovada.
export const ATALHOS_MINISTERIOS: Atalho[] = [
  { href: "/meus-ministerios", rotulo: "Meus ministérios", curto: "Meus" },
  { href: "/ministerios", rotulo: "Ministérios", curto: "Ministérios" },
];

// Atalhos de gestão mostrados na tela inicial: aprovações para administrador e para quem lidera
// ministério; usuários só para administrador.
export function atalhosPorPapel(papel: Papel, lidera: boolean): Atalho[] {
  const atalhos: Atalho[] = [];
  if (ADMINISTRADOR_OU_LIDER(papel, lidera)) {
    atalhos.push({ href: "/aprovacoes", rotulo: "Pedidos e aprovações", curto: "Aprovações" });
  }
  if (ADMINISTRADOR(papel)) {
    atalhos.push({ href: "/usuarios", rotulo: "Gerenciar usuários", curto: "Usuários" });
  }
  return atalhos;
}
