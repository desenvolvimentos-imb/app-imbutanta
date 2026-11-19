// Fonte única, para a INTERFACE, de quem pode ver o quê (contracts/rotas.md).
// Atenção: esconder uma opção não é segurança. A segurança de verdade está no banco (RLS e
// funções SQL); isto só decide para onde levar a pessoa e o que mostrar.

export type Situacao = "pendente" | "aprovado" | "recusado" | "acesso_removido";
export type Papel = "membro" | "lider" | "administrador";

const TELA_DA_SITUACAO: Record<Exclude<Situacao, "aprovado">, string> = {
  pendente: "/aguardando-aprovacao",
  recusado: "/cadastro-recusado",
  acesso_removido: "/acesso-removido",
};

export const INICIO = "/inicio";

export function rotaDaSituacao(situacao: Situacao): string {
  return situacao === "aprovado" ? INICIO : TELA_DA_SITUACAO[situacao];
}

// Rotas restritas a certos papéis. As demais rotas do grupo (app) valem para qualquer aprovado.
const PAPEIS_POR_ROTA: { base: string; papeis: Papel[] }[] = [
  { base: "/aprovacoes", papeis: ["lider", "administrador"] },
  { base: "/usuarios", papeis: ["administrador"] },
];

const corresponde = (rota: string, base: string) => rota === base || rota.startsWith(`${base}/`);

// Devolve para onde redirecionar, ou null se a pessoa pode ficar na rota pedida.
export function destinoPara(situacao: Situacao, papel: Papel, rota: string): string | null {
  const telasDeSituacao = Object.values(TELA_DA_SITUACAO);

  if (situacao !== "aprovado") {
    const propria = TELA_DA_SITUACAO[situacao];
    return rota === propria ? null : propria;
  }

  if (telasDeSituacao.some((t) => corresponde(rota, t))) return INICIO;

  const regra = PAPEIS_POR_ROTA.find((r) => corresponde(rota, r.base));
  if (regra && !regra.papeis.includes(papel)) return INICIO;
  return null;
}

export type Atalho = { href: string; rotulo: string };

// Atalhos administrativos mostrados na tela inicial (membro não tem nenhum).
export function atalhosPorPapel(papel: Papel): Atalho[] {
  const atalhos: Atalho[] = [];
  if (papel === "lider" || papel === "administrador") {
    atalhos.push({ href: "/aprovacoes", rotulo: "Aprovar cadastros" });
  }
  if (papel === "administrador") {
    atalhos.push({ href: "/usuarios", rotulo: "Gerenciar usuários" });
  }
  return atalhos;
}
