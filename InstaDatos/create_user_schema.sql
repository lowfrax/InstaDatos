-- Ejecutar en Supabase → SQL Editor (sustituye la función anterior).
-- public.users.id = 1 → esquema user_1 y tabla user_1.registros

create or replace function public.create_user_schema(user_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  schema_name text;
begin
  if not exists (select 1 from public.users u where u.id = user_id) then
    raise exception 'El usuario % no existe en public.users', user_id;
  end if;

  schema_name := 'user_' || user_id::text;

  execute format('create schema if not exists %I', schema_name);

  execute format(
    'create table if not exists %I.registros (
      id bigserial primary key,
      nombre text not null,
      estado text not null default ''activo'',
      fecha_creacion timestamptz not null default now()
    )',
    schema_name
  );

  -- Permisos explícitos (más fiable que solo ALL TABLES en algunos entornos).
  execute format('grant usage on schema %I to anon, authenticated', schema_name);
  execute format(
    'grant select, insert, update, delete on table %I.registros to anon, authenticated',
    schema_name
  );
  execute format(
    'grant usage, select on sequence %I.registros_id_seq to anon, authenticated',
    schema_name
  );
end;
$$;

grant execute on function public.create_user_schema(bigint) to anon, authenticated;

-- Settings → API → Exposed schemas: añade user_1, user_2, … (o el patrón que uses).
