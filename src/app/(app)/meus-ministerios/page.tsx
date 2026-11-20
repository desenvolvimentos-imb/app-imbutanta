import type { Metadata } from "next";
import Link from "next/link";
import { BotaoCancelarPedido, BotaoPedirEntrada } from "@/components/AcoesPedido";
import { exigirAcesso } from "@/lib/auth/sessao";
import {
  listarMeusPedidos,
  listarMinhasParticipacoes,
  listarMinisteriosAtivos,
  listarParticipantes,
  pedidosRelevantes,
} from "@/lib/ministerios/consultas";

export const metadata: Metadata = { title: "Meus ministérios" };

const ROTULO_PAPEL = { lider: "Líder", participante: "Participante" } as const;

// "Meus ministérios": a tela existe para todos, inclusive para quem não participa de nenhum (RF-033).
export default async function PaginaMeusMinisterios() {
  await exigirAcesso("/meus-ministerios");

  const [participacoes, todosPedidos, ativos] = await Promise.all([
    listarMinhasParticipacoes(),
    listarMeusPedidos(),
    listarMinisteriosAtivos(),
  ]);

  // Quem faz parte de cada ministério (nome e papel; a função do banco nunca devolve email).
  const colegas = await Promise.all(participacoes.map((p) => listarParticipantes(p.ministerio_id)));

  const pedidos = pedidosRelevantes(todosPedidos);
  const participaDe = new Set(participacoes.map((p) => p.ministerio_id));
  const comPendente = new Set(pedidos.filter((p) => p.situacao === "pendente").map((p) => p.ministerio_id));
  const disponiveis = ativos.filter((m) => !participaDe.has(m.id) && !comPendente.has(m.id));

  return (
    <>
      <h1 className="text-2xl font-bold">Meus ministérios</h1>

      {participacoes.length === 0 ? (
        <p className="rounded-lg bg-slate-100 p-4 text-lg">
          Você ainda não participa de nenhum ministério. Peça para entrar em um deles logo abaixo; o líder decide.
        </p>
      ) : (
        participacoes.map((p, i) => (
          <section
            key={p.ministerio_id}
            aria-labelledby={`min-${p.ministerio_id}`}
            className="flex flex-col gap-3 rounded-lg border border-slate-400 p-4"
          >
            <div className="flex items-center justify-between gap-2">
              <h2 id={`min-${p.ministerio_id}`} className="text-lg font-semibold">
                {p.nome}
              </h2>
              <span
                className={`rounded px-2 py-0.5 text-sm font-medium ${p.papel === "lider" ? "bg-blue-100 text-blue-950" : "bg-slate-200 text-slate-800"}`}
              >
                {ROTULO_PAPEL[p.papel]}
              </span>
            </div>
            {p.descricao && <p className="text-base text-slate-800">{p.descricao}</p>}
            <div>
              <p className="text-sm font-medium text-slate-700">Quem faz parte</p>
              <ul className="mt-1 flex flex-col gap-1 text-base">
                {colegas[i].map((c) => (
                  <li key={c.perfil_id}>
                    {c.nome}
                    {c.papel === "lider" && <span className="ml-2 text-sm text-slate-700">(líder)</span>}
                  </li>
                ))}
              </ul>
            </div>
            <Link href={`/ministerios/${p.ministerio_id}`} className="text-base font-semibold text-blue-900 underline">
              Abrir {p.nome}
            </Link>
          </section>
        ))
      )}

      {pedidos.length > 0 && (
        <section aria-labelledby="titulo-meus-pedidos" className="flex flex-col gap-3">
          <h2 id="titulo-meus-pedidos" className="text-lg font-semibold">
            Meus pedidos
          </h2>
          <ul className="flex flex-col gap-3">
            {pedidos.map((p) => (
              <li key={p.id} className="flex flex-col gap-2 rounded-lg border border-slate-400 p-4">
                <div className="flex items-center justify-between gap-2">
                  <span className="text-lg font-semibold">{p.ministerio_nome}</span>
                  <span className="text-base text-slate-800">
                    {p.situacao === "pendente" ? "Aguardando o líder" : "Recusado"}
                  </span>
                </div>
                {p.situacao === "pendente" && (
                  <BotaoCancelarPedido pedidoId={p.id} ministerioId={p.ministerio_id} nome={p.ministerio_nome} />
                )}
              </li>
            ))}
          </ul>
        </section>
      )}

      <section aria-labelledby="titulo-pedir" className="flex flex-col gap-3">
        <h2 id="titulo-pedir" className="text-lg font-semibold">
          Pedir para entrar em outro ministério
        </h2>
        {disponiveis.length === 0 ? (
          <p className="rounded-lg bg-slate-100 p-4 text-base">Não há outros ministérios disponíveis para pedir agora.</p>
        ) : (
          <ul className="flex flex-col gap-3">
            {disponiveis.map((m) => (
              <li key={m.id} className="flex flex-col gap-2 rounded-lg border border-slate-400 p-4">
                <p className="text-lg font-semibold">{m.nome}</p>
                {m.descricao && <p className="text-base text-slate-800">{m.descricao}</p>}
                <BotaoPedirEntrada ministerioId={m.id} nome={m.nome} />
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  );
}
