-- Regras de acesso a `perfis` aplicadas NO BANCO (RF-020): valem mesmo para chamadas
-- diretas à API do Supabase com a chave pública, não só pela interface.

-- Papel da pessoa logada, mas só se a conta estiver aprovada (senão, nulo).
-- `security definer` lê a tabela sem passar pela RLS, o que evita recursão nas políticas.
-- Lê do banco a cada chamada: mudanças de papel valem na hora (RF-026).
create function public.papel_aprovado_atual()
returns public.papel_usuario
language sql
stable
security definer
set search_path = public
as $$
  select papel from public.perfis
   where id = auth.uid() and situacao = 'aprovado';
$$;

revoke execute on function public.papel_aprovado_atual() from public, anon;
grant execute on function public.papel_aprovado_atual() to authenticated;

alter table public.perfis enable row level security;

-- Permissões de tabela: o app só lê e, no máximo, edita o próprio nome.
-- Criar/apagar perfil é feito por gatilhos e funções; situação e papel, por funções RPC.
revoke all on public.perfis from anon, authenticated;
grant select on public.perfis to authenticated;
grant update (nome) on public.perfis to authenticated;

-- Cada pessoa lê o próprio perfil (precisa dele para saber qual tela ver).
create policy perfis_ler_proprio on public.perfis
  for select to authenticated
  using (id = auth.uid());

-- Administrador lê todos.
create policy perfis_ler_admin on public.perfis
  for select to authenticated
  using (public.papel_aprovado_atual() = 'administrador');

-- Líder lê apenas quem está na fila: pendente e com email confirmado.
create policy perfis_ler_fila_lider on public.perfis
  for select to authenticated
  using (
    public.papel_aprovado_atual() = 'lider'
    and situacao = 'pendente'
    and email_verificado
  );

-- Cada pessoa só edita a própria linha (e, pelas permissões acima, só a coluna `nome`).
create policy perfis_editar_proprio on public.perfis
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());
