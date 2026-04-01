import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabaseClient = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_ANON_KEY') ?? '',
            { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
        )

        // Authenticate the user and enforce tenant bounds
        const { data: user, error: userError } = await supabaseClient.auth.getUser()
        if (userError) throw userError

        // Operation Oracle: Inventory Aggregate
        // Fetches lowest inventory thresholds directly from the core DB
        const { data, error } = await supabaseClient
            .from('inventory')
            .select('product_id, quantity, products!inner(name, sku)')
            .eq('tenant_id', user.user.app_metadata.tenant_id)
            .order('quantity', { ascending: true })
            .limit(100)

        if (error) throw error

        return new Response(JSON.stringify({ metrics: data }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
        })
    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
        })
    }
})
