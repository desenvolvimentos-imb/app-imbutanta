import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { FormularioConsulta } from "@/components/FormularioConsulta";
import { exigirAcesso } from "@/lib/auth/sessao";
import { hoje } from "@/lib/disponibilidade/datas";
import { ehGestorDoMinisterio } from "@/lib/escalas/gestao";
import { obterMinisterio } from "@/lib/ministerios/consultas";
import { criarConsulta } from "../acoes";

export const metadata: Metadata = { title: "Nova consulta de disponibilidade" };

export default async function PaginaNovaConsulta({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const perfil = await exigirAcesso(`/ministerios/${id}/disponibilidade/nova`);
  const ministerio = await obterMinisterio(id);
  if (!ministerio || !ministerio.ativo || !(await ehGestorDoMinisterio(perfil, ministerio.id))) notFound();

  return (
    <>
      <Link href={`/ministerios/${ministerio.id}/disponibilidade`} className="text-base font-medium text-blue-900 underline">
        ← Disponibilidade
      </Link>
      <h1 className="text-2xl font-bold">Nova consulta</h1>
      <p className="text-base text-slate-800">
        Os participantes de {ministerio.nome} marcarão em quais datas podem ser escalados. A consulta nasce aberta.
      </p>
      <FormularioConsulta acao={criarConsulta} ministerioId={ministerio.id} hoje={hoje()} rotuloBotao="Criar consulta" />
    </>
  );
}
