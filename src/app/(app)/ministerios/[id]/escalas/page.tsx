import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { CartaoEscala } from "@/components/CartaoEscala";
import { classesBotao } from "@/components/estilos-botao";
import { exigirAcesso } from "@/lib/auth/sessao";
import { listarEscalasMinisterio } from "@/lib/escalas/consultas";
import { ehGestorDoMinisterio } from "@/lib/escalas/gestao";
import { listarMinhasParticipacoes, obterMinisterio } from "@/lib/ministerios/consultas";

export const metadata: Metadata = { title: "Escalas do ministério" };

// Em Next.js 16, `params` e `searchParams` são Promises e precisam de await.
export default async function PaginaEscalas({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ passadas?: string }>;
}) {
  const { id } = await params;
  const { passadas } = await searchParams;
  const verPassadas = passadas === "1";
  const perfil = await exigirAcesso(`/ministerios/${id}/escalas`);

  const ministerio = await obterMinisterio(id);
  if (!ministerio) notFound();

  const [escalas, gestor, participacoes] = await Promise.all([
    listarEscalasMinisterio(ministerio.id, verPassadas),
    ehGestorDoMinisterio(perfil, ministerio.id),
    listarMinhasParticipacoes(),
  ]);
  // Quem não participa nem gere o ministério recebe "não encontrado": a tela não revela nada.
  // (O banco já devolve lista vazia a essas pessoas; isto só evita mostrar uma tela vazia.)
  const participa = participacoes.some((p) => p.ministerio_id === ministerio.id);
  if (!gestor && !participa) notFound();

  return (
    <>
      <Link href={`/ministerios/${ministerio.id}`} className="text-base font-medium text-blue-900 underline">
        ← {ministerio.nome}
      </Link>
      <h1 className="text-2xl font-bold">Escalas</h1>

      {gestor && ministerio.ativo && (
        <Link href={`/ministerios/${ministerio.id}/escalas/nova`} className={classesBotao("primario")}>
          Nova escala
        </Link>
      )}

      <nav aria-label="Período" className="grid grid-cols-2 gap-2">
        <Link href={`/ministerios/${ministerio.id}/escalas`} aria-current={verPassadas ? undefined : "page"}
              className={classesBotao(verPassadas ? "secundario" : "primario")}>Próximas</Link>
        <Link href={`/ministerios/${ministerio.id}/escalas?passadas=1`} aria-current={verPassadas ? "page" : undefined}
              className={classesBotao(verPassadas ? "primario" : "secundario")}>Passadas</Link>
      </nav>

      {escalas.length === 0 ? (
        <p className="rounded-lg bg-slate-100 p-4 text-lg">
          {verPassadas ? "Nenhuma escala passada." : "Nenhuma escala próxima."}
        </p>
      ) : (
        <ul className="flex flex-col gap-3">
          {escalas.map((e) => (
            <CartaoEscala key={e.id} ministerioId={ministerio.id} escala={e} />
          ))}
        </ul>
      )}
    </>
  );
}
