-- Persistent habit streaks and opt-in friend accountability.
-- Additive migration: existing profile JSON and user data are left untouched.

create table if not exists public.habits (
  id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 80),
  icon_code_point integer not null,
  cadence text not null check (cadence in ('daily', 'weekly')),
  weekly_target smallint not null default 3 check (weekly_target between 1 and 7),
  scheduled_days smallint[] not null default array[1, 3, 5]::smallint[],
  current_streak integer not null default 0 check (current_streak >= 0),
  best_streak integer not null default 0 check (best_streak >= current_streak),
  shared_with_friends boolean not null default false,
  auto_evaluated boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, id),
  constraint habits_schedule_days_valid check (
    cardinality(scheduled_days) between 1 and 7
    and scheduled_days <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
  )
);

create index if not exists habits_user_active_idx
  on public.habits (user_id, is_active, created_at);

create table if not exists public.habit_check_ins (
  id uuid primary key default gen_random_uuid(),
  habit_id text not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  completed_on date not null,
  created_at timestamptz not null default now(),
  constraint habit_check_ins_habit_fk foreign key (user_id, habit_id)
    references public.habits(user_id, id) on delete cascade,
  constraint habit_check_ins_once_per_day unique (habit_id, user_id, completed_on)
);

create index if not exists habit_check_ins_user_date_idx
  on public.habit_check_ins (user_id, completed_on desc);

create table if not exists public.friend_invites (
  id uuid primary key default gen_random_uuid(),
  inviter_id uuid not null references auth.users(id) on delete cascade,
  invite_code text not null unique,
  expires_at timestamptz not null default (now() + interval '30 days'),
  accepted_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  constraint friend_invites_not_self check (accepted_by is null or accepted_by <> inviter_id)
);

create index if not exists friend_invites_inviter_idx
  on public.friend_invites (inviter_id, created_at desc);

create table if not exists public.friend_connections (
  id uuid primary key default gen_random_uuid(),
  member_low uuid not null references auth.users(id) on delete cascade,
  member_high uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint friend_connections_sorted_pair check (member_low < member_high),
  constraint friend_connections_unique_pair unique (member_low, member_high)
);

create index if not exists friend_connections_member_high_idx
  on public.friend_connections (member_high);

create table if not exists public.friend_nudges (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  habit_id text,
  message text not null check (length(trim(message)) between 1 and 280),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint friend_nudges_not_self check (sender_id <> recipient_id)
);

create index if not exists friend_nudges_recipient_unread_idx
  on public.friend_nudges (recipient_id, created_at desc) where read_at is null;

alter table public.habits enable row level security;
alter table public.habit_check_ins enable row level security;
alter table public.friend_invites enable row level security;
alter table public.friend_connections enable row level security;
alter table public.friend_nudges enable row level security;

grant select, insert, update, delete on public.habits to authenticated;
grant select, insert, update, delete on public.habit_check_ins to authenticated;
grant select on public.friend_invites to authenticated;
grant select, delete on public.friend_connections to authenticated;
grant select, insert on public.friend_nudges to authenticated;
grant update (read_at) on public.friend_nudges to authenticated;

-- SECURITY DEFINER helper avoids recursive RLS checks on friend_connections.
create or replace function public.are_friends(p_user_a uuid, p_user_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.friend_connections fc
    where fc.member_low = least(p_user_a, p_user_b)
      and fc.member_high = greatest(p_user_a, p_user_b)
  );
$$;

revoke all on function public.are_friends(uuid, uuid) from public;
grant execute on function public.are_friends(uuid, uuid) to authenticated;

create policy "Users manage their own habits"
  on public.habits for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "Friends can view explicitly shared habits"
  on public.habits for select to authenticated
  using (
    shared_with_friends
    and public.are_friends((select auth.uid()), user_id)
  );

create policy "Users manage their own habit check-ins"
  on public.habit_check_ins for all to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.habits h
      where h.id = habit_id and h.user_id = (select auth.uid())
    )
  );

