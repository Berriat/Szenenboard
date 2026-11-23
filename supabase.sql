-- Szenenboard: Datenbank für die gemeinsame Online-Speicherung
-- In Supabase: SQL Editor → New query → alles einfügen → Run.
-- Ganz unten die E-Mail-Adressen eintragen, die Zugang bekommen sollen.
-- Das Skript kann gefahrlos mehrmals ausgeführt werden.

-- ---------- Team: wer darf rein ----------
create table if not exists public.team_members (
  email     text primary key,
  added_at  timestamptz not null default now()
);

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.team_members
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
grant execute on function public.is_member() to authenticated;

-- ---------- Projekte und Versionen ----------
create table if not exists public.projects (
  id          text primary key,
  name        text not null default '',
  deleted     boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  updated_by  text,
  client_id   text
);

create table if not exists public.versions (
  id          text primary key,
  project_id  text not null references public.projects(id) on delete cascade,
  n           integer not null,
  note        text not null default '',
  created     date not null default current_date,
  data        jsonb not null default '{}'::jsonb,
  deleted     boolean not null default false,
  updated_at  timestamptz not null default now(),
  updated_by  text,
  client_id   text
);
create index if not exists versions_project_idx on public.versions(project_id);

-- ---------- Verlauf: frühere Stände jeder Version ----------
create table if not exists public.history (
  id          bigserial primary key,
  version_id  text not null references public.versions(id) on delete cascade,
  project_id  text not null,
  n           integer,
  data        jsonb not null,
  saved_at    timestamptz not null default now(),
  saved_by    text
);
create index if not exists history_version_idx on public.history(version_id, saved_at desc);

-- Vor jeder Änderung wird der bisherige Stand gesichert, höchstens alle
-- 10 Minuten pro Version, und immer, wenn jemand anderer weiterschreibt.
create or replace function public.snapshot_version() returns trigger
language plpgsql security definer set search_path = public as $$
declare last_at timestamptz;
begin
  if new.data is not distinct from old.data then
    return new;
  end if;
  select max(saved_at) into last_at from public.history where version_id = old.id;
  if last_at is null
     or last_at < now() - interval '10 minutes'
     or new.updated_by is distinct from old.updated_by then
    insert into public.history (version_id, project_id, n, data, saved_at, saved_by)
    values (old.id, old.project_id, old.n, old.data, old.updated_at, old.updated_by);
  end if;
  return new;
end $$;

drop trigger if exists versions_snapshot on public.versions;
create trigger versions_snapshot
  before update on public.versions
  for each row execute function public.snapshot_version();

-- ---------- Zugriffsrechte: nur Team-Mitglieder ----------
alter table public.team_members enable row level security;
alter table public.projects     enable row level security;
alter table public.versions     enable row level security;
alter table public.history      enable row level security;

drop policy if exists "team lesen"     on public.team_members;
drop policy if exists "team einladen"  on public.team_members;
drop policy if exists "team entfernen" on public.team_members;
create policy "team lesen"     on public.team_members for select to authenticated using (public.is_member());
create policy "team einladen"  on public.team_members for insert to authenticated with check (public.is_member());
create policy "team entfernen" on public.team_members for delete to authenticated using (public.is_member());

drop policy if exists "projekte" on public.projects;
drop policy if exists "versionen" on public.versions;
drop policy if exists "verlauf"   on public.history;
create policy "projekte"  on public.projects for all    to authenticated using (public.is_member()) with check (public.is_member());
create policy "versionen" on public.versions for all    to authenticated using (public.is_member()) with check (public.is_member());
create policy "verlauf"   on public.history  for select to authenticated using (public.is_member());

-- ---------- Live-Abgleich ----------
do $$ begin
  alter publication supabase_realtime add table public.projects;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.versions;
exception when duplicate_object then null; end $$;

-- ---------- Bilder der Figuren ----------
insert into storage.buckets (id, name, public)
values ('bilder', 'bilder', true)
on conflict (id) do nothing;

drop policy if exists "bilder hochladen" on storage.objects;
drop policy if exists "bilder loeschen"  on storage.objects;
create policy "bilder hochladen" on storage.objects for insert to authenticated
  with check (bucket_id = 'bilder' and public.is_member());
create policy "bilder loeschen" on storage.objects for delete to authenticated
  using (bucket_id = 'bilder' and public.is_member());

-- ---------- Wer darf rein? Hier E-Mail-Adressen eintragen ----------
insert into public.team_members (email) values
  ('deine@email.at')
on conflict (email) do nothing;
