-- Ejecutar en Supabase → SQL Editor.
-- Para usuario con id = 1 en public.users → esquema user_1 y tabla user_1.registros

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

  execute format('grant usage on schema %I to anon, authenticated', schema_name);
  execute format('grant all on all tables in schema %I to anon, authenticated', schema_name);
  execute format('grant usage, select on all sequences in schema %I to anon, authenticated', schema_name);
end;
$$;

grant execute on function public.create_user_schema(bigint) to anon, authenticated;

-- Añade el esquema (p. ej. user_1) en Settings → API → Exposed schemas para PostgREST.
