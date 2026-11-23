"use client";
// Funções do ministério (vocal, violão...): criar, renomear, desativar e reativar (FR-001 a FR-003).
// Esconder estes controles de quem não é gestor NÃO é segurança: o banco barra de qualquer forma.
import { useActionState } from "react";
import { AcaoComConfirmacao } from "@/components/AcaoComConfirmacao";
import { BotaoEnviar } from "@/components/Botao";
import { Campo } from "@/components/Campo";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { FuncaoMinisterio } from "@/lib/escalas/consultas";
import {
  criarFuncao, desativarFuncao, reativarFuncao, renomearFuncao,
} from "@/app/(app)/ministerios/[id]/funcoes/acoes";

function NovaFuncao({ ministerioId }: { ministerioId: string }) {
  const [estado, acao] = useActionState<EstadoForm, FormData>(criarFuncao, {});
  return (
    <form action={acao} noValidate className="flex flex-col gap-3">
      <MensagemErro texto={estado.erro} />
      <MensagemInfo texto={estado.info} />
      <input type="hidden" name="ministerio" value={ministerioId} />
      <Campo nome="nome" rotulo="Nova função" erro={estado.erros?.nome} defaultValue={estado.valores?.nome} maxLength={40}
             dica="Por exemplo: Vocal, Violão, Bateria, Recepção." />
      <BotaoEnviar>Criar função</BotaoEnviar>
    </form>
  );
}

function LinhaFuncao({ ministerioId, funcao }: { ministerioId: string; funcao: FuncaoMinisterio }) {
  const [estado, renomear] = useActionState<EstadoForm, FormData>(renomearFuncao, {});
  const [estadoReativar, reativar] = useActionState<EstadoForm, FormData>(reativarFuncao, {});

  return (
    <li className="flex flex-col gap-3 rounded-lg border border-slate-400 p-4">
      <div className="flex items-center justify-between gap-2">
        <p className="text-lg font-semibold">{funcao.nome}</p>
        <span className={`rounded px-2 py-0.5 text-sm font-medium ${funcao.ativa ? "bg-blue-100 text-blue-950" : "bg-slate-200 text-slate-800"}`}>
          {funcao.ativa ? "Ativa" : "Desativada"}
        </span>
      </div>

      {funcao.ativa ? (
        <>
          <form action={renomear} noValidate className="flex flex-col gap-3">
            <MensagemErro texto={estado.erro} />
            <MensagemInfo texto={estado.info} />
            <input type="hidden" name="ministerio" value={ministerioId} />
            <input type="hidden" name="funcao" value={funcao.id} />
            <Campo nome="nome" idCampo={`nome-${funcao.id}`} rotulo={`Nome da função ${funcao.nome}`} erro={estado.erros?.nome}
                   defaultValue={funcao.nome} maxLength={40} />
            <BotaoEnviar variante="secundario" aria-label={`Salvar nome da função ${funcao.nome}`}>Salvar nome</BotaoEnviar>
          </form>
          <AcaoComConfirmacao
            rotulo="Desativar"
            rotuloConfirmar="Confirmar desativação"
            aviso="A função deixa de poder ser escolhida em vagas novas. Escalas e vagas que já existem continuam como estão."
            acao={desativarFuncao}
            campos={{ ministerio: ministerioId, funcao: funcao.id }}
            nomeAcessivel={`Desativar a função ${funcao.nome}`}
            nomeAcessivelConfirmar={`Confirmar desativação: ${funcao.nome}`}
          />
        </>
      ) : (
        <form action={reativar} className="flex flex-col gap-3">
          <MensagemErro texto={estadoReativar.erro} />
          <input type="hidden" name="ministerio" value={ministerioId} />
          <input type="hidden" name="funcao" value={funcao.id} />
          <BotaoEnviar variante="secundario" aria-label={`Reativar a função ${funcao.nome}`}>Reativar</BotaoEnviar>
        </form>
      )}
    </li>
  );
}

export function EditorFuncoes({ ministerioId, funcoes }: { ministerioId: string; funcoes: FuncaoMinisterio[] }) {
  return (
    <div className="flex flex-col gap-6">
      <NovaFuncao ministerioId={ministerioId} />
      {funcoes.length === 0 ? (
        <p className="rounded-lg bg-slate-100 p-4 text-lg">Este ministério ainda não tem funções. Crie a primeira acima.</p>
      ) : (
        <ul className="flex flex-col gap-3">
          {funcoes.map((f) => <LinhaFuncao key={f.id} ministerioId={ministerioId} funcao={f} />)}
        </ul>
      )}
    </div>
  );
}
