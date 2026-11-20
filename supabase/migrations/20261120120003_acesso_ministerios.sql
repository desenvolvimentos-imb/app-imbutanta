-- Regras de acesso (RLS) das tabelas de ministérios, aplicadas NO BANCO (RF-035): valem mesmo
-- para chamadas diretas à API com a chave pública. Detalhes: data-model.md (Políticas de acesso).

-- A pessoa logada é líder VÁLIDO deste ministério? (participação com papel líder, ministério
-- ativo e conta aprovada). `security definer` lê as tabelas sem passar pela RLS; lê do banco a
-- cada chamada, então mudanças valem na hora (RF-034).
create function public.eh_lider_de(p_ministerio uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.participacoes_ministerio pm
      join public.ministerios m on m.id = pm.ministerio_id and m.ativo
      join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
     where pm.ministerio_id = p_ministerio
       and pm.perfil_id = auth.uid()
       and pm.papel = 'lider'
  );
$$;

-- Ministérios ativos que a pessoa logada lidera. A interface usa para mostrar as telas de líder.
create function public.ministerios_que_lidero()
returns table (id uuid, nome text)
language sql
stable
security definer
set search_path = public
as $$
  select m.id, m.nome
    from public.participacoes_ministerio pm
    join public.ministerios m on m.id = pm.ministerio_id and m.ativo
    join public.perfis p on p.id = pm.perfil_id and p.situacao = 'aprovado'
   where pm.perfil_id = auth.uid()
     and pm.papel = 'lider'
   order by m.nome;
$$;

revoke execute on function public.eh_lider_de(uuid) from public, anon;
grant execute on function public.eh_lider_de(uuid) to authenticated;
revoke execute on function public.ministerios_que_lidero() from public, anon;
grant execute on function public.ministerios_que_lidero() to authenticated;

alter table public.ministerios enable row level security;
alter table public.participacoes_ministerio enable row level security;
alter table public.pedidos_entrada_ministerio enable row level security;

-- Permissões de tabela: só leitura; TODA escrita passa por funções (security definer).
revoke all on public.ministerios from anon, authenticated;
revoke all on public.participacoes_ministerio from anon, authenticated;
revoke all on public.pedidos_entrada_ministerio from anon, authenticated;

-- O visitante (tela de cadastro) lê só o que precisa para marcar ministérios: nome e descrição.
grant select (id, nome, descricao, ativo) on public.ministerios to anon;
grant select on public.ministerios to authenticated;
grant select on public.participacoes_ministerio to authenticated;
grant select on public.pedidos_entrada_ministerio to authenticated;

-- Ministérios ativos: qualquer pessoa (inclusive visitante). Nome e descrição não são dado pessoal.
create policy ministerios_ler_ativos on public.ministerios
  for select to anon, authenticated
  using (ativo);

-- O administrador lê todos, inclusive os desativados.
create policy ministerios_ler_admin on public.ministerios
  for select to authenticated
  using (public.papel_aprovado_atual() = 'administrador');

-- Cada pessoa lê só as próprias participações; os colegas são lidos por função (sem email).
create policy participacoes_ler_propria on public.participacoes_ministerio
  for select to authenticated
  using (perfil_id = auth.uid());

create policy participacoes_ler_admin on public.participacoes_ministerio
  for select to authenticated
  using (public.papel_aprovado_atual() = 'administrador');

-- Cada pessoa lê só os próprios pedidos.
create policy pedidos_ler_proprio on public.pedidos_entrada_ministerio
  for select to authenticated
  using (perfil_id = auth.uid());

create policy pedidos_ler_admin on public.pedidos_entrada_ministerio
  for select to authenticated
  using (public.papel_aprovado_atual() = 'administrador');
