"use client";
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { Campo } from "@/components/Campo";
import { MensagemErro } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { PessoaAprovada } from "@/lib/ministerios/consultas";
import { criarMinisterio } from "./actions";

export function FormularioNovoMinisterio({ pessoas }: { pessoas: PessoaAprovada[] }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(criarMinisterio, {});
  const erroLider = estado.erros?.lider;

  return (
    <form action={acao} noValidate className="flex flex-col gap-4">
      <MensagemErro texto={estado.erro} />
      <Campo nome="nome" rotulo="Nome do ministério" erro={estado.erros?.nome} defaultValue={estado.valores?.nome} maxLength={60} />
      <Campo
        nome="descricao"
        rotulo="Descrição curta"
        obrigatorio={false}
        dica="Opcional, até 200 caracteres."
        erro={estado.erros?.descricao}
        defaultValue={estado.valores?.descricao}
        maxLength={200}
      />
      <div className="flex flex-col gap-1">
        <label htmlFor="lider" className="text-base font-medium text-slate-900">
          Líder inicial
        </label>
        <select
          id="lider"
          name="lider"
          defaultValue={estado.valores?.lider ?? ""}
          aria-invalid={erroLider ? true : undefined}
          aria-describedby={erroLider ? "lider-erro" : "lider-dica"}
          className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base text-slate-900 focus:outline-3 focus:outline-offset-2 focus:outline-blue-700"
        >
          <option value="">Escolha uma pessoa</option>
          {pessoas.map((p) => (
            <option key={p.id} value={p.id}>
              {p.nome}
            </option>
          ))}
        </select>
        <p id="lider-dica" className="text-sm text-slate-700">
          Todo ministério precisa de pelo menos um líder desde o início.
        </p>
        {erroLider && (
          <p id="lider-erro" className="text-sm font-medium text-red-800">
            {erroLider}
          </p>
        )}
      </div>
      <BotaoEnviar>Criar ministério</BotaoEnviar>
    </form>
  );
}
