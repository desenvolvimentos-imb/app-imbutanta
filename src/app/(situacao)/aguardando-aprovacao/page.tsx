import type { Metadata } from "next";
import { TelaSituacao } from "@/components/TelaSituacao";
import { exigirAcesso } from "@/lib/auth/sessao";
import { listarMeusPedidos, listarMinisteriosAtivos } from "@/lib/ministerios/consultas";
import { FormularioPedirMinisterios } from "./formulario";

export const metadata: Metadata = { title: "Aguardando aprovação" };

const ROTULO_SITUACAO = {
  pendente: "Aguardando o líder",
  aceito: "Aceito",
  recusado: "Recusado",
  cancelado: "Cancelado",
} as const;

export default async function PaginaAguardando() {
  const perfil = await exigirAcesso("/aguardando-aprovacao");
  const [pedidos, ativos] = await Promise.all([listarMeusPedidos(), listarMinisteriosAtivos()]);

  // Só oferece os ministérios que ainda não têm pedido pendente.
  const comPedidoPendente = new Set(pedidos.filter((p) => p.situacao === "pendente").map((p) => p.ministerio_id));
  const disponiveis = ativos.filter((m) => !comPedidoPendente.has(m.id));

  return (
    <TelaSituacao titulo="Aguardando aprovação">
      <p>Olá, {perfil.nome}! O seu cadastro foi recebido e está aguardando aprovação.</p>
      <p>Você ainda não tem acesso ao conteúdo do app. Assim que for aprovado, é só abrir o app de novo.</p>
      <p className="text-base">
        A conta é ativada por um administrador ou quando o líder de um ministério que você pediu aceita o seu pedido.
      </p>

      {pedidos.length > 0 && (
        <section aria-labelledby="titulo-pedidos" className="flex flex-col gap-2">
          <h2 id="titulo-pedidos" className="text-lg font-semibold">
            Ministérios que você pediu
          </h2>
          <ul className="flex flex-col gap-2 text-base">
            {pedidos.map((p) => (
              <li key={p.id} className="flex items-center justify-between gap-2 rounded-lg bg-slate-100 p-3">
                <span className="font-medium">{p.ministerio_nome}</span>
                <span className="text-slate-800">{ROTULO_SITUACAO[p.situacao]}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <FormularioPedirMinisterios ministerios={disponiveis} />
    </TelaSituacao>
  );
}
