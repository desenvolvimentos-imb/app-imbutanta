"use client";
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { Campo } from "@/components/Campo";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { Ministerio, PessoaAprovada } from "@/lib/ministerios/consultas";
import { editarMinisterio, reativarMinisterio } from "./actions";

export function FormularioEditarMinisterio({ ministerio }: { ministerio: Ministerio }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(editarMinisterio, {});
  return (
    <form action={acao} noValidate className="flex flex-col gap-4">
      <MensagemErro texto={estado.erro} />
      <MensagemInfo texto={estado.info} />
      <input type="hidden" name="id" value={ministerio.id} />
      <Campo
        nome="nome"
        rotulo="Nome do ministério"
        erro={estado.erros?.nome}
        defaultValue={estado.valores?.nome ?? ministerio.nome}
        maxLength={60}
      />
      <Campo
        nome="descricao"
        rotulo="Descrição curta"
        obrigatorio={false}
        erro={estado.erros?.descricao}
        defaultValue={estado.valores?.descricao ?? ministerio.descricao}
        maxLength={200}
      />
      <BotaoEnviar variante="secundario">Salvar alterações</BotaoEnviar>
    </form>
  );
}

export function FormularioReativarMinisterio({ id, pessoas }: { id: string; pessoas: PessoaAprovada[] }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(reativarMinisterio, {});
  return (
    <form action={acao} className="flex flex-col gap-3">
      <MensagemErro texto={estado.erro} />
      <input type="hidden" name="id" value={id} />
      <div className="flex flex-col gap-1">
        <label htmlFor="lider" className="text-base font-medium text-slate-900">
          Líder (só é necessário se o ministério ficou sem líder)
        </label>
        <select
          id="lider"
          name="lider"
          defaultValue=""
          className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base text-slate-900 focus:outline-3 focus:outline-offset-2 focus:outline-blue-700"
        >
          <option value="">Não preciso escolher</option>
          {pessoas.map((p) => (
            <option key={p.id} value={p.id}>
              {p.nome}
            </option>
          ))}
        </select>
      </div>
      <BotaoEnviar>Reativar ministério</BotaoEnviar>
    </form>
  );
}
