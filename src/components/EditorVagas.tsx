"use client";
// Editor de vagas do gestor: adicionar, alterar e remover vagas, escolhendo função, rótulo e pessoa.
// Mostra os avisos do servidor (outro ministério no mesmo dia, falta de aptidão) e deixa continuar.
import { useActionState, useState } from "react";
import { AcaoComConfirmacao } from "@/components/AcaoComConfirmacao";
import { AvisosVaga } from "@/components/AvisosVaga";
import { BotaoEnviar } from "@/components/Botao";
import { DestaqueVaga } from "@/components/DestaqueVaga";
import { MensagemErro, MensagemInfo } from "@/components/MensagemErro";
import { SeloDisponibilidade } from "@/components/SeloDisponibilidade";
import type { SituacaoNaData } from "@/lib/disponibilidade/consultas";
import type { Candidato, FuncaoMinisterio, VagaDaEscala } from "@/lib/escalas/consultas";
import type { EstadoVaga } from "@/lib/escalas/estado";
import { removerVaga, salvarVaga } from "@/app/(app)/ministerios/[id]/escalas/acoes";

type Props = {
  ministerioId: string;
  escalaId: string;
  vagas: VagaDaEscala[];
  funcoes: FuncaoMinisterio[];
  candidatos: Candidato[];
  /**
   * Resposta de cada pessoa na data da escala (consulta de disponibilidade do ministério, 004).
   * Vazio quando a data não está em nenhuma consulta: então nada é mostrado (RF-030).
   */
  disponibilidade?: Record<string, SituacaoNaData>;
};

const TEXTO_DISPONIBILIDADE: Record<SituacaoNaData, string> = {
  disponivel: "disponível", indisponivel: "indisponível", sem_resposta: "sem resposta",
};

function FormularioVaga({ ministerioId, escalaId, vaga, funcoes, candidatos, disponibilidade = {} }: Omit<Props, "vagas"> & { vaga?: VagaDaEscala }) {
  const [estado, acao] = useActionState<EstadoVaga, FormData>(salvarVaga, {});
  const [dispensado, setDispensado] = useState<EstadoVaga | null>(null);
  const idBase = vaga ? `vaga-${vaga.id}` : "vaga-nova";
  const nomeVaga = vaga ? `${vaga.funcao}${vaga.rotulo ? ` ${vaga.rotulo}` : ""}` : "nova vaga";

  // Função desativada só aparece se for a da própria vaga (não dá para escolher para vaga nova).
  const opcoesFuncao = funcoes.filter((f) => f.ativa || f.id === vaga?.funcao_id);
  const avisos = estado.avisos && dispensado !== estado ? estado.avisos : [];

  // O React limpa o formulário depois de cada ação. Para a vaga não "sumir" quando aparecem os
  // avisos (e o líder poder continuar com exatamente os mesmos valores), os campos são recriados
  // a cada resposta do servidor, já com os valores devolvidos.
  const chave = estado.valores
    ? `v-${estado.valores.funcao}-${estado.valores.rotulo}-${estado.valores.pessoa}-${estado.avisos?.length ?? 0}`
    : "inicial";

  // "Continuar mesmo assim": envia o mesmo formulário com a ciência do líder.
  const continuar = (formData: FormData) => {
    formData.set("ciente", "1");
    acao(formData);
  };

  return (
    <form action={acao} className="flex flex-col gap-3">
      <MensagemErro texto={estado.erro} />
      <MensagemInfo texto={estado.info} />
      <input type="hidden" name="ministerio" value={ministerioId} />
      <input type="hidden" name="escala" value={escalaId} />
      {vaga && <input type="hidden" name="vaga" value={vaga.id} />}

      <div key={chave} className="flex flex-col gap-3">
        <div className="flex flex-col gap-1">
          <label htmlFor={`${idBase}-funcao`} className="text-base font-medium">Função</label>
          <select id={`${idBase}-funcao`} name="funcao" defaultValue={estado.valores?.funcao ?? vaga?.funcao_id ?? ""} required
                  className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base">
            {!vaga && <option value="" disabled>Escolha a função</option>}
            {opcoesFuncao.map((f) => <option key={f.id} value={f.id}>{f.nome}{f.ativa ? "" : " (desativada)"}</option>)}
          </select>
          {estado.erros?.funcao && <p className="text-sm font-medium text-red-800">{estado.erros.funcao}</p>}
        </div>

        <div className="flex flex-col gap-1">
          <label htmlFor={`${idBase}-rotulo`} className="text-base font-medium">Rótulo (opcional)</label>
          <input id={`${idBase}-rotulo`} name="rotulo" type="text" maxLength={40} defaultValue={estado.valores?.rotulo ?? vaga?.rotulo ?? ""}
                 aria-describedby={estado.erros?.rotulo ? `${idBase}-rotulo-erro` : undefined}
                 className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base" />
          {estado.erros?.rotulo && <p id={`${idBase}-rotulo-erro`} className="text-sm font-medium text-red-800">{estado.erros.rotulo}</p>}
        </div>

        <div className="flex flex-col gap-1">
          <label htmlFor={`${idBase}-pessoa`} className="text-base font-medium">Pessoa</label>
          <select id={`${idBase}-pessoa`} name="pessoa" defaultValue={estado.valores?.pessoa ?? vaga?.pessoa?.id ?? ""}
                  className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base">
            <option value="">Em aberto (sem pessoa)</option>
            {candidatos.map((c) => (
              <option key={c.id} value={c.id}>
                {c.nome}{disponibilidade[c.id] ? ` (${TEXTO_DISPONIBILIDADE[disponibilidade[c.id]]})` : ""}
              </option>
            ))}
          </select>
        </div>
      </div>

      <AvisosVaga avisos={avisos} aoDispensar={() => setDispensado(estado)} aoContinuar={continuar} />
      {avisos.length === 0 && (
        <BotaoEnviar variante={vaga ? "secundario" : "primario"} aria-label={vaga ? `Salvar vaga ${nomeVaga}` : "Adicionar vaga"}>
          {vaga ? "Salvar vaga" : "Adicionar vaga"}
        </BotaoEnviar>
      )}
    </form>
  );
}

