
# Generate Upload Keystore
# Run this script to create the keystore file.
# Make sure 'keytool' is in your PATH (part of JDK).

$KEYSTORE_NAME = "upload-keystore.jks"
$ALIAS = "upload"
$VALIDITY_DAYS = 10000

if (Test-Path $KEYSTORE_NAME) {
    Write-Host "Keystore $KEYSTORE_NAME already exists. Skipping generation." -ForegroundColor Yellow
} else {
    Write-Host "Generating new keystore: $KEYSTORE_NAME..." -ForegroundColor Green
    keytool -genkey -v -keystore $KEYSTORE_NAME -storetype JKS -keyalg RSA -keysize 2048 -validity $VALIDITY_DAYS -alias $ALIAS
    
    Write-Host "Keystore generated successfully!" -ForegroundColor Green
    Write-Host "Please move $KEYSTORE_NAME to android/app/"
    Write-Host "And update android/key.properties with your password."
}
