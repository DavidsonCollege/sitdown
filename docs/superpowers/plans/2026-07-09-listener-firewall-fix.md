# Listener Firewall Permanent Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the macOS firewall's "Allow" for the sync listener survive rebuilds, via stable Developer ID signing wrapped in one install script, plus a line-buffered listener log.

**Architecture:** The firewall persists trust by a signature's designated requirement (identifier + certificate), so signing every build with the Mac's Developer ID identity makes one Allow permanent. `scripts/install-listener.sh` encodes build → sign → install → firewall-allow → LaunchAgent restart. `setvbuf` line-buffers the listener's stdout so its log is live under launchd.

**Tech Stack:** bash, `codesign`, `socketfilterfw`, `launchctl`, Swift (one-line change in LuxiconMCP).

**Spec:** `docs/superpowers/specs/2026-07-09-listener-firewall-fix-design.md`

## Global Constraints

- Signing identity, exactly: `Developer ID Application: The Trustees of Davidson College (4Z539UE4TT)`.
- Plain `codesign --force --sign` — no `--timestamp` (needs network, only for notarization), no hardened runtime (risks MLX/Metal, buys nothing for firewall trust).
- The script's only sudo steps are the two `socketfilterfw` calls.
- `swift build`/`swift test` run from the repo root; the sudo steps prompt for a password, so the full script run happens in JD's terminal, not here.
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Line-buffered listener log

**Files:**
- Modify: `Sources/LuxiconMCP/SyncListener.swift:13-16`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing other tasks call; behavioral change only (log lines flush as printed).

- [ ] **Step 1: Add setvbuf at the top of run()**

In `Sources/LuxiconMCP/SyncListener.swift`, at the start of `static func run(libraryURL: URL) throws -> Never`:

```swift
    static func run(libraryURL: URL) throws -> Never {
        // Under launchd, stdout is a file and fully buffered — the banner and
        // "Received …" lines would sit unflushed forever. Line-buffer so the
        // log is usable for diagnosing sync issues live.
        setvbuf(stdout, nil, _IOLBF, 0)
        try FileManager.default.createDirectory(
            at: libraryURL, withIntermediateDirectories: true)
```

- [ ] **Step 2: Build and run existing tests**

```bash
swift build -c release --product luxicon-mcp && swift test --filter SyncTests
```
Expected: build succeeds, SyncTests pass.

- [ ] **Step 3: Commit**

```bash
git add Sources/LuxiconMCP/SyncListener.swift
git commit -m "fix: line-buffer listener stdout so the launchd log is live

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: install-listener.sh

**Files:**
- Create: `scripts/install-listener.sh` (mode 755)

**Interfaces:**
- Consumes: the release binary built by `swift build -c release --product luxicon-mcp`.
- Produces: `scripts/install-listener.sh`, referenced by docs in Task 3.

- [ ] **Step 1: Write the script**

```bash
#!/bin/bash
# Build, sign, install, firewall-allow, and restart the Luxicon sync listener.
#
# Why signing: the macOS application firewall remembers "Allow" by the
# binary's code-signing identity. Ad-hoc builds get a fresh identity every
# rebuild, so the firewall silently re-blocks them (phone pushes then fail
# with "The listener did not confirm the transfer"). A stable Developer ID
# signature makes one Allow permanent.
set -euo pipefail

IDENTITY="Developer ID Application: The Trustees of Davidson College (4Z539UE4TT)"
BIN="$HOME/bin/luxicon-mcp"
LABEL="edu.davidson.luxicon.listener"
FW=/usr/libexec/ApplicationFirewall/socketfilterfw

cd "$(dirname "$0")/.."

echo "==> Building"
swift build -c release --product luxicon-mcp

echo "==> Signing"
codesign --force --sign "$IDENTITY" .build/release/luxicon-mcp

echo "==> Installing to $BIN"
mkdir -p "$HOME/bin"
install .build/release/luxicon-mcp "$BIN"

echo "==> Allowing through the application firewall (sudo)"
# Idempotent: --add is a no-op when already listed; --unblockapp flips any
# Block rule to Allow.
sudo "$FW" --add "$BIN"
sudo "$FW" --unblockapp "$BIN"

echo "==> Restarting LaunchAgent"
if launchctl kickstart -k "gui/$(id -u)/$LABEL" 2>/dev/null; then
    echo "Done. Listener restarted on the new binary."
