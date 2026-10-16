# FitCheck Security Policy

## Security Philosophy

FitCheck is an AI-powered interview simulation and candidate screening platform designed with defense-in-depth, candidate data isolation, and credential protection principles:

1. **No Client-Side Secrets**: Private credentials (Google Gemini API keys, Agora Customer Secrets, App Certificates, Firebase Admin SDK credentials) are strictly retained in the backend environment. The Flutter client only consumes ephemeral session tokens and authenticated REST endpoints.
2. **Ephemeral RTC Access Tokens**: Clients receive short-lived, channel-scoped Agora RTC tokens dynamically minted by the backend upon session initiation. Tokens expire automatically after the simulation concludes.
3. **Tenant-Isolated Practice Memory**: All candidate models, jobs, interview sessions, evaluation scorecards, and practice memories enforce strict `WHERE user_id = :current_user_uid` query boundaries verified cryptographically via Firebase ID token verification.
4. **Zero Raw Audio Storage**: Live bidirectional WebRTC voice streams are processed dynamically in-memory for transcription and evaluation. Raw candidate audio recordings are never stored on disk or persistent cloud buckets.
5. **Candidate Privacy & Right to be Forgotten**: Candidates have transparent visibility into persisted practice memories and can purge individual memory entries or clear all historical insights via dedicated self-service endpoints (`DELETE /api/v1/candidate/memories`).
6. **Environment Variable Isolation**: Provider credentials and database connection strings are loaded exclusively via server-side environment variables (`.env`) that are strictly excluded from source control.

---

## Reporting a Vulnerability

If you discover a security vulnerability or sensitive credential leakage within this repository, please report it responsibly:

- **Do NOT** file a public issue on GitHub.
- Submit a confidential report via GitHub's [Security Advisory disclosure](https://github.com/shubhamranswal/fitcheck/security/advisories) feature, or contact the project maintainers directly.
- Include detailed steps to reproduce the issue, along with affected endpoints, payloads, or deployment configurations.

We investigate all legitimate security disclosures promptly and implement remediation patches prior to public disclosure.

---

## Secret Handling Guidelines

- Never commit `.env` or configuration files containing active production keys.
- Always use `.env.example` as a template with placeholder values.
- If credentials are accidentally exposed in a commit, immediately revoke and rotate them across the respective provider consoles (Google AI Studio, Agora Console, Firebase Console).
