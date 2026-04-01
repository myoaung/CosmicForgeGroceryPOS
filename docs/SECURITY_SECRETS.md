## Secrets Handling

- Supabase URL / anon key must be supplied via CI secrets (`ENV_FILE_BASE64` or individual vars). No secrets are tracked in the repo.
- Previously committed keys are considered compromised; rotate Supabase credentials immediately and update CI secrets.
- Local development should use `.env.example` and manual export of vars; never commit generated `.env`.

