$ErrorActionPreference = "Stop"

if (-not $env:VERCEL_TOKEN) { throw "VERCEL_TOKEN is required." }
if (-not $env:VERCEL_PROJECT_ID) { throw "VERCEL_PROJECT_ID is required." }
if (-not $env:VERCEL_ORG_ID) { throw "VERCEL_ORG_ID is required." }

Write-Host "Building Flutter Web release..."
flutter build web --release `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY

Write-Host "Deploying to Vercel..."
vercel deploy build/web --prod --confirm --token $env:VERCEL_TOKEN
