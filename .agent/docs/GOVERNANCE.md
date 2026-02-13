# ⚖️ GOVERNANCE, SECURITY & COMPLIANCE

## 1. IDENTITY & ACCESS MANAGEMENT (IAM)
- **Principle of Least Privilege**:
  - **Cashier**: Access limited to `sales.insert` and `inventory.read`.
  - **Manager**: Access includes `sales.void` and `inventory.update`.
- **MFA Enforcement**: Mandatory Multi-Factor Authentication for all 'Store Owner' roles.

## 2. SECURITY GUARDRAILS
- **Location Spoofing**:
  - Check `isMocked` flag in GPS data.
  - Scan local BSSIDs (WiFi MAC Addresses) and match against `authorized_bssid` in the `stores` table.
- **VPN Policy**: Detect and block requests from known Data Center IP ranges via IP-API.

## 3. IMMUTABLE AUDIT LOGGING
- All destructive actions (DELETE, VOID, PRICE_OVERRIDE) MUST trigger a log entry in the `audit_trail` table.
- Audit logs are READ-ONLY for everyone except the App Owner.