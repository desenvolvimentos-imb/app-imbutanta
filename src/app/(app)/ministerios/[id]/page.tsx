import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { AcaoComConfirmacao } from "@/components/AcaoComConfirmacao";
import { BotaoPedirEntrada } from "@/components/AcoesPedido";
import { exigirAcesso } from "@/lib/auth/sessao";
import { BuscaPessoa } from "@/components/BuscaPessoa";
import { ListaParticipantes } from "@/components/ListaParticipantes";
import { PedidosDeEntrada } from "@/app/(app)/aprovacoes/pedidos";
import {
  buscarPessoas,
  idsDosMinisteriosQueLidero,
  listarMeusPedidos,
  listarMinhasParticipacoes,
  listarParticipantes,
  listarPedidosPendentes,
  listarPessoasAprovadas,
  obterMinisterio,
} from "@/lib/ministerios/consultas";
import { FormularioEditarMinisterio, FormularioReativarMinisterio } from "./formularios";
import { desativarMinisterio } from "./actions";

export const metadata: Metadata = { title: "Ministério" };

// Em Next.js 16, `params` é uma Promise e precisa de await.
export default async function PaginaMinisterio({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ busca?: string }>;
}) {
  const { id } = await params;
  const { busca = "" } = await searchParams;
  const perfil = await exigirAcesso(`/ministerios/${id}`);

  // A RLS só entrega ministério desativado ao administrador; para os demais, "não encontrado".
  const ministerio = await obterMinisterio(id);
  if (!ministerio) notFound();

  const ehAdmin = perfil.papel === "administrador";
  const pessoas = ehAdmin && !ministerio.ativo ? await listarPessoasAprovadas() : [];

  // Gere quem é administrador ou líder DESTE ministério ativo (o banco confere de novo em cada ação).
  const lidero = perfil.lidera ? (await idsDosMinisteriosQueLidero()).includes(ministerio.id) : false;
  const podeGerir = ministerio.ativo && (ehAdmin || lidero);

  // O banco só devolve a lista a administrador, líder e participantes deste ministério.
  const participantes = await listarParticipantes(ministerio.id);
  const resultados = podeGerir ? await buscarPessoas(ministerio.id, busca) : [];
  // Pedidos de entrada pendentes DESTE ministério, para quem gere (o banco só entrega a quem pode).
  const pedidosDoMinisterio = podeGerir
    ? (await listarPedidosPendentes()).filter((p) => p.ministerio_id === ministerio.id)
    : [];

  // Situação da própria pessoa neste ministério: participa, já pediu ou pode pedir.
  const [minhasParticipacoes, meusPedidos] = await Promise.all([listarMinhasParticipacoes(), listarMeusPedidos()]);
  const participa = minhasParticipacoes.some((p) => p.ministerio_id === ministerio.id);
  const pedidoPendente = meusPedidos.find((p) => p.ministerio_id === ministerio.id && p.situacao === "pendente");

  return (
    <>
      <h1 className="text-2xl font-bold">{ministerio.nome}</h1>
      {ministerio.descricao && <p className="text-lg text-slate-800">{ministerio.descricao}</p>}

      {!ministerio.ativo && (
        <p role="status" className="rounded-lg border border-slate-500 bg-slate-100 p-3 text-base">
          Ministério desativado
          {ministerio.desativado_em && (
            <>
              {" "}
              em{" "}
              {new Intl.DateTimeFormat("pt-BR", { dateStyle: "short", timeZone: "America/Sao_Paulo" }).format(
                new Date(ministerio.desativado_em),
              )}
            </>
          )}
          . O histórico foi preservado.
        </p>
      )}

      {ministerio.ativo && !participa && (
        <section aria-labelledby="titulo-entrar" className="flex flex-col gap-3">
          <h2 id="titulo-entrar" className="text-lg font-semibold">
            Participar deste ministério
          </h2>
          {pedidoPendente ? (
            <p role="status" className="rounded-lg bg-slate-100 p-3 text-base">
              Você já pediu para entrar. Aguardando a decisão do líder.
            </p>
          ) : (
            <BotaoPedirEntrada ministerioId={ministerio.id} nome={ministerio.nome} />
          )}
        </section>
      )}

      {podeGerir && (
        <section aria-labelledby="titulo-pedidos-ministerio" className="flex flex-col gap-3">
          <h2 id="titulo-pedidos-ministerio" className="text-lg font-semibold">
            Pedidos de entrada ({pedidosDoMinisterio.length})
          </h2>
          <PedidosDeEntrada pedidos={pedidosDoMinisterio} />
        </section>
      )}

      {participantes.length > 0 || podeGerir ? (
        <section aria-labelledby="titulo-participantes" className="flex flex-col gap-4">
          <h2 id="titulo-participantes" className="text-lg font-semibold">
            Participantes ({participantes.length})
          </h2>
          <ListaParticipantes ministerioId={ministerio.id} participantes={participantes} podeGerir={podeGerir} />
          {podeGerir && <BuscaPessoa ministerioId={ministerio.id} termo={busca} resultados={resultados} />}
        </section>
      ) : null}

      {ehAdmin && (
        <section aria-labelledby="titulo-administrar" className="flex flex-col gap-4">
          <h2 id="titulo-administrar" className="text-lg font-semibold">
            Administrar ministério
          </h2>
          <FormularioEditarMinisterio ministerio={ministerio} />
          {ministerio.ativo ? (
            <AcaoComConfirmacao
              rotulo="Desativar ministério"
              rotuloConfirmar="Confirmar desativação"
              aviso="O ministério sai da lista de ativos e deixa de receber pedidos. Participantes e histórico continuam registrados."
              acao={desativarMinisterio}
              campos={{ id: ministerio.id }}
            />
          ) : (
            <FormularioReativarMinisterio id={ministerio.id} pessoas={pessoas} />
          )}
        </section>
      )}
    </>
  );
}
