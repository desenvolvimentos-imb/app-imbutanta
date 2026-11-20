"use client";
import { useActionState } from "react";
import { BotaoEnviar } from "@/components/Botao";
import { MensagemErro } from "@/components/MensagemErro";
import type { EstadoForm } from "@/lib/auth/estado-form";
import type { Papel, Situacao } from "@/lib/auth/permissoes";
import { alterarPapel, alterarSituacao } from "./actions";

export type Usuario = { id: string; nome: string; email: string; situacao: Situacao; papel: Papel };

const ROTULO_PAPEL: Record<Papel, string> = {
  membro: "Membro",
  administrador: "Administrador",
};

const GRUPOS: { situacao: Exclude<Situacao, "pendente">; titulo: string; vazio: string }[] = [
  { situacao: "aprovado", titulo: "Aprovados", vazio: "Ninguém aprovado." },
  { situacao: "recusado", titulo: "Cadastros recusados", vazio: "Nenhum cadastro recusado." },
  { situacao: "acesso_removido", titulo: "Acesso removido", vazio: "Ninguém com acesso removido." },
];

export function ListaDeUsuarios({ usuarios }: { usuarios: Usuario[] }) {
  const [estadoPapel, acaoPapel] = useActionState<EstadoForm, FormData>(alterarPapel, {});
  const [estadoSituacao, acaoSituacao] = useActionState<EstadoForm, FormData>(alterarSituacao, {});
  const erro = estadoPapel.erro ?? estadoSituacao.erro;

  const botaoSituacao = (u: Usuario, nova: Situacao, rotulo: string, variante: "primario" | "secundario") => (
    <form action={acaoSituacao}>
      <input type="hidden" name="id" value={u.id} />
      <input type="hidden" name="nova" value={nova} />
      <input type="hidden" name="esperada" value={u.situacao} />
      <BotaoEnviar variante={variante} aria-label={`${rotulo} ${u.nome}`}>
        {rotulo}
      </BotaoEnviar>
    </form>
  );

  return (
    <>
      <MensagemErro texto={erro} />
      {GRUPOS.map((g) => {
        const doGrupo = usuarios.filter((u) => u.situacao === g.situacao);
        return (
          <section key={g.situacao} aria-labelledby={`grupo-${g.situacao}`} className="flex flex-col gap-3">
            <h2 id={`grupo-${g.situacao}`} className="text-lg font-semibold">
              {g.titulo} ({doGrupo.length})
            </h2>
            {doGrupo.length === 0 && <p className="rounded-lg bg-slate-100 p-3">{g.vazio}</p>}
            <ul className="flex flex-col gap-4">
              {doGrupo.map((u) => (
                <li key={u.id} className="flex flex-col gap-3 rounded-lg border border-slate-400 p-4">
                  <div>
                    <p className="text-lg font-semibold">{u.nome}</p>
                    <p className="text-sm text-slate-700">{u.email}</p>
                  </div>

                  {u.situacao === "aprovado" && (
                    <>
                      <form action={acaoPapel} className="flex flex-col gap-2">
                        <input type="hidden" name="id" value={u.id} />
                        <label htmlFor={`papel-${u.id}`} className="font-medium">
                          Papel de {u.nome}
                        </label>
                        <select
                          id={`papel-${u.id}`}
                          name="papel"
                          defaultValue={u.papel}
                          className="min-h-12 rounded-lg border border-slate-500 bg-white px-3 text-base"
                        >
                          {(Object.keys(ROTULO_PAPEL) as Papel[]).map((p) => (
                            <option key={p} value={p}>
                              {ROTULO_PAPEL[p]}
                            </option>
                          ))}
                        </select>
                        <BotaoEnviar variante="secundario" aria-label={`Alterar papel de ${u.nome}`}>
                          Alterar papel
                        </BotaoEnviar>
                      </form>
                      {botaoSituacao(u, "acesso_removido", "Remover acesso de", "secundario")}
                    </>
                  )}
                  {u.situacao === "recusado" && botaoSituacao(u, "aprovado", "Reaprovar", "primario")}
                  {u.situacao === "acesso_removido" && botaoSituacao(u, "aprovado", "Restaurar acesso de", "primario")}
                </li>
              ))}
            </ul>
          </section>
        );
      })}
    </>
  );
}
