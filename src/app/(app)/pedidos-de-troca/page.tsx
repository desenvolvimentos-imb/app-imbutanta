import type { Metadata } from "next";
import { CartaoPedidoTroca } from "@/components/CartaoPedidoTroca";
import { exigirAcesso } from "@/lib/auth/sessao";
import { listarPedidosTroca, type PedidoTroca } from "@/lib/escalas/consultas";

export const metadata: Metadata = { title: "Pedidos de troca" };

const PENDENTE = ["aguardando_indicada", "aguardando_lider"];

function Bloco({ id, titulo, vazio, pedidos }: { id: string; titulo: string; vazio: string; pedidos: PedidoTroca[] }) {
  return (
    <section aria-labelledby={id} className="flex flex-col gap-3">
      <h2 id={id} className="text-lg font-semibold">{titulo} ({pedidos.length})</h2>
      {pedidos.length === 0 ? (
        <p className="rounded-lg bg-slate-100 p-4 text-base">{vazio}</p>
      ) : (
        <ul className="flex flex-col gap-3">{pedidos.map((p) => <CartaoPedidoTroca key={p.id} pedido={p} />)}</ul>
      )}
    </section>
  );
}

// "Pedidos de troca": os que a pessoa recebeu, os que fez e, para quem gere ministérios, os que
// aguardam a sua aprovação (FR-036). A tela existe para todos, inclusive sem nenhum pedido.
export default async function PaginaPedidosDeTroca() {
  const perfil = await exigirAcesso("/pedidos-de-troca");
  const todos = await listarPedidosTroca();

  const aAprovar = todos.filter((p) => p.pode_decidir);
  const recebidos = todos.filter((p) => !p.pode_decidir && p.pode_responder);
  const feitos = todos.filter((p) => !p.pode_decidir && !p.pode_responder && p.papel_na_lista === "solicitante" && PENDENTE.includes(p.situacao));
  const jaTratados = new Set([...aAprovar, ...recebidos, ...feitos].map((p) => p.id));
  const historico = todos.filter((p) => !jaTratados.has(p.id));
  const gestor = aAprovar.length > 0 || perfil.papel === "administrador" || perfil.lidera;

  return (
    <>
      <h1 className="text-2xl font-bold">Pedidos de troca</h1>
      {gestor && (
        <Bloco id="titulo-aprovar" titulo="Aguardando minha aprovação" vazio="Nenhum pedido aguardando a sua aprovação." pedidos={aAprovar} />
      )}
      <Bloco id="titulo-recebidos" titulo="Recebidos" vazio="Ninguém pediu que você assuma uma vaga." pedidos={recebidos} />
      <Bloco id="titulo-feitos" titulo="Feitos" vazio="Você não tem pedidos de troca em andamento." pedidos={feitos} />
      {historico.length > 0 && <Bloco id="titulo-historico" titulo="Histórico" vazio="" pedidos={historico} />}
    </>
  );
}
