// Interpreta o resultado da consulta ao perfil da pessoa logada.
// Se a consulta falhar ou a pessoa não tiver perfil, levantamos um erro CLARO em vez de
// tratar como "pendente": antes isso escondia problemas reais (ex.: banco sem as migrações)
// atrás de uma tela de "aguardando aprovação" enganosa (constituição, princípio III).
import type { Papel, Situacao } from "./permissoes";

// Linha de `perfis` como vem do banco.
export type PerfilBanco = {
  id: string;
  nome: string;
  email: string;
  situacao: Situacao;
  papel: Papel;
};

// Perfil usado pelo app: a linha do banco + se a pessoa lidera algum ministério ativo (RF-027).
// A liderança é derivada das participações e lida do banco a cada requisição (RF-034).
export type Perfil = PerfilBanco & { lidera: boolean };

/** Erro com mensagem segura para a pessoa; o detalhe técnico vai só para o log do servidor. */
export class ErroPerfil extends Error {
  constructor() {
    super("Não foi possível carregar o perfil da conta.");
    this.name = "ErroPerfil";
  }
}

type Consulta = { data: PerfilBanco | null; error: { message: string } | null };

export function perfilOuFalha(consulta: Consulta, usuario: { id: string; email?: string | null }): PerfilBanco {
  if (consulta.error) {
    console.error("[perfil] falha ao ler o perfil", { usuario: usuario.id, erro: consulta.error.message });
    throw new ErroPerfil();
  }
  if (!consulta.data) {
    // Não deveria acontecer: o gatilho cria o perfil junto com o usuário.
    console.error("[perfil] usuário sem perfil", { usuario: usuario.id });
    throw new ErroPerfil();
  }
  return consulta.data;
}
