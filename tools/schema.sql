-- QuickChat — production schema additions.
-- Run inside the Supabase SQL editor for your project.
-- Idempotent: safe to re-run.

-- ============================================================
-- users: presence
-- ============================================================
alter table public.users
  add column if not exists last_seen timestamptz;

-- Allow each user to update only their own row (presence updates).
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'users' and policyname = 'users_update_self'
  ) then
    create policy users_update_self
      on public.users
      for update
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;
end$$;

-- ============================================================
-- messages: read receipts + soft delete
-- ============================================================
alter table public.messages
  add column if not exists read_at timestamptz,
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_for_everyone boolean not null default false;

-- The recipient may mark messages they DID NOT send as read.
-- The sender may flip deleted flags on their own messages.
-- Both cases are expressed via membership in the conversation.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'messages' and policyname = 'messages_update_in_conversation'
  ) then
    create policy messages_update_in_conversation
      on public.messages
      for update
      using (
        exists (
          select 1 from public.conversations c
          where c.id = messages.conversation_id
            and (c.user1_id = auth.uid() or c.user2_id = auth.uid())
        )
      )
      with check (
        exists (
          select 1 from public.conversations c
          where c.id = messages.conversation_id
            and (c.user1_id = auth.uid() or c.user2_id = auth.uid())
        )
      );
  end if;
end$$;

-- ============================================================
-- conversations: per-user "clear chat" timestamps
-- ============================================================
alter table public.conversations
  add column if not exists user1_cleared_at timestamptz,
  add column if not exists user2_cleared_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'conversations' and policyname = 'conversations_update_by_member'
  ) then
    create policy conversations_update_by_member
      on public.conversations
      for update
      using (auth.uid() = user1_id or auth.uid() = user2_id)
      with check (auth.uid() = user1_id or auth.uid() = user2_id);
  end if;
end$$;

-- ============================================================
-- helpful indexes
-- ============================================================
create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at desc);

create index if not exists messages_unread_idx
  on public.messages (conversation_id, sender_id)
  where read_at is null and deleted_at is null;

-- ============================================================
-- Realtime: ensure UPDATE events on these tables propagate.
-- (Supabase exposes the publication `supabase_realtime` for streaming.)
-- ============================================================
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    -- Add tables to the publication if not already present.
    begin
      execute 'alter publication supabase_realtime add table public.messages';
    exception when duplicate_object then null;
    end;
    begin
      execute 'alter publication supabase_realtime add table public.users';
    exception when duplicate_object then null;
    end;
    begin
      execute 'alter publication supabase_realtime add table public.conversations';
    exception when duplicate_object then null;
    end;
  end if;
end$$;
