// Telas sem login: entrar, cadastrar, recuperar e redefinir senha.
// Layout centralizado, pensado para celular.
export default function LayoutPublico({ children }: { children: React.ReactNode }) {
  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center gap-6 px-4 py-8">
      <p className="text-center text-2xl font-bold text-blue-900">Imbutanta</p>
      {children}
    </main>
  );
}