create policy "Friends can view check-ins for shared habits"
  on public.habit_check_ins for select to authenticated
  using (
    public.are_friends((select auth.uid()), user_id)
    and exists (
      select 1 from public.habits h
      where h.id = habit_check_ins.habit_id
        and h.user_id = habit_check_ins.user_id
        and h.shared_with_friends
    )
  );

create policy "Users view their own friend invites"
  on public.friend_invites for select to authenticated
  using (inviter_id = (select auth.uid()));

create policy "Users view their own friend connections"
  on public.friend_connections for select to authenticated
  using ((select auth.uid()) in (member_low, member_high));

create policy "Either friend can end a connection"
  on public.friend_connections for delete to authenticated
  using ((select auth.uid()) in (member_low, member_high));

create policy "Friends view nudges sent or received"
  on public.friend_nudges for select to authenticated
  using ((select auth.uid()) in (sender_id, recipient_id));

create policy "Users send nudges to connected friends"
  on public.friend_nudges for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and public.are_friends(sender_id, recipient_id)
    and (habit_id is null or exists (
      select 1 from public.habits h
      where h.id = friend_nudges.habit_id
        and h.user_id = sender_id
        and h.shared_with_friends
    ))
  );

create policy "Recipients mark their nudges as read"
  on public.friend_nudges for update to authenticated
  using (recipient_id = (select auth.uid()))
  with check (recipient_id = (select auth.uid()));

-- Create a short, shareable invite code without exposing email addresses.
create or replace function public.create_friend_invite()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_code text;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select invite_code into v_code
  from public.friend_invites
  where inviter_id = v_user_id
    and accepted_by is null
    and expires_at > now()
  order by created_at desc
  limit 1;

  if v_code is not null then
    return v_code;
  end if;

  -- Hex codes are case-insensitive and easy to read aloud. Retry on collision.
  loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    exit when not exists (
      select 1 from public.friend_invites where invite_code = v_code
    );

    v_code := null;
  end loop;

  insert into public.friend_invites (inviter_id, invite_code)
  values (v_user_id, v_code);

  return v_code;
end;
$$;

revoke all on function public.create_friend_invite() from public;
grant execute on function public.create_friend_invite() to authenticated;

-- Accepting an invite atomically consumes it and creates a normalized friend pair.
create or replace function public.accept_friend_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_invite public.friend_invites%rowtype;
  v_low uuid;
  v_high uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select * into v_invite
  from public.friend_invites
  where invite_code = upper(trim(p_code))
    and accepted_by is null
    and expires_at > now()
  for update;

  if not found then
    raise exception 'Invite code is invalid or expired';
  end if;
  if v_invite.inviter_id = v_user_id then
    raise exception 'You cannot accept your own invite';
  end if;

  v_low := least(v_invite.inviter_id, v_user_id);
  v_high := greatest(v_invite.inviter_id, v_user_id);

  insert into public.friend_connections (member_low, member_high)
  values (v_low, v_high)
  on conflict (member_low, member_high) do nothing;

  update public.friend_invites
  set accepted_by = v_user_id, accepted_at = now()
  where id = v_invite.id;

  return v_invite.inviter_id;
end;
$$;

revoke all on function public.accept_friend_invite(text) from public;
grant execute on function public.accept_friend_invite(text) to authenticated;

-- Returns only connected users' display names, rather than exposing profiles broadly.
create or replace function public.get_my_friends()
returns table (friend_user_id uuid, display_name text, connected_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select
    case when fc.member_low = auth.uid() then fc.member_high else fc.member_low end,
    coalesce(nullif(trim(p.name), ''), 'Kloudy friend'),
    fc.created_at
  from public.friend_connections fc
  left join public.profiles p
    on p.id = case when fc.member_low = auth.uid() then fc.member_high else fc.member_low end
  where auth.uid() in (fc.member_low, fc.member_high)
  order by fc.created_at desc;
$$;

revoke all on function public.get_my_friends() from public;
grant execute on function public.get_my_friends() to authenticated;
