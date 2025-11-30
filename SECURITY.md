# Security Policy

## Supported Versions

Use the latest version of Demel.

## Reporting a Vulnerability

If you discover a security vulnerability within Demel, please do not open a public issue.

### API Keys and Secrets
Demel uses API keys for services like Gemini and ListenBrainz.
- **NEVER** commit your `.env` file to version control.
- The `.gitignore` file is configured to exclude `.env` by default.
- If you accidentally commit your API keys, revoke them immediately and generate new ones.

### Reporting Process
Please report security issues by opening a draft security advisory or contacting the maintainer directly if that option is not available.