else
    echo "LaunchAgent $LABEL is not loaded — set it up per docs/sync.md."
fi
```

- [ ] **Step 2: Make it executable and syntax-check**

```bash
chmod +x scripts/install-listener.sh && bash -n scripts/install-listener.sh
```
Expected: no output (clean parse).

- [ ] **Step 3: Verify the non-sudo portion works (build + sign)**

```bash
swift build -c release --product luxicon-mcp && codesign --force --sign "Developer ID Application: The Trustees of Davidson College (4Z539UE4TT)" .build/release/luxicon-mcp && codesign -dv .build/release/luxicon-mcp 2>&1 | grep Authority | head -1
```
Expected: `Authority=Developer ID Application: The Trustees of Davidson College (4Z539UE4TT)`.

- [ ] **Step 4: Commit**

```bash
git add scripts/install-listener.sh
git commit -m "feat: install script that signs the listener so the firewall Allow sticks

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Update docs/sync.md

**Files:**
- Modify: `docs/sync.md:25-81` (LaunchAgent section)

**Interfaces:**
- Consumes: `scripts/install-listener.sh` from Task 2.
- Produces: docs only.

- [ ] **Step 1: Replace the manual install block (lines 27-34)**

Replace:

```markdown
A LaunchAgent keeps the listener alive so you never have to remember a
terminal window. Install the binary somewhere stable first — pointing
launchd into `.build/` breaks the next time `swift package clean` runs:

```bash
swift build -c release
mkdir -p ~/bin && install .build/release/luxicon-mcp ~/bin/
```
```

with:

```markdown
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
```

- [ ] **Step 2: Update the buffering note (lines 69-72)**

Replace:

```markdown
Verify with `lsof -nP -i :51234` (should show `luxicon-m … LISTEN`). Note
that the startup banner may not appear in the log immediately — stdout is
buffered when not attached to a terminal — so read the pairing token from
the file instead: `cat ~/Luxicon/.sync-token`.
```

with:

```markdown
Verify with `lsof -nP -i :51234` (should show `luxicon-m … LISTEN`), or
read the startup banner in `~/Library/Logs/luxicon-listener.log`. The
pairing token is also in `~/Luxicon/.sync-token`.
```

- [ ] **Step 3: Update housekeeping (lines 76-78)**

Replace:

```markdown
- After pulling new code, rebuild and re-run the `install` command, then
  `launchctl kickstart -k gui/$(id -u)/edu.davidson.luxicon.listener` to
  restart on the new binary.
```

with:

```markdown
- After pulling new code, re-run `scripts/install-listener.sh` — it
  rebuilds, re-signs, and restarts the agent in one go.
```

- [ ] **Step 4: Commit**

```bash
git add docs/sync.md
git commit -m "docs: install the listener via the signing install script

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: End-to-end verification

**Files:** none (verification only).

**Interfaces:**
- Consumes: everything above; JD's terminal for the sudo run; JD's phone for the final push.

- [ ] **Step 1: JD runs the script** (sudo prompts for a password, so this run happens in JD's terminal):

```bash
cd ~/Documents/GitHub/sitdown && scripts/install-listener.sh
```
Expected: ends with "Done. Listener restarted on the new binary."

- [ ] **Step 2: Verify signature and firewall state**

```bash
codesign -dv ~/bin/luxicon-mcp 2>&1 | grep -E "Authority|Signature" | head -2
/usr/libexec/ApplicationFirewall/socketfilterfw --listapps | grep -A1 luxicon
```
Expected: `Authority=Developer ID Application: …` (no `Signature=adhoc`), and the firewall entry says **Allow incoming connections**.

- [ ] **Step 3: Loopback push proves the log is live**

```bash
echo '{"test":"log-live"}' > /tmp/log-live.json
TOKEN=$(cat ~/Luxicon/.sync-token)
.build/release/luxicon-cli push /tmp/log-live.json --token "$TOKEN" --host 127.0.0.1
tail -3 ~/Library/Logs/luxicon-listener.log
```
Expected: push succeeds AND `Received log-live.json (…bytes)` appears in the tail immediately.

- [ ] **Step 4: Phone push (JD)** — tap **Retry Push** on the failed session. Expected: flips to green "Pushed to Mac now" and the file appears in `~/Luxicon`.
