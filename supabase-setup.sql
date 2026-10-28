-- Run this once in your Supabase project's SQL Editor
-- (Supabase dashboard → SQL Editor → New query → paste → Run)

create extension if not exists pgcrypto;

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner text,
  status text not null default 'not_started' check (status in ('not_started','in_progress','blocked','done')),
  priority text not null default 'medium' check (priority in ('high','medium','low')),
  due date,
  notes text,
  subtasks jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Row Level Security must be on for the anon key to be used safely.
alter table public.projects enable row level security;

-- Starting point: anyone holding the anon key (i.e. anyone who can load the
-- page) can read and write. This is fine behind a company-only subdomain
-- that nobody outside the org can reach. If the page will ever be reachable
-- from the open internet, replace these with Supabase Auth–based policies
-- (e.g. restrict by authenticated users with your company's email domain)
-- before relying on it.
create policy "anon can read projects" on public.projects
  for select using (true);

create policy "anon can insert projects" on public.projects
  for insert with check (true);

create policy "anon can update projects" on public.projects
  for update using (true);

create policy "anon can delete projects" on public.projects
  for delete using (true);

-- Enable realtime updates for this table.
alter publication supabase_realtime add table public.projects;
