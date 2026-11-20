import type { Metadata } from "next";
import { exigirAcesso } from "@/lib/auth/sessao";
import { listarPedidosPendentes } from "@/lib/ministerios/consultas";
import { criarClienteServidor } from "@/lib/supabase/server";
import { FilaDeAprovacao, type Pendente } from "./fila";
import { PedidosDeEntrada } from "./pedidos";

export const metadata: Metadata = { title: "Pedidos e aprovações" };

export default async function PaginaAprovacoes() {
  // Administrador e quem lidera ministério. O banco também só entrega os dados a quem pode.
  const perfil = await exigirAcesso("/aprovacoes");
  const ehAdmin = perfil.papel === "administrador";

  // Pedidos de entrada: administrador vê todos; líder, só os dos ministérios que lidera.
  const pedidos = await listarPedidosPendentes();

  // Cadastros pendentes (contas sem decisão): só o administrador aprova ou recusa a conta em si.
  let cadastros: Pendente[] = [];
  if (ehAdmin) {
    const supabase = await criarClienteServidor();
    const { data } = await supabase
      .from("perfis")
      .select("id, nome, criado_em")
      .eq("situacao", "pendente")
      .eq("email_verificado", true) // quem não confirmou o email ainda não entra na fila
      .order("criado_em", { ascending: true });
    cadastros = (data ?? []) as Pendente[];
  }

  return (
    <>
      <h1 className="text-2xl font-bold">Pedidos e aprovações</h1>

      <section aria-labelledby="titulo-pedidos" className="flex flex-col gap-3">
        <h2 id="titulo-pedidos" className="text-lg font-semibold">
          Pedidos de entrada
        </h2>
        <PedidosDeEntrada pedidos={pedidos} />
      </section>

      {ehAdmin && (
        <section aria-labelledby="titulo-cadastros" className="flex flex-col gap-3">
          <h2 id="titulo-cadastros" className="text-lg font-semibold">
            Cadastros pendentes
          </h2>
          <p className="text-base text-slate-800">
            Contas novas que ainda não foram aprovadas. Quem pediu ministério também pode ser ativado pelo líder.
          </p>
          <FilaDeAprovacao pendentes={cadastros} />
        </section>
      )}
    </>
  );
}
