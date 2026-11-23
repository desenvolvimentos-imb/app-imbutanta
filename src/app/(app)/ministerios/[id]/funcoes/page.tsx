import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { EditorAptidoes } from "@/components/EditorAptidoes";
import { EditorFuncoes } from "@/components/EditorFuncoes";
import { exigirAcesso } from "@/lib/auth/sessao";
import { listarAptidoes, listarFuncoes } from "@/lib/escalas/consultas";
import { ehGestorDoMinisterio } from "@/lib/escalas/gestao";
import { listarParticipantes, obterMinisterio } from "@/lib/ministerios/consultas";

export const metadata: Metadata = { title: "Funções e aptidões" };

// Em Next.js 16, `params` é uma Promise e precisa de await.
export default async function PaginaFuncoes({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const perfil = await exigirAcesso(`/ministerios/${id}/funcoes`);

  // Quem não gere este ministério (inclusive quem nem participa) recebe "não encontrado": a tela
  // não revela nem que o ministério existe. O banco confere de novo em cada ação.
  const ministerio = await obterMinisterio(id);
  if (!ministerio || !(await ehGestorDoMinisterio(perfil, ministerio.id))) notFound();

  const [funcoes, aptidoes, participantes] = await Promise.all([
    listarFuncoes(ministerio.id, true),
    listarAptidoes(ministerio.id),
    listarParticipantes(ministerio.id),
  ]);

  return (
    <>
      <Link href={`/ministerios/${ministerio.id}`} className="text-base font-medium text-blue-900 underline">
        ← {ministerio.nome}
      </Link>
      <h1 className="text-2xl font-bold">Funções e aptidões</h1>
      {!ministerio.ativo && (
        <p role="status" className="rounded-lg border border-slate-500 bg-slate-100 p-3 text-base">
          Ministério desativado: não é possível alterar funções nem aptidões.
        </p>
      )}

      <section aria-labelledby="titulo-funcoes" className="flex flex-col gap-4">
        <h2 id="titulo-funcoes" className="text-lg font-semibold">Funções do ministério</h2>
        {ministerio.ativo ? (
          <EditorFuncoes ministerioId={ministerio.id} funcoes={funcoes} />
        ) : (
          <ul className="flex flex-col gap-2">
            {funcoes.map((f) => <li key={f.id} className="rounded-lg border border-slate-400 p-3 text-lg">{f.nome}</li>)}
          </ul>
        )}
      </section>

      {ministerio.ativo && (
        <section aria-labelledby="titulo-aptidoes" className="flex flex-col gap-4">
          <h2 id="titulo-aptidoes" className="text-lg font-semibold">Aptidões dos participantes</h2>
          <p className="text-base text-slate-800">
            Marque em quais funções cada pessoa é apta. &quot;Principal&quot; e &quot;secundária&quot; são só informação para você:
            as duas contam como apta.
          </p>
          <EditorAptidoes ministerioId={ministerio.id} participantes={participantes} funcoes={funcoes} aptidoes={aptidoes} />
        </section>
      )}
    </>
  );
}
