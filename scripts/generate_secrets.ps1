# scripts/generate_secrets.ps1

# This script generates the necessary secret files from environment variables.
# It is intended to run in CI/CD environments or for local setup if you have the env vars set.

$ErrorActionPreference = "Stop"

Write-Host "Starting secret generation..."

# 1. Generate .env file
if ($env:ENV_FILE_BASE64) {
    Write-Host "Generating .env from ENV_FILE_BASE64..."
    $envContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($env:ENV_FILE_BASE64))
    [System.IO.File]::WriteAllText("$PWD/.env", $envContent)
}
elseif ($env:SUPABASE_URL -and $env:SUPABASE_ANON_KEY) {
    Write-Host "Generating .env from individual variables..."
    $envContent = "SUPABASE_URL=$($env:SUPABASE_URL)`nSUPABASE_ANON_KEY=$($env:SUPABASE_ANON_KEY)"
    [System.IO.File]::WriteAllText("$PWD/.env", $envContent)
}
else {
    Write-Warning "Skipping .env generation: Missing ENV_FILE_BASE64 or SUPABASE credentials."
}

# 2. Generate android/key.properties
if ($env:ANDROID_KEY_PROPERTIES_BASE64) {
    Write-Host "Generating android/key.properties from ANDROID_KEY_PROPERTIES_BASE64..."
    $keyPropsContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($env:ANDROID_KEY_PROPERTIES_BASE64))
    [System.IO.File]::WriteAllText("$PWD/android/key.properties", $keyPropsContent)
}
else {
    Write-Warning "Skipping key.properties generation: Missing ANDROID_KEY_PROPERTIES_BASE64."
}

# 3. Generate android/app/upload-keystore.jks
if ($env:ANDROID_KEYSTORE_BASE64) {
    Write-Host "Generating android/app/upload-keystore.jks from ANDROID_KEYSTORE_BASE64..."
    $keystoreBytes = [System.Convert]::FromBase64String($env:ANDROID_KEYSTORE_BASE64)
    [System.IO.File]::WriteAllBytes("$PWD/android/app/upload-keystore.jks", $keystoreBytes)
}
else {
    Write-Warning "Skipping upload-keystore.jks generation: Missing ANDROID_KEYSTORE_BASE64."
}

Write-Host "Secret generation complete."
