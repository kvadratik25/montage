create table if not exists public.montage_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  work_date date not null,
  title text not null,
  total_seconds integer not null check (total_seconds >= 0),
  ad_seconds integer not null default 0 check (ad_seconds >= 0),
  paid boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.montage_settings (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  rate integer not null default 250,
  compare_rate integer not null default 350,
  updated_at timestamptz not null default now()
);

create table if not exists public.montage_access (
  owner_id uuid not null references auth.users(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'client' check (role = 'client'),
  created_at timestamptz not null default now(),
  primary key (owner_id, viewer_id)
);

alter table public.montage_jobs enable row level security;
alter table public.montage_settings enable row level security;
alter table public.montage_access enable row level security;

drop policy if exists "owner jobs" on public.montage_jobs;
create policy "owner jobs" on public.montage_jobs for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "owner settings" on public.montage_settings;
create policy "owner settings" on public.montage_settings for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "viewer sees access" on public.montage_access;
create policy "viewer sees access" on public.montage_access for select using (auth.uid() = viewer_id or auth.uid() = owner_id);
drop policy if exists "client reads shared jobs" on public.montage_jobs;
create policy "client reads shared jobs" on public.montage_jobs for select using (exists (select 1 from public.montage_access a where a.owner_id = montage_jobs.user_id and a.viewer_id = auth.uid()));
drop policy if exists "client reads shared settings" on public.montage_settings;
create policy "client reads shared settings" on public.montage_settings for select using (exists (select 1 from public.montage_access a where a.owner_id = montage_settings.user_id and a.viewer_id = auth.uid()));

insert into public.montage_access (owner_id, viewer_id)
select owner.id, viewer.id from auth.users owner cross join auth.users viewer
where owner.email = 'kvadratik25@gmail.com' and viewer.email = 'proavto@montage.local'
on conflict do nothing;
