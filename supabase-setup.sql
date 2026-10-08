-- =====================================================================
-- Wedding Budget Planner: database setup for Supabase
-- Paste this whole file into Supabase → SQL Editor → New query → Run.
-- Safe to run more than once.
--
-- What it creates:
--   profiles          one row per login: role ('bride' or 'groom') + name
--   planner_sections  each person's planner (settings, items, vendors, ...)
--   planner_images    photos uploaded by each person
-- Row Level Security makes sure a logged-in person can only read and write
-- their OWN rows. The bride can never load the groom's data, and vice versa.
-- =====================================================================

-- 1. PROFILES -----------------------------------------------------------
create table if not exists public.profiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  role       text not null unique check (role in ('bride', 'groom')),  -- only one bride, one groom
  name       text not null default '',
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

drop policy if exists "read own profile"   on public.profiles;
drop policy if exists "update own profile" on public.profiles;
create policy "read own profile"   on public.profiles for select using (auth.uid() = user_id);
create policy "update own profile" on public.profiles for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Create the profile automatically when someone signs up.
-- The app sends { role, name } as sign-up metadata.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id, role, name)
  values (new.id, new.raw_user_meta_data->>'role', coalesce(new.raw_user_meta_data->>'name', ''));
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- The login screen asks which roles already have an account (and their first
-- name) so it can show "Log in" vs "Set up". Nothing else is exposed.
create or replace function public.wedding_roles()
returns table (role text, name text)
language sql security definer set search_path = public as $$
  select role, name from public.profiles;
$$;
grant execute on function public.wedding_roles() to anon, authenticated;

-- 2. PLANNER DATA ------------------------------------------------------
create table if not exists public.planner_sections (
  user_id    uuid not null references auth.users(id) on delete cascade default auth.uid(),
  section    text not null,                 -- settings | items | vendors | payments | tasks | savings
  data       jsonb not null,
  updated_at bigint not null default 0,     -- milliseconds, set by the app
  primary key (user_id, section)
);
alter table public.planner_sections enable row level security;

drop policy if exists "own planner" on public.planner_sections;
create policy "own planner" on public.planner_sections
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 3. PHOTOS ------------------------------------------------------------
-- Photos are resized in the browser (~100–250 KB each) and stored as text.
create table if not exists public.planner_images (
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  id      text not null,
  data    text not null,
  primary key (user_id, id)
);
alter table public.planner_images enable row level security;

drop policy if exists "own images" on public.planner_images;
create policy "own images" on public.planner_images
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
