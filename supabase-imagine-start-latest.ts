// ==========================================
// Supabase Edge Function: imagine-start
// Triggers the Railway worker to begin processing a job
// Project: vvtiiffhwftiloisywdf (Madeonic RL Storage)
// Deploy via: Supabase Dashboard → Edge Functions → New Function
// Copy-paste this entire file content into the function editor
// ==========================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      }
    })
  }

  try {
    const { prompt, model, features } = await req.json()

    if (!prompt || typeof prompt !== 'string') {
      return new Response(
        JSON.stringify({ error: 'prompt is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client with service role key
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 1. Create job row
    const { data: job, error: jobErr } = await supabase
      .from('jobs')
      .insert({
        status: 'pending',
        model: model || 'minimax-m2p7',
        features: features || {}
      })
      .select()
      .single()

    if (jobErr || !job) {
      return new Response(
        JSON.stringify({ error: 'Failed to create job', details: jobErr?.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // 2. Insert user message
    const { error: msgErr } = await supabase
      .from('messages')
      .insert({
        job_id: job.id,
        role: 'user',
        content: prompt,
        seq: 1
      })

    if (msgErr) {
      console.error('Failed to insert message:', msgErr)
    }

    // 3. Trigger Railway worker via HTTP POST
    const workerUrl = Deno.env.get('RAILWAY_WORKER_URL')!
    const workerSecret = Deno.env.get('WORKER_SECRET')!

    try {
      const workerResp = await fetch(`${workerUrl}/run`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          job_id: job.id,
          secret: workerSecret
        })
      })

      if (!workerResp.ok) {
        const errText = await workerResp.text()
        console.error('Worker trigger failed:', errText)
        // Update job status to error
        await supabase.from('jobs').update({ status: 'error', error: 'Worker trigger failed' }).eq('id', job.id)
      }
    } catch (fetchErr) {
      console.error('Worker unreachable:', fetchErr.message)
      await supabase.from('jobs').update({ status: 'error', error: 'Worker unreachable' }).eq('id', job.id)
    }

    // 4. Return job_id immediately (total execution < 3 seconds)
    return new Response(
      JSON.stringify({ job_id: job.id, status: 'pending' }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      }
    )

  } catch (err) {
    console.error('Edge function error:', err)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: err.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
