# Rebuild prompt

Hand this whole file to an AI coding assistant (or a developer) to rebuild this
project from scratch. It is written so the result matches what is in this repo.

---

## The brief

Build a shared project tracker for a small team (about 4–25 people). One page,
no build step, no framework, deployed as a static file on GitHub Pages behind a
company subdomain. Everyone signed in sees and edits the same live data.

**Stack**

- A single `index.html` — all HTML, CSS and JS inline. No bundler, no npm.
- Supabase for the database, realtime sync, and email magic-link auth.
- `@supabase/supabase-js@2.45.4` UMD build from jsDelivr, loaded with a `<script>` tag.
- Fonts: Inter (UI) and JetBrains Mono (ids, countdowns) from Google Fonts.
- Hosting: GitHub Pages serving `index.html` from the repo root.

**Hard constraints**

- The Supabase **anon key is public** (it ships in the page source). All access
  control must be enforced by Postgres Row Level Security, never by hiding the key.
- Do **not** put any secret or private API key in the page. That rules out
  calling an LLM directly from the client. Anything that looks like "natural
  language understanding" must be deterministic client-side parsing.
- No horizontal page scroll at phone width. The table becomes stacked cards.
- Support light and dark themes via `prefers-color-scheme` plus a
  `[data-theme]` override.

---

## Data model

One table. Run in the Supabase SQL editor:

```sql
create extension if not exists pgcrypto;

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner text,
  status text not null default 'not_started'
    check (status in ('not_started','in_progress','blocked','done')),
  priority text not null default 'medium'
    check (priority in ('high','medium','low')),
  due date,
  notes text,
  subtasks jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.projects enable row level security;
alter publication supabase_realtime add table public.projects;
```

`subtasks` holds `[{ id, text, done }]`.

`owner` is free text, not a foreign key — real teams write things like
`Ram (7Eagles) / Gautam` and the tracker must not fight that.

---

## Access control

Invite-only. Nobody can self-register.

1. Supabase → Authentication → **turn off** "Allow new users to sign up".
2. Supabase → Authentication → Users → **Invite user** for each teammate.
3. Supabase → Authentication → URL Configuration → set **Site URL** and add the
   production URL to **Redirect URLs** (otherwise the magic link will not return).
4. RLS policies — signed-in users only:

```sql
create policy "authenticated can read projects" on public.projects
  for select using (auth.role() = 'authenticated');
create policy "authenticated can insert projects" on public.projects
  for insert with check (auth.role() = 'authenticated');
create policy "authenticated can update projects" on public.projects
  for update using (auth.role() = 'authenticated');
create policy "authenticated can delete projects" on public.projects
  for delete using (auth.role() = 'authenticated');
```

