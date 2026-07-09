# Mac sync — pairing and troubleshooting

Luxicon can push finished transcripts (and summaries) from the iPhone to a
Mac over your local network, so the MCP server can serve them to Claude
without AirDrop round-trips.

## How it works

- The Mac runs `luxicon-mcp listen`, which advertises `_luxicon._tcp` via
  Bonjour on port 51234 and prints a **pairing token** (also stored beside
  the library at `.sync-token`, chmod 600).
- The phone connects with TLS-PSK: both sides derive the key from the
  pairing token (SHA-256), so nothing on the wire is readable — and nothing
  can be pushed — without the token. Traffic never leaves your LAN.
- Pushes are one file per connection; re-pushing a session after its summary
  lands simply overwrites the same file (idempotent).

## Pairing

1. On the Mac: `swift build -c release && .build/release/luxicon-mcp listen`
2. On the iPhone: **My Voice → Mac sync**, enter the printed token.
3. Optional: toggle **Push automatically after each 1-on-1**, or use
   **Push All to Mac** from a person's share menu.

## When the Mac isn't found

Enterprise Wi-Fi often blocks mDNS/Bonjour. The listener prints its IP
addresses at startup — enter one under **Mac address** on the phone and
Luxicon connects directly to port 51234.

Other checks:

- iOS asks for **Local Network** permission on the first push; if you
  declined, re-enable it in Settings → Privacy & Security → Local Network →
  Luxicon.
- Both devices must be on the same network (and not isolated by a guest
  SSID).
- A wrong token fails the TLS handshake — re-copy it from the listener
  output.

## Security notes

- The pairing token is the only credential. On the phone it is stored in
  the Keychain; on the Mac, in `.sync-token` next to the library. Delete
  that file to force a new token (re-pair the phone afterwards).
- Sessions use `TLS_PSK_WITH_AES_128_GCM_SHA256`. There is no forward
  secrecy: treat the token like a password and rotate it if a device is
  compromised.
- The listener accepts frames up to 64 MiB and only writes sanitized
  `*.json` filenames inside the library directory.
