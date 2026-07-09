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

## Run the listener automatically at login

A LaunchAgent keeps the listener alive so you never have to remember a
terminal window. Install the binary with the script — it builds, signs,
installs to `~/bin` (pointing launchd into `.build/` breaks the next time
`swift package clean` runs), allows it through the macOS firewall, and
restarts the agent:

```bash
scripts/install-listener.sh
```

Signing matters: the firewall remembers "Allow" by code-signing identity,
and unsigned builds get a new identity each rebuild — the firewall then
silently blocks the listener and phone pushes fail with "The listener did
not confirm the transfer".

Save this as `~/Library/LaunchAgents/edu.davidson.luxicon.listener.plist`,
replacing `YOURUSER` with your username:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>edu.davidson.luxicon.listener</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Users/YOURUSER/bin/luxicon-mcp</string>
		<string>listen</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>/Users/YOURUSER/Library/Logs/luxicon-listener.log</string>
	<key>StandardErrorPath</key>
	<string>/Users/YOURUSER/Library/Logs/luxicon-listener.log</string>
</dict>
</plist>
```

Then load it (starts at login from now on, restarts if it dies):

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/edu.davidson.luxicon.listener.plist
```

Verify with `lsof -nP -i :51234` (should show `luxicon-m … LISTEN`), or
read the startup banner in `~/Library/Logs/luxicon-listener.log`. The
pairing token is also in `~/Luxicon/.sync-token`.

Housekeeping:

- After pulling new code, re-run `scripts/install-listener.sh` — it
  rebuilds, re-signs, and restarts the agent in one go.
- To stop it: `launchctl bootout gui/$(id -u)/edu.davidson.luxicon.listener`.
- The listener prints the pairing token at startup, so the log file is as
  sensitive as `.sync-token` — both are readable only by your account.

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