In the page: on load call `supabase.auth.getSession()`. No session means show a
full-screen sign-in card (email field → `signInWithOtp` with `emailRedirectTo`
set to the page's own URL) and load nothing. Subscribe to `onAuthStateChange`
to enter the app on `SIGNED_IN` and return to the gate on `SIGNED_OUT`. Show the
signed-in email with a Sign out control at the bottom of the sidebar.

---

## Layout

Three regions: a fixed left sidebar, a top bar, and a scrolling main area.

**Sidebar** (`#EDECEF`, 248px, becomes a stacked block under 860px)

- Brand row: round near-black avatar with a letter, product name with a chevron,
  and a live connection status line underneath (green dot + "Live").
- Nav: Home, Inbox, Saved items.
- Section heading "WORKSPACE": Content Approval, **Project Tracker** (the active
  item, the only one wired to anything), CRM Dashboard, Analytics,
  Monthly Reports, Inventory, HR Modules.
- "Owner" filter list, built from the data: Everyone + every distinct owner with
  a count, plus Unassigned when any row has no owner.
- "Status" filter list: Any status, the four statuses with counts, plus
  Overdue and Due soon.
- Pinned to the bottom: Settings, Help & support, and the signed-in user row.

The non-wired nav items are deliberate placeholders for modules that do not
exist. Keep them inert — do not fake pages for them.

**Top bar** (white, bottom border): search box filtering name, notes and owner.

**Main**: page title with a live count line, a "New project" button, a summary
row, a right-aligned "Clear filters" link, then the table. Reserve about 120px
of bottom padding so the floating composer never covers the last row.

---

## Features

### Summary row

Four stat tiles (one per status, clickable to filter, click again to clear) plus
a "Needs attention" panel listing overdue items (red) and items due within 3 days
(amber), sorted by date, capped at 4 with a "Show all N" link. Panel border turns
red if anything is overdue, amber if only due-soon, and it says everything is on
schedule when both are empty.

### Table

Columns: Project, Status, Owner, Priority, Due. Every header sorts (click again
to reverse).

The Project cell holds, on one line: a square checkbox that toggles the row
between done and not started, a muted monospace id (`PT-1`, `PT-2`…), and the
name. Below it: the notes as one truncated line, and — when the row has
subtasks — a small progress bar with `done/total`.

Ids are positional: sort all rows by `created_at` and number from 1, so an id
stays put while the visible list is filtered or re-sorted.

Row click opens the editor. Under 680px the table turns into stacked cards:
headers hidden, each cell becomes a label/value row using `data-label`.

### Editor (right slide-over)

Fields: name, owner (with a datalist of existing owners), due date, status,
priority, a task checklist (add, rename, tick, remove), and notes. Delete asks
for a second click. Shows the row id and a last-updated line.

### Quick-assign composer

A floating bar at the bottom of the screen. One typed line creates a project.
Parsing is deterministic — no model call:

- `@token` → owner. Match against existing owners (exact, then prefix) so `@ram`
  resolves to `Ram (7Eagles) / Gautam`; otherwise use the token as typed.
- `!token` → priority (`high|h|urgent`, `med|medium|m`, `low|l`) or status
  (`blocked|waiting`, `done|complete`, `wip|inprogress|progress|started`,
  `notstarted|todo`). Unknown `!tags` are dropped rather than left in the title.
- Dates, optionally preceded by `by` or `due`: `today`, `eod`, `tomorrow`,
  `eow`, `next week`, a weekday name or 3-letter prefix, `next <weekday>`,
  `YYYY-MM-DD`, `d/m` and `d/m/yy[yy]`, `5 nov`, `nov 5`.
- Everything left over becomes the name.

Date rules that matter: a weekday means its next occurrence and today counts as
that day; `next <weekday>` is the same but skips a week when it lands on today;
a bare day/month already past rolls to next year.

Above the input, show a live chip row with the parsed name, owner, status,
priority and due date, so the interpretation is visible before sending. Disable
send when no name survives parsing.

### Realtime

Subscribe to `postgres_changes` on `projects` and apply inserts, updates and
deletes to local state by id.

**Also update local state immediately after your own writes.** On a fresh page
load the realtime channel can still be connecting when the first write lands, so
a row added in that window would otherwise not appear until reload. Use
`.insert(...).select()` / `.update(...).select()` and merge the returned row.

---

## Design system

```css
--canvas:#FFFFFF; --sidebar:#EDECEF; --surface:#FFFFFF; --surface-2:#F6F6FA;
--line:#E7E7EB; --line-strong:#D7D7DE;
--fg:#101014; --fg-2:#5F5F68; --fg-3:#8E8E98;
--accent:#7B62FF; --accent-soft:#EEEBFC;      /* status/brand only, never buttons */
--ink:#050404; --ink-fg:#FFFFFF; --ink-soft:#E3E1E6;  /* every button and link */
--st-ns:#9CA3AF; --st-ip:#7B62FF; --st-bl:#F2994A; --st-dn:#3EBF55;
--danger:#E5484D;
--radius:5px; --radius-sm:4px;   /* nothing is rounder than 5px */
--shadow:none;                   /* no box shadows anywhere */
```

- Buttons and links are `#050404`. Destructive actions stay red.
- Status renders as **icon + dark text**, never a coloured pill, and only the
  icon carries colour: grey filled circle with an "i" (not started), purple
  dashed spinner that rotates (in progress), amber filled circle with "!"
  (blocked), green filled circle with a white tick (done).
- Priority renders as three ascending bars that fade as they get taller —
  all solid for high (red), partly faded for medium (amber), mostly faded for
  low (green). The label text stays dark.
- Owner avatars are rounded squares with initials. Strip bracketed notes before
  taking initials so `Ram (7Eagles) / Gautam` gives `RG`, not `RE`.
- Respect `prefers-reduced-motion` for the spinner.

---

## Deployment

1. Push to GitHub. The repo must be **public** for Pages on a free account.
2. Settings → Pages → Deploy from a branch → `main` → `/ (root)`.
3. Settings → Pages → Custom domain → `tracker.yourcompany.com`.
4. At the DNS provider add `CNAME` `tracker` → `<user>.github.io`.
5. Tick Enforce HTTPS once the certificate is issued.
6. Add the final URL to Supabase's Site URL and Redirect URLs.

---

## Traps worth knowing

These each cost real debugging time in the original build.

1. **`[hidden]` loses to your own CSS.** `.scrim{display:flex}` is an author rule
   and beats the browser's `[hidden]{display:none}`, so the editor drawer
   rendered open on every page load. Add `[hidden]{display:none!important}`
   yourself. (A hosted-artifact preview injects this for you — plain static
   hosting does not, so the bug only appears after deploying.)
2. **Realtime versus your own first write.** See the note under Realtime above.
3. **PostgREST bulk insert requires identical keys** in every object of the
   array, or it rejects the batch with `All object keys must match`. Fill in
   `null`s rather than omitting fields.
4. **The anon key cannot run DDL**, by design. Schema changes and policy changes
   go through the Supabase SQL editor.
5. **Turning on the authenticated-only policies locks out the anon key**, which
   is the point — but it also stops any script you were using to seed or verify
   data. Finish the data work, or sign in, before applying them.
6. A `python3 -m http.server` started with an empty `cd ""` silently serves the
   wrong directory. Use `--directory`.

---

## Importing an existing spreadsheet

The original data came from a weekly tracker workbook. Map columns to the
schema, and when the sheet has a status vocabulary that is wider than the four
statuses here (for example Waiting and On Hold), either fold them onto the
closest status or widen the `check` constraint — but say which you did, because
the two are not the same thing to the person reading the board.

Put anything that has no column of its own — theme, KPIs, source — into `notes`,
theme first, so it shows as the subtitle line under each project name.