export function EditorVagas({ ministerioId, escalaId, vagas, funcoes, candidatos, disponibilidade = {} }: Props) {
  return (
    <div className="flex flex-col gap-6">
      {vagas.length === 0 && <p className="rounded-lg bg-slate-100 p-4 text-lg">Esta escala ainda não tem vagas. Adicione a primeira abaixo.</p>}
      <ul className="flex flex-col gap-4">
        {vagas.map((v) => (
          <li key={v.id} className="flex flex-col gap-3 rounded-lg border border-slate-400 p-4">
            <div className="flex items-center justify-between gap-2">
              <h3 className="text-lg font-semibold">{v.funcao}{v.rotulo && <span className="font-normal"> · {v.rotulo}</span>}</h3>
              <DestaqueVaga tipo={v.precisa_atencao} />
            </div>
            {v.pessoa && disponibilidade[v.pessoa.id] && disponibilidade[v.pessoa.id] !== "disponivel" && (
              <p className="flex flex-wrap items-center gap-2 text-base">
                Disponibilidade nesta data: <SeloDisponibilidade situacao={disponibilidade[v.pessoa.id]} />
              </p>
            )}
            {v.resposta && (
              <p className="text-base text-slate-800">
                Resposta: {v.resposta === "pendente" ? "Pendente" : v.resposta === "confirmado" ? "Confirmado" : "Recusado"}
                {v.resposta === "recusado" && v.motivo ? ` — ${v.motivo}` : ""}
              </p>
            )}
            <FormularioVaga ministerioId={ministerioId} escalaId={escalaId} vaga={v} funcoes={funcoes} candidatos={candidatos} disponibilidade={disponibilidade} />
            <AcaoComConfirmacao
              rotulo="Remover vaga"
              rotuloConfirmar="Confirmar remoção"
              aviso="A vaga é removida da escala. Se houver pessoa nela, ela deixa de estar escalada nesta vaga."
              acao={removerVaga}
              campos={{ ministerio: ministerioId, escala: escalaId, vaga: v.id }}
              nomeAcessivel={`Remover vaga ${v.funcao}${v.rotulo ? ` ${v.rotulo}` : ""}`}
              nomeAcessivelConfirmar={`Confirmar remoção da vaga ${v.funcao}${v.rotulo ? ` ${v.rotulo}` : ""}`}
            />
          </li>
        ))}
      </ul>

      <section aria-labelledby="titulo-nova-vaga" className="flex flex-col gap-3 rounded-lg border border-blue-900 p-4">
        <h3 id="titulo-nova-vaga" className="text-lg font-semibold">Adicionar vaga</h3>
        {funcoes.some((f) => f.ativa) ? (
          <FormularioVaga ministerioId={ministerioId} escalaId={escalaId} funcoes={funcoes} candidatos={candidatos} disponibilidade={disponibilidade} />
        ) : (
          <p className="text-base">Crie ao menos uma função do ministério antes de adicionar vagas.</p>
        )}
      </section>
    </div>
  );
}
