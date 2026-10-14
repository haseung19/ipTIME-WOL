# Changelog

All notable changes to this project will be documented here.

## [0.1.0] - 2026-10-14

### Added

- Windows desktop GUI to log in to an ipTIME router and list registered WOL targets.
- Wake-on-LAN request for a selected target PC.
- One-click desktop shortcut (`PC 켜기 (ipTIME)`).
- Local password protection through Windows user-scoped DPAPI.
- Single-file Windows x64 launcher (`ipTIME-WOL.exe`) embedding the PowerShell GUI.
- Korean and English instructions, security guide, build script, and protocol notes.

### Known limitations

- Confirmed user-reported working setup: BE5100M firmware 15.36.0; other models/versions are unverified.
- HTTP and HTTPS are selectable, but enabling HTTPS is a separate router configuration task.
- Accepted router WOL command does not confirm the target PC is powered on.
- The executable is not digitally signed.
