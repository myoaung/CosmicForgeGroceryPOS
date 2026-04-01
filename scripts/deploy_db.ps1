$ErrorActionPreference = "Stop"

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
  throw "Supabase CLI is required. Install: https://supabase.com/docs/guides/cli"
}

Write-Host "Applying Supabase migrations..."
supabase db push
