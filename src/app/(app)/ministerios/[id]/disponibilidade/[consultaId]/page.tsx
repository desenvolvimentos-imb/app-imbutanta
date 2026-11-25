import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { AcoesConsulta } from "@/components/AcoesConsulta";
import { FormularioAdicionarDatas } from "@/components/FormularioAdicionarDatas";
import { FormularioConsulta } from "@/components/FormularioConsulta";
import { GradeDisponibilidade } from "@/components/GradeDisponibilidade";
import { PreencherResposta } from "@/components/PreencherResposta";
import { RemoverData } from "@/components/RemoverData";
import { SeloConsulta } from "@/components/SeloDisponibilidade";
import { exigirAcesso } from "@/lib/auth/sessao";
import { lerConsultaGestor } from "@/lib/disponibilidade/consultas";
import { formatarDataCompleta, formatarDataConsulta, hoje, prazoVencido } from "@/lib/disponibilidade/datas";
import { adicionarDatas, editarConsulta, fecharConsulta, preencherResposta, reabrirConsulta, removerData } from "../acoes";

export const metadata: Metadata = { title: "Consulta de disponibilidade" };

// Grade e gestão de uma consulta. A leitura é por função do banco: quem não é líder do ministério
// (nem administrador) recebe nulo, e a tela mostra "não encontrado" sem revelar nada.
export default async function PaginaConsulta({ params }: { params: Promise<{ id: string; consultaId: string }> }) {
  const { id, consultaId } = await params;
  await exigirAcesso(`/ministerios/${id}/disponibilidade/${consultaId}`);
  const grade = await lerConsultaGestor(consultaId);
  if (!grade || grade.consulta.ministerio_id !== id) notFound();

  const { consulta } = grade;
  const hojeSp = hoje();
  const aberta = consulta.aberta;
  const ministerioAtivo = consulta.ministerio_ativo;

  return (
    <>
      <Link href={`/ministerios/${id}/disponibilidade`} className="text-base font-medium text-blue-900 underline">
        ← Disponibilidade
      </Link>
      <div className="flex flex-wrap items-start justify-between gap-2">
        <h1 className="text-2xl font-bold">{consulta.titulo}</h1>
        <SeloConsulta aberta={aberta} motivo={consulta.motivo_fechada} />
      </div>
      <p className="text-base text-slate-800">
        {consulta.ministerio}
        {consulta.prazo && ` · prazo ${formatarDataCompleta(consulta.prazo)}`}
      </p>
      {consulta.mensagem && <p className="rounded-lg bg-slate-50 p-3 text-base">{consulta.mensagem}</p>}

      <GradeDisponibilidade grade={grade} hrefFuncoes={`/ministerios/${id}/funcoes`} podeCorrigir={ministerioAtivo} />

      <section aria-labelledby="titulo-preencher" className="flex flex-col gap-3">
        <h2 id="titulo-preencher" className="text-lg font-semibold">Preencher ou corrigir respostas</h2>
        <p className="text-base text-slate-800">Para quem respondeu por outro meio. Vale também com a consulta fechada.</p>
        {ministerioAtivo ? (
          <div className="flex flex-col gap-3">
            {grade.participantes.map((p) => (
              <PreencherResposta key={p.perfil_id} acao={preencherResposta} ministerioId={id} consultaId={consulta.id}
                                 datas={grade.datas} pessoa={p} />
            ))}
          </div>
        ) : (
          <p className="rounded-lg bg-slate-100 p-3 text-base">O ministério está desativado: as respostas não podem mais ser alteradas.</p>
        )}
      </section>

      {ministerioAtivo && (
        <section aria-labelledby="titulo-situacao" className="flex flex-col gap-3">
          <h2 id="titulo-situacao" className="text-lg font-semibold">{aberta ? "Situação" : "Reabrir"}</h2>
          <AcoesConsulta ministerioId={id} consultaId={consulta.id} aberta={aberta}
                         prazoVencido={prazoVencido(consulta.prazo, hojeSp)} hoje={hojeSp}
                         fechar={fecharConsulta} reabrir={reabrirConsulta} />
        </section>
      )}

      {ministerioAtivo && aberta && (
        <>
          <section aria-labelledby="titulo-editar" className="flex flex-col gap-3">
            <h2 id="titulo-editar" className="text-lg font-semibold">Editar consulta</h2>
            <FormularioConsulta acao={editarConsulta} ministerioId={id} consultaId={consulta.id} hoje={hojeSp}
                                inicial={{ titulo: consulta.titulo, mensagem: consulta.mensagem, prazo: consulta.prazo }}
                                rotuloBotao="Salvar alterações" />
          </section>

          <section aria-labelledby="titulo-datas" className="flex flex-col gap-3">
            <h2 id="titulo-datas" className="text-lg font-semibold">Datas</h2>
            <ul className="flex flex-col gap-3">
              {grade.datas.map((d) => (
                <li key={d.id} className="flex flex-col gap-2 rounded-lg border border-slate-400 p-3">
                  <p className="text-base font-semibold">
                    {formatarDataConsulta(d.data)}
                    {d.rotulo && <span className="font-normal text-slate-800"> · {d.rotulo}</span>}
                  </p>
                  {grade.datas.length > 1 && (
                    <RemoverData acao={removerData} ministerioId={id} consultaId={consulta.id} dataId={d.id} data={d.data} />
                  )}
                </li>
              ))}
            </ul>
            <FormularioAdicionarDatas acao={adicionarDatas} ministerioId={id} consultaId={consulta.id}
                                      hoje={hojeSp} totalDatas={grade.datas.length} />
          </section>
        </>
      )}
    </>
  );
}
