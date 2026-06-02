-- ==========================================
-- IMAGINE VISUALIZATION BUILDER
-- Supabase Database Schema
-- ==========================================
-- Project: vvtiiffhwftiloisywdf (Madeonic RL Storage)
-- URL: https://vvtiiffhwftiloisywdf.supabase.co
-- Run this entire script in the Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ==========================================

-- Enable Realtime for all tables (needed for client subscription)
-- This is also configured in Dashboard → Database → Replication

-- ==========================================
-- TABLE: jobs
-- Tracks each visualization request
-- ==========================================
CREATE TABLE IF NOT EXISTS jobs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'running', 'completed', 'error')),
  model TEXT NOT NULL DEFAULT 'minimax-m2p7',
  features JSONB DEFAULT '{}',
  api_key TEXT,  -- optional: per-job API key override (encrypted at rest by Supabase)
  error TEXT,    -- error message if status = 'error'
  source TEXT DEFAULT 'edge_function'
    CHECK (source IN ('edge_function', 'direct_chat', 'poll_recovery')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- TABLE: messages
-- Stores the conversation history for each job
-- ==========================================
CREATE TABLE IF NOT EXISTS messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'tool', 'system', 'assistant_tool_calls')),
  content TEXT DEFAULT '',
  seq INTEGER NOT NULL DEFAULT 0,  -- ordering within the conversation
  tool_call_id TEXT,               -- for role='tool': the tool_call_id
  tool_calls_data JSONB,           -- for role='assistant_tool_calls': the full tool_calls array
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- TABLE: widgets
-- Stores the widget code (HTML/SVG) for each job
-- Updated progressively during streaming
-- ==========================================
CREATE TABLE IF NOT EXISTS widgets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT 'widget',
  code TEXT NOT NULL DEFAULT '',   -- the HTML/SVG widget code
  is_final BOOLEAN NOT NULL DEFAULT false,  -- true when streaming complete
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- TABLE: tool_calls
-- Records each tool call made during a job
-- ==========================================
CREATE TABLE IF NOT EXISTS tool_calls (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,              -- 'visualize_read_me' or 'show_widget'
  args TEXT DEFAULT '',            -- raw JSON arguments
  status TEXT NOT NULL DEFAULT 'calling'
    CHECK (status IN ('calling', 'running', 'done', 'error')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- INDEXES
-- ==========================================
CREATE INDEX IF NOT EXISTS idx_messages_job_id ON messages(job_id);
CREATE INDEX IF NOT EXISTS idx_messages_job_seq ON messages(job_id, seq);
CREATE INDEX IF NOT EXISTS idx_widgets_job_id ON widgets(job_id);
CREATE INDEX IF NOT EXISTS idx_tool_calls_job_id ON tool_calls(job_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);

-- ==========================================
-- ENABLE REALTIME
-- The client subscribes to these tables to get live updates
-- ==========================================
ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE widgets;
ALTER PUBLICATION supabase_realtime ADD TABLE tool_calls;

-- ==========================================
-- ROW LEVEL SECURITY (RLS)
-- For now, we use the service_role key in the worker,
-- and the anon key in the client. RLS policies:
-- ==========================================
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE widgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE tool_calls ENABLE ROW LEVEL SECURITY;

-- Allow anon key to read everything (for the thin client)
-- and insert jobs/messages (to send prompts)
CREATE POLICY "Allow anon read jobs" ON jobs FOR SELECT USING (true);
CREATE POLICY "Allow anon insert jobs" ON jobs FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon update jobs" ON jobs FOR UPDATE USING (true);

CREATE POLICY "Allow anon read messages" ON messages FOR SELECT USING (true);
CREATE POLICY "Allow anon insert messages" ON messages FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anon read widgets" ON widgets FOR SELECT USING (true);
CREATE POLICY "Allow anon insert widgets" ON widgets FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon update widgets" ON widgets FOR UPDATE USING (true);

CREATE POLICY "Allow anon read tool_calls" ON tool_calls FOR SELECT USING (true);
CREATE POLICY "Allow anon insert tool_calls" ON tool_calls FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow anon update tool_calls" ON tool_calls FOR UPDATE USING (true);

-- ==========================================
-- FUNCTION: trigger_railway_worker
-- Called after inserting a job to notify the Railway worker
-- ==========================================
-- Note: We use the Supabase Edge Function to trigger the worker,
-- not a DB trigger, because we need to make an HTTP POST request
-- which requires network access not available in DB functions.
