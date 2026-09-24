alter table public.friend_invites
  add column if not exists streak_name text,
  add column if not exists streak_cadence text;

create or replace function public.create_streak_invite(
  p_streak_name text,
  p_cadence text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_code text;
begin
  if v_user_id is null then raise exception 'Authentication required'; end if;
  if length(trim(coalesce(p_streak_name, ''))) = 0 then raise exception 'Streak name required'; end if;
  loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    exit when not exists (select 1 from public.friend_invites where invite_code = v_code);
  end loop;
  insert into public.friend_invites (inviter_id, invite_code, streak_name, streak_cadence)
  values (v_user_id, v_code, trim(p_streak_name), p_cadence);
  return v_code;
end;
$$;

revoke all on function public.create_streak_invite(text, text) from public;
grant execute on function public.create_streak_invite(text, text) to authenticated;
