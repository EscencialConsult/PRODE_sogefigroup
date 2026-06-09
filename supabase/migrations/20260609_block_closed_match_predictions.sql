-- Blocks predictions once a match has started or is no longer scheduled.
-- Run this in Supabase SQL Editor, or via the Supabase CLI with admin credentials.

create or replace function public.validar_prediccion_partido_abierto()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_partido record;
  v_apuesta_estado text;
begin
  select p.id, p.fecha_hora, p.estado
    into v_partido
  from public.partidos p
  where p.id = new.partido_id;

  if not found then
    raise exception 'El partido no existe.';
  end if;

  select a.estado
    into v_apuesta_estado
  from public.apuestas a
  where a.id = new.apuesta_id;

  if not found then
    raise exception 'La apuesta no existe.';
  end if;

  if v_apuesta_estado is distinct from 'abierta' then
    raise exception 'La apuesta no admite mas pronosticos.';
  end if;

  if not exists (
    select 1
    from public.apuesta_partidos ap
    where ap.apuesta_id = new.apuesta_id
      and ap.partido_id = new.partido_id
  ) then
    raise exception 'El partido no pertenece a esta apuesta.';
  end if;

  if lower(coalesce(v_partido.estado, '')) in ('en_vivo', 'finalizado', 'cancelado', 'suspendido') then
    raise exception 'Este partido ya no admite mas pronosticos.';
  end if;

  if v_partido.fecha_hora is not null and v_partido.fecha_hora <= now() then
    raise exception 'Este partido ya comenzo y no admite mas pronosticos.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validar_prediccion_partido_abierto on public.predicciones;

create trigger trg_validar_prediccion_partido_abierto
before insert or update of pred_local, pred_visitante, pred_clasificado, partido_id, apuesta_id
on public.predicciones
for each row
execute function public.validar_prediccion_partido_abierto();
