// Molde das telas "logado, mas sem acesso a conteúdo" (aguardando, recusado, acesso removido).
import { BotaoSair } from "./BotaoSair";
import { ExcluirConta } from "./ExcluirConta";

export function TelaSituacao({ titulo, children, rodape }: { titulo: string; children: React.ReactNode; rodape?: React.ReactNode }) {
  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center gap-6 px-4 py-8">
      <p className="text-center text-2xl font-bold text-blue-900">Imbutanta</p>
      <h1 className="text-2xl font-bold">{titulo}</h1>
      <div className="flex flex-col gap-3 text-lg">{children}</div>
      {rodape}
      <BotaoSair />
      {/* Direito da LGPD: vale em qualquer situação da conta. */}
      <ExcluirConta />
    </main>
  );
}
