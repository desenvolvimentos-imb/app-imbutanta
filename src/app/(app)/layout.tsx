// Área do app: exige conta APROVADA. Quem está pendente, recusado ou sem acesso é levado
// à tela da própria situação (RF-008, RF-024). Permissões por papel ficam em cada página
// (exigirAcesso) e, de verdade, no banco.
import { Cabecalho, NavegacaoInferior } from "@/components/Cabecalho";
import { exigirAcesso } from "@/lib/auth/sessao";

export default async function LayoutApp({ children }: { children: React.ReactNode }) {
  const perfil = await exigirAcesso("/inicio");
  return (
    <>
      <Cabecalho />
      <main className="mx-auto flex w-full max-w-xl flex-1 flex-col gap-4 px-4 py-6 md:order-3">{children}</main>
      <NavegacaoInferior papel={perfil.papel} lidera={perfil.lidera} />
    </>
  );
}
