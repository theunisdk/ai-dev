---
name: check-claude-ext-backdoor
description: Use when someone asks whether their machine is compromised by the trojanized Claude Code IDE extension (Anthropic.claude-code 2.1.313 from the Cursor extension marketplace, October 2026), mentions the svc-telemetry SSH key, 134.209.82.225, com.apple.sysmond.plist or the SysMon scheduled task, or wants to audit a Mac, Linux, Windows or WSL box after that incident.
---

# Check for the Claude Code extension backdoor

## Overview

On 2026-10-29, version 2.1.313 of `Anthropic.claude-code` in the Cursor extension marketplace was trojanized. It was live from about 02:27 to 13:35 PT. It added an attacker SSH key labelled `svc-telemetry` and installed persistence. It sent host details to `134.209.82.225` and tried to open a reverse SSH tunnel. The npm package and the Microsoft VS Code Marketplace build were not affected. Cursor's notice is the primary source:
https://cursor.com/blog/claude-code-extension-security-notice

The scripts here only read. They never delete, kill or change anything.

## Run

| Machine | Command |
|---|---|
| macOS, Linux, WSL, remote SSH hosts | `bash scripts/check.sh` |
| Windows | `powershell -ExecutionPolicy Bypass -File scripts\check.ps1` |

Run each script as the user who runs the IDE. Under WSL, run both scripts: `check.sh` inside WSL and `check.ps1` on the Windows host. Each one checks only the machine it runs on.

## Read the result

Every line starts with `FOUND`, `clean`, `SKIP` or `info`. The exit code summarizes them:

| Exit | Meaning | Tell the user |
|---|---|---|
| 0 | No indicator found | No published indicator is present on this machine. |
| 1 | At least one `FOUND` | List every `FOUND` line, then give the next steps below. |
| 2 | No `FOUND`, but a check could not run | The result is incomplete. Name each `SKIP` line and how to run that check, for example from an elevated shell. |

Do not report exit 2 as clean. A check that could not run is not a check that passed.

`FOUND` lines about the extension folder, `extensions.json` or the IDE logs show that 2.1.313 was installed or loaded. The other `FOUND` lines show that the payload ran.

## Next steps when something is FOUND

Give these steps to the user. Do not carry them out yourself, even when the user asks you to fix it. The machine is untrusted, and the credential rotation must happen on another machine.

1. Do not delete anything yet. Copy the flagged files somewhere safe first.
2. Disconnect the machine from the network, or block `134.209.82.225` on ports 22 and 8099.
3. Follow the remediation section of Cursor's notice. It has cleanup scripts for macOS and Windows. The cleanup removes the `svc-telemetry` line from `authorized_keys`, the dropped files, and the LaunchAgent, cron entry or `SysMon` task.
4. From a different, clean machine, rotate every credential this machine could reach. That covers SSH keys, cloud keys, tokens, and `.env` secrets.
5. Update the extension to 2.1.314 or later. Uninstalling it alone does not remove the persistence.
6. If the payload ran, consider rebuilding the machine.

## Common mistakes

- Treating a clean result as proof. The scripts check only the published indicators, and IDE logs rotate.
- Checking only the WSL side when the IDE runs on the Windows host, or the reverse.
- Forgetting remote hosts that `.vscode-server` or `.cursor-server` connects to.
- Deleting the evidence before copying it.
