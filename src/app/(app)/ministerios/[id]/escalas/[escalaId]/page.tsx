import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { AcaoComConfirmacao } from "@/components/AcaoComConfirmacao";
import { BotoesResposta } from "@/components/BotoesResposta";
import { SeloResposta } from "@/components/SeloResposta";
import { SeloSituacao } from "@/components/CartaoEscala";
import { EditorVagas } from "@/components/EditorVagas";
import { FormularioEscala } from "@/components/FormularioEscala";
import { FormularioPedidoTroca } from "@/components/FormularioPedidoTroca";
import { ListaVagas } from "@/components/ListaVagas";
import { SeloTroca } from "@/components/SeloTroca";
import { PublicarEscala } from "@/components/PublicarEscala";
import { exigirAcesso } from "@/lib/auth/sessao";
import { disponibilidadeDaEscala } from "@/lib/disponibilidade/consultas";
import {
  lerEscala, listarCandidatasTroca, listarCandidatos, listarFuncoes, listarPedidosDaEscala,
} from "@/lib/escalas/consultas";
import { formatarDataHora } from "@/lib/escalas/datas";
import { cancelarEscala, editarEscala } from "../acoes";

export const metadata: Metadata = { title: "Escala" };

// Em Next.js 16, `params` é uma Promise e precisa de await.
export default async function PaginaEscala({ params }: { params: Promise<{ id: string; escalaId: string }> }) {
  const { id, escalaId } = await params;
  await exigirAcesso(`/ministerios/${id}/escalas/${escalaId}`);

  // O banco só entrega a escala a quem pode vê-la; para os demais é "não encontrado".
  const detalhe = await lerEscala(escalaId);
  if (!detalhe || detalhe.escala.ministerio_id !== id) notFound();

  const { escala } = detalhe;
  const gestor = detalhe.papel === "gestor";
  const editavel = gestor && escala.ministerio_ativo && escala.situacao !== "cancelada" && !detalhe.somente_leitura;

  const minhasVagas = detalhe.vagas.filter((v) => v.minha);
  const [pedidos, candidatasTroca] = await Promise.all([
    listarPedidosDaEscala(escalaId),
    detalhe.pode_pedir_troca && minhasVagas.length > 0 ? listarCandidatasTroca(minhasVagas[0].id) : Promise.resolve([]),
  ]);

  // Só o gestor vê a disponibilidade das pessoas na data da escala (004, RF-028 a RF-030). Fica vazio
  // quando a data não pertence a nenhuma consulta do ministério: então nada é mostrado.
  const disponibilidade = gestor ? Object.fromEntries(await disponibilidadeDaEscala(escalaId)) : {};

  const [funcoes, candidatos] = editavel
    ? await Promise.all([listarFuncoes(id, true), listarCandidatos(escalaId)])
    : [[], []];

  return (
    <>
      <Link href={`/ministerios/${id}/escalas`} className="text-base font-medium text-blue-900 underline">
        ← Escalas
      </Link>
      <div className="flex items-start justify-between gap-2">
        <h1 className="text-2xl font-bold">{escala.evento}</h1>
        <SeloSituacao situacao={escala.situacao} />
      </div>
      <p className="text-lg">{formatarDataHora(escala.data, escala.horario)}</p>
      <p className="text-base text-slate-800">{escala.ministerio}</p>
      {escala.observacao && <p className="text-base">{escala.observacao}</p>}

      {escala.situacao === "cancelada" && (
        <p role="status" className="rounded-lg border border-red-800 bg-red-50 p-3 text-base text-red-950">
          Esta escala foi cancelada.
        </p>
      )}
      {escala.situacao !== "cancelada" && detalhe.somente_leitura && (
        <p role="status" className="rounded-lg border border-slate-500 bg-slate-100 p-3 text-base">
          Escala encerrada: não pode mais ser alterada.
        </p>
      )}
      {escala.situacao === "rascunho" && gestor && (
        <p role="status" className="rounded-lg border border-slate-500 bg-slate-100 p-3 text-base">
          Rascunho: só você e os administradores veem esta escala. Publique quando estiver pronta.
        </p>
      )}

      {editavel && (
        <section aria-labelledby="titulo-dados" className="flex flex-col gap-4">
          <h2 id="titulo-dados" className="text-lg font-semibold">Dados da escala</h2>
          <FormularioEscala
            acao={editarEscala}
            ministerioId={id}
            escalaId={escala.id}
            inicial={{ evento: escala.evento, data: escala.data, horario: escala.horario, observacao: escala.observacao }}
            rotuloBotao="Salvar alterações"
            avisoRespostas={escala.situacao === "publicada"}
          />
        </section>
      )}

      {detalhe.minha_resposta && escala.situacao !== "cancelada" && (
        <section aria-labelledby="titulo-minha-resposta" className="flex flex-col gap-3 rounded-lg border border-blue-900 p-4">
          <h2 id="titulo-minha-resposta" className="text-lg font-semibold">Sua participação</h2>
          <div><SeloResposta resposta={detalhe.minha_resposta.resposta} /></div>
          {detalhe.minha_resposta.resposta === "recusado" && detalhe.minha_resposta.motivo && (
            <p className="text-base text-slate-800">Motivo: {detalhe.minha_resposta.motivo}</p>
          )}
          {detalhe.pode_responder ? (
            <BotoesResposta escalaId={escala.id} ministerioId={id} evento={escala.evento} atual={detalhe.minha_resposta.resposta} />
          ) : (
            detalhe.iniciada && <p className="text-base text-slate-800">O horário de início já passou: a resposta não pode mais ser mudada.</p>
          )}
        </section>
      )}

      {detalhe.pode_pedir_troca && minhasVagas.length > 0 && (
        <section aria-labelledby="titulo-troca" className="flex flex-col gap-3">
          <h2 id="titulo-troca" className="text-lg font-semibold">Não vai poder ir?</h2>
          <p className="text-base text-slate-800">
            Peça que outra pessoa do ministério assuma a vaga. A pessoa aceita e o líder aprova; até lá, nada muda na escala.
          </p>
          <ul className="flex flex-col gap-3">
            {minhasVagas.map((v) => {
              const nomeVaga = `${v.funcao}${v.rotulo ? ` · ${v.rotulo}` : ""}`;
              const pedido = pedidos.find((p) => p.vaga_id === v.id && p.solicitante_id === v.pessoa?.id);
              return (
                <li key={v.id} className="flex flex-col gap-2 rounded-lg border border-slate-400 p-3">
                  <p className="text-base font-semibold">{nomeVaga}</p>
                  {pedido ? (
                    <>
                      <p className="text-base">Pedido para {pedido.indicada}.</p>
                      <div><SeloTroca situacao={pedido.situacao} /></div>
                      <p className="text-sm text-slate-800">Acompanhe e cancele em &quot;Pedidos de troca&quot;.</p>
                    </>
                  ) : (
                    <FormularioPedidoTroca vagaId={v.id} escalaId={escala.id} ministerioId={id} nomeVaga={nomeVaga} candidatas={candidatasTroca} />
                  )}
                </li>
              );
            })}
          </ul>
        </section>
      )}

      <section aria-labelledby="titulo-vagas" className="flex flex-col gap-4">
        <h2 id="titulo-vagas" className="text-lg font-semibold">Vagas</h2>
        {editavel ? (
          <EditorVagas ministerioId={id} escalaId={escala.id} vagas={detalhe.vagas} funcoes={funcoes} candidatos={candidatos} disponibilidade={disponibilidade} />
        ) : (
          <ListaVagas vagas={detalhe.vagas} disponibilidade={disponibilidade} />
        )}
      </section>

      {editavel && (
        <section aria-labelledby="titulo-situacao" className="flex flex-col gap-4">
          <h2 id="titulo-situacao" className="text-lg font-semibold">Publicação</h2>
          {escala.situacao === "rascunho" && <PublicarEscala ministerioId={id} escalaId={escala.id} vagasEmAberto={detalhe.vagas.filter((v) => v.em_aberto).length} />}
          <AcaoComConfirmacao
            rotulo="Cancelar escala"
            rotuloConfirmar="Confirmar cancelamento"
            aviso="A escala não é apagada: continua visível para quem estava escalado, marcada como cancelada. Pedidos de troca em andamento perdem efeito."
            acao={cancelarEscala}
            campos={{ ministerio: id, escala: escala.id }}
          />
        </section>
      )}
    </>
  );
}
