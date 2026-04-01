# 7. DevOps Pipelines & Deployment

## 7.1 Continuous Integration (CI)
GitHub Actions (`.github/workflows/ci.yml`) is the primary CI provider.
Every push and PR to `main` and `develop` triggers the `Lint / Analyze / Test` workflow:

1. **Linting & Analysis**: Runs `flutter analyze` ensuring 0 warnings.
2. **Unit & Widget Testing**: Runs `flutter test` across all targets.
3. **Coverage Enforcement**: Uses `lcov` to enforce a strict **70% minimum code coverage**. Pull requests will visually fail the CI gate if coverage drops below this boundary.

## 7.2 Security Scanning
Automated guardrails scan the repository for infrastructural misconfigurations:
- **Trivy / Snyk**: Analyzes native dependencies inside `.flutter-plugins-dependencies`, checking for known CVEs.
- **GitLeaks**: Scans all commits to guarantee `.env` tokens, Supabase Anon Keys, or production secrets are never leaked into version control.

## 7.3 Delivery & Deployment (CD)
- **Android Builds**: An automated workflow spawns on `windows-latest` via `pwsh`, leveraging `scripts/generate_secrets.ps1` to decode Base64 GitHub Secrets into a physical `key.properties` file for APK/AAB signing. Artifacts are automatically grouped.
- **iOS Builds**: Spawned on `macos-latest` to build `.ipa` archives.
- **Web Dashboard**: An automated job compiles Flutter to WASM/HTML and instantly deploys the artifacts to Vercel via CLI utilizing injected Production `.env` securely.
