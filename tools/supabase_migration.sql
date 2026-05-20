-- =========================================================================
-- QuickChat — Supabase schema (TEST mode, RLS DISABLED)
-- Run this once in Supabase Dashboard → SQL Editor → New query → Run.
-- WARNING: RLS is OFF here for testing only. Do NOT ship to production
-- without enabling RLS and adding policies.
-- =========================================================================

-- 1) Profile mirror of auth.users (the app inserts a row on signUp)
create table if not exists public.users (
  id         uuid primary key references auth.users(id) on delete cascade,
  name       text,
  email      text,
  bio        text,
  created_at timestamptz not null default now()
);

-- 2) 1-on-1 conversations between two users
create table if not exists public.conversations (
  id         uuid primary key default gen_random_uuid(),
  user1_id   uuid not null references public.users(id) on delete cascade,
  user2_id   uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint conversations_distinct check (user1_id <> user2_id)
);

-- 3) Messages
create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id       uuid not null references public.users(id) on delete cascade,
  content         text not null,
  message_type    text not null default 'text',
  is_read         boolean not null default false,
  created_at      timestamptz not null default now()
);

-- 4) Indexes for the queries the app actually runs
create index if not exists idx_conversations_user1   on public.conversations(user1_id);
create index if not exists idx_conversations_user2   on public.conversations(user2_id);
create index if not exists idx_messages_conversation on public.messages(conversation_id);
create index if not exists idx_messages_created      on public.messages(conversation_id, created_at desc);

-- 5) DISABLE RLS — testing only
alter table public.users         disable row level security;
alter table public.conversations disable row level security;
alter table public.messages      disable row level security;

-- 6) Realtime: messages stream needs the table in the supabase_realtime publication
do $$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

-- 7) Optional: also stream conversation creates (so dashboard live-updates)
do $$
begin
  alter publication supabase_realtime add table public.conversations;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
