"use client";
// Tela de erro do app: aparece quando algo inesperado falha ao montar uma página (ex.: o banco
// não responde). Mensagem em português, sem texto técnico, e com saída (constituição III).
import { useEffect } from "react";
import { sair } from "@/app/actions/sair";
import { BotaoEnviar } from "@/components/Botao";

export default function ErroDoApp({ error, retry }: { error: unknown; retry: () => void }) {
  useEffect(() => {
    // O detalhe técnico fica no console e nos logs do servidor, nunca na tela.
    console.error(error);
  }, [error]);

  return (
    <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center gap-6 px-4 py-8">
      <p className="text-center text-2xl font-bold text-blue-900">IM Butantã</p>
      <h1 className="text-2xl font-bold">Não foi possível carregar a sua conta</h1>
      <div role="alert" className="flex flex-col gap-3 text-lg">
        <p>Algo falhou do nosso lado ao buscar os seus dados. Isso não é culpa sua.</p>
        <p>Tente de novo. Se continuar, saia e entre outra vez, ou avise a liderança da igreja.</p>
      </div>
      <button
        type="button"
        onClick={() => retry()}
        className="inline-flex min-h-12 w-full items-center justify-center rounded-lg bg-blue-900 px-4 text-base font-semibold text-white hover:bg-blue-800 focus:outline-3 focus:outline-offset-2 focus:outline-blue-700"
      >
        Tentar de novo
      </button>
      <form action={sair}>
        <BotaoEnviar variante="secundario">Sair</BotaoEnviar>
      </form>
    </main>
  );
}
