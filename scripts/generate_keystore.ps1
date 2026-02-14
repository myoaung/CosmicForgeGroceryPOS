$keystorePath = "$PSScriptRoot\..\android\app\upload-keystore.jks"
$keyToolPath = "keytool" # Assumes keytool is in PATH

if (Test-Path $keystorePath) {
    Write-Host "Keystore already exists at $keystorePath"
    exit 0
}

Write-Host "Generating keystore at $keystorePath..."

& $keyToolPath -genkey -v -keystore $keystorePath `
    -alias upload `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -storepass password123 `
    -keypass password123 `
    -dname "CN=CosmicForge, OU=Engineering, O=CosmicForge, L=Yangon, ST=Yangon, C=MM"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Keystore generated successfully."
} else {
    Write-Host "Failed to generate keystore."
    exit 1
}
