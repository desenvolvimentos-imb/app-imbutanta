import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { FormularioResposta } from "@/components/FormularioResposta";
import { SeloConsulta } from "@/components/SeloDisponibilidade";
import { exigirAcesso } from "@/lib/auth/sessao";
import { lerConsultaParticipante } from "@/lib/disponibilidade/consultas";
import { formatarDataCompleta } from "@/lib/disponibilidade/datas";
import { salvarRespostas } from "../acoes";

export const metadata: Metadata = { title: "Responder disponibilidade" };

// Quem não participa do ministério da consulta recebe nulo do banco: "não encontrado".
export default async function PaginaResponder({ params }: { params: Promise<{ consultaId: string }> }) {
  const { consultaId } = await params;
  await exigirAcesso(`/disponibilidade/${consultaId}`);
  const consulta = await lerConsultaParticipante(consultaId);
  if (!consulta) notFound();

  return (
    <>
      <Link href="/disponibilidade" className="text-base font-medium text-blue-900 underline">← Disponibilidade</Link>
      <div className="flex flex-wrap items-start justify-between gap-2">
        <h1 className="text-2xl font-bold">{consulta.titulo}</h1>
        <SeloConsulta aberta={consulta.aberta} motivo={consulta.motivo_fechada} />
      </div>
      <p className="text-base text-slate-800">
        {consulta.ministerio}
        {consulta.prazo && ` · responda até ${formatarDataCompleta(consulta.prazo)}`}
      </p>
      {consulta.mensagem && <p className="rounded-lg bg-slate-50 p-3 text-base">{consulta.mensagem}</p>}
      {!consulta.aberta && (
        <p role="status" className="rounded-lg border border-slate-600 bg-slate-100 p-3 text-base font-medium">
          Esta consulta está fechada. Você vê suas respostas, mas não pode alterá-las.
        </p>
      )}
      <FormularioResposta consulta={consulta} acao={salvarRespostas} />
    </>
  );
}
