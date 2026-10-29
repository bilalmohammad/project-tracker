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

alter table public.projects enable row level security;

-- Access control: only people who are signed in (via the magic-link email
-- sign-in flow) can read or write. Nobody can sign in unless you've invited
-- them from the Supabase dashboard (Authentication → Users → Invite user)
-- with "Allow new users to sign up" turned OFF, so this is effectively a
-- private tool limited to your invited teammates.
drop policy if exists "anon can read projects" on public.projects;
drop policy if exists "anon can insert projects" on public.projects;
drop policy if exists "anon can update projects" on public.projects;
drop policy if exists "anon can delete projects" on public.projects;

create policy "authenticated can read projects" on public.projects
  for select using (auth.role() = 'authenticated');

create policy "authenticated can insert projects" on public.projects
  for insert with check (auth.role() = 'authenticated');

create policy "authenticated can update projects" on public.projects
  for update using (auth.role() = 'authenticated');

create policy "authenticated can delete projects" on public.projects
  for delete using (auth.role() = 'authenticated');

-- Enable realtime updates for this table.
alter publication supabase_realtime add table public.projects;
