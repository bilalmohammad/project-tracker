# Team Project Tracker

A single-page project tracker (table view, owner/status filters, overdue
summary) backed by Supabase for live, shared data across every teammate who
opens the page.

## Files
- `index.html` — the app (GitHub Pages serves this as the homepage)
- `project-tracker.html` — identical copy, kept for reference
- `supabase-setup.sql` — run once in Supabase to create the table and policies

## One-time setup

1. **Create a Supabase project** at supabase.com (free tier is enough for a
   team of 4). Note its **Project URL** and **anon public key** from
   Project Settings → API.
2. **Create the table.** Open the SQL Editor in Supabase, paste the contents
   of `supabase-setup.sql`, and run it.
3. **Wire up the keys.** In `index.html`, find:
   ```js
   const SUPABASE_URL = "https://YOUR-PROJECT-REF.supabase.co";
   const SUPABASE_ANON_KEY = "YOUR-ANON-PUBLIC-KEY";
   ```
   and replace both with your project's real values. Do the same in
   `project-tracker.html` if you keep it.
4. **Push to GitHub** and turn on **Pages** (see the chat steps for exact
   commands).
5. **Point your subdomain** at GitHub Pages with a CNAME DNS record, and set
   that subdomain as the custom domain in the repo's Pages settings.

## Security note

The anon key is meant to be public — it only grants what the table's Row
Level Security policies allow. `supabase-setup.sql` ships with open
read/write policies (anyone who can load the page can edit data), which is
reasonable only because the page sits behind a company-only subdomain. If
this will ever be reachable from the public internet, add Supabase Auth and
restrict policies to signed-in users on your company's email domain before
relying on it.
