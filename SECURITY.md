# Security policy

Luxicon handles sensitive workplace conversations, so we take reports
seriously.

## Reporting a vulnerability

Email **jdmills@davidson.edu** or use GitHub's private vulnerability
reporting on this repository. Please include reproduction steps. You should
hear back within five business days.

Please do not open public issues for exploitable vulnerabilities before
we've had a chance to ship a fix.

## Scope notes

- The iOS app opens no listening ports; the LAN sync channel is
  authenticated and encrypted with TLS-PSK derived from the pairing token.
- `luxicon-mcp listen` is intended for trusted local networks. The pairing
  token (`.sync-token` on the Mac, the phone's Keychain) is the only
  credential — treat it like a password.
