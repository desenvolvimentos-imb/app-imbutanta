import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { FormularioEscala } from "@/components/FormularioEscala";
import { exigirAcesso } from "@/lib/auth/sessao";
import { ehGestorDoMinisterio } from "@/lib/escalas/gestao";
import { obterMinisterio } from "@/lib/ministerios/consultas";
import { criarEscala } from "../acoes";

export const metadata: Metadata = { title: "Nova escala" };

export default async function PaginaNovaEscala({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const perfil = await exigirAcesso(`/ministerios/${id}/escalas/nova`);

  const ministerio = await obterMinisterio(id);
  if (!ministerio || !ministerio.ativo || !(await ehGestorDoMinisterio(perfil, ministerio.id))) notFound();

  return (
    <>
      <Link href={`/ministerios/${ministerio.id}/escalas`} className="text-base font-medium text-blue-900 underline">
        ← Escalas
      </Link>
      <h1 className="text-2xl font-bold">Nova escala</h1>
      <p className="text-base text-slate-800">
        A escala nasce como rascunho: só você e os administradores a veem até você publicá-la.
      </p>
      <FormularioEscala acao={criarEscala} ministerioId={ministerio.id} rotuloBotao="Criar escala" />
    </>
  );
}
