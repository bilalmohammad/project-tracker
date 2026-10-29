# Team Project Tracker

A shared project tracker for a small team. One HTML file, no build step,
deployed on GitHub Pages, with Supabase behind it for live shared data and
invite-only sign-in.

Everyone signed in sees the same board, and changes appear for everyone without
a refresh.

## What's in here

| File | What it is |
| --- | --- |
| `index.html` | The whole app — HTML, CSS and JS inline. This is the only file GitHub Pages serves. |
| `supabase-setup.sql` | Table, row-level security policies and realtime, to run once in Supabase. |
| `PROMPT.md` | A complete rebuild spec. Hand it to an AI assistant or a developer to recreate this project from scratch. |

## Features

- Table of projects with name, owner, status, priority, due date and notes
- Per-project task checklist with a progress bar on the row
- Filter by owner and by status, search across name/notes/owner, sortable columns
- "Needs attention" panel for overdue and due-within-3-days work
- One-click done toggle on each row
- Quick-assign bar at the bottom: `Draft Q4 deck @Priya !high by friday`
- Live sync between everyone who has it open
- Magic-link sign-in, limited to people you invite
- Works on phones (the table becomes cards), light and dark themes

## Setup

### 1. Supabase

1. Create a project at [supabase.com](https://supabase.com) (the free tier is enough).
2. SQL Editor → New query → paste `supabase-setup.sql` → Run.
3. Project Settings → API → copy the **Project URL** and the **anon public** key.

### 2. Point the app at your project

In `index.html`, near the top of the `<script>` block:

```js
const SUPABASE_URL = "https://YOUR-PROJECT-REF.supabase.co";
const SUPABASE_ANON_KEY = "YOUR-ANON-PUBLIC-KEY";
```

The anon key is meant to be public — it only grants what the row-level security
policies allow. Never put the **service role** key in this file.

### 3. Lock down who can sign in

1. Authentication → Sign In / Providers → Email enabled, and
   **"Allow new users to sign up" turned OFF**. Without this, anyone could
   register themselves.
2. Authentication → Users → **Invite user** for each teammate.
3. Authentication → URL Configuration → set **Site URL** to your live URL and
   add it to **Redirect URLs**, or the magic link will not come back to the app.

### 4. Publish

1. Push this repo to GitHub. It must be **public** for Pages on a free account.
2. Settings → Pages → Source: Deploy from a branch → `main` → `/ (root)`.
3. Settings → Pages → Custom domain → e.g. `tracker.yourcompany.com`.
4. At your DNS provider add a `CNAME` record: `tracker` → `<your-user>.github.io`.
5. Once DNS resolves, tick **Enforce HTTPS**.
6. Add the final URL back into Supabase's Site URL / Redirect URLs.

## Running it locally

```bash
python3 -m http.server 8000
```

Then open `http://localhost:8000`. Add `http://localhost:8000` to Supabase's
Redirect URLs if you want magic-link sign-in to work locally too.

## Quick-assign syntax

Type one line in the bar at the bottom and press Enter. The chips above the
input show exactly what was understood before you send it.

| Token | Effect |
| --- | --- |
| `@priya` | Assigns the owner. Matches existing owners, so `@ram` finds `Ram (7Eagles) / Gautam`. |
| `!high` `!med` `!low` | Priority |
| `!blocked` `!done` `!wip` | Status |
| `by friday`, `tomorrow`, `5 nov`, `15/11`, `2026-11-05`, `next week`, `eow` | Due date |
| anything else | The project name |

Parsing happens in the browser with fixed rules, not a language model — a public
static page cannot hold an API key safely. So phrasing it has not been taught
(`sometime after Diwali`) lands in the project name instead of the date field,
which the preview chips will show you.

## Changing the statuses

The four statuses are fixed in four places: the `check` constraint in
`supabase-setup.sql`, the `STATUSES` array, the `STATUS_ICON` map, and
`STATUS_WORDS` (the `!tags` the quick-assign bar accepts). Changing the set
means editing all four and migrating any existing rows.
