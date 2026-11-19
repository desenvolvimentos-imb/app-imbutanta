// Páginas públicas (sem exigir login): Política de Privacidade e Termos de Uso.
import Link from "next/link";

export default function LayoutLegal({ children }: { children: React.ReactNode }) {
  return (
    <>
      <header className="border-b border-slate-300 bg-blue-900 px-4 py-3 text-white">
        <div className="mx-auto flex max-w-2xl items-center justify-between">
          <p className="text-lg font-semibold">IM Butantã</p>
          <Link href="/" className="min-h-11 py-2 font-medium underline">
            Voltar ao app
          </Link>
        </div>
      </header>
      <main className="mx-auto w-full max-w-2xl flex-1 px-4 py-6">{children}</main>
    </>
  );
}
