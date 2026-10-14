# ipTIME WOL Windows

**An unofficial portable Windows utility for listing Wake-on-LAN devices registered on an ipTIME router and sending a wake request with one click.**

[한국어 README](README.md) · [Security](SECURITY.md) · [Troubleshooting (Korean)](docs/TROUBLESHOOTING.ko.md)

> This software is **not an official EFM Networks / ipTIME product** and is not affiliated with or endorsed by the manufacturer.

## Features

- Connect using the router's IP address or DDNS hostname, management port, administrator username, and password.
- Query WOL targets registered on the router after login.
- Select a target and send a wake request.
- Create a desktop shortcut for one-click wake-up of the selected PC.
- Protect the locally stored **password** using Windows user-scoped DPAPI.
- Run without Python or an installer; the EXE uses built-in Windows PowerShell.

## Known working setup

| Item | Status |
| --- | --- |
| Router | ipTIME **BE5100M** |
| Firmware | **15.36.0** |
| Client OS | Designed for Windows 10/11 **x64** |
| Functional validation | A user reported successful operation of the login, list, and WOL features |
| Other models and versions | **Not yet verified** |

The binary format and packaged source have been checked, but broad compatibility testing has not been performed.

## Getting started

1. Download [`bin/ipTIME-WOL.exe`](bin/ipTIME-WOL.exe), or use the [Releases page](../../releases) once a release has been published.
2. Put the EXE in a **permanent folder** and double-click it.
3. Enter the router hostname/IP, management port, HTTP/HTTPS choice, administrator ID, and password.
4. Click **`1. 로그인 및 목록 조회` (Log in and list)**. Select a PC and click **`2. 선택한 PC 켜기` (Wake selected PC)**.
5. To create a one-click shortcut, select a PC and click **`3. 원클릭 아이콘 생성` (Create one-click shortcut)**.
6. Double-click **`PC 켜기 (ipTIME)`** on your Windows desktop to send the saved wake request.

The shortcut points to the EXE's original location. If you move the EXE, recreate the shortcut.

## Requirements

- The target PC must be registered in the router's WOL device list.
- For access outside your LAN, the router's remote management interface must be reachable through its configured address/port, or you must use a suitable VPN.
- The target PC's BIOS/UEFI, network adapter, and OS must support and have WOL enabled; a wired Ethernet connection is typically required.

## Security: HTTP and HTTPS

**HTTPS must be configured on the router separately. This program does not enable or require HTTPS automatically.**

- You can choose either HTTP or HTTPS in the UI.
- **An HTTP administrator login transmits your credentials without transport encryption.** HTTPS or a VPN is recommended, especially over the internet.
- HTTPS certificate validation is not bypassed.
- The password saved for one-click access is DPAPI-protected on the local Windows account. Other saved values, such as the router URL and target MAC, are not encrypted.
- An accepted WOL request does **not** verify that the PC has finished booting.

See [SECURITY.md](SECURITY.md) for details.

## Storage and reset

Saved settings are stored at `%LOCALAPPDATA%\ipTIME-WOL\settings.json`. To reset, close the application and delete this file. **Do not upload it to a public issue or commit it to Git.**

## Build from source

The single Windows EXE is a Go launcher embedding the PowerShell GUI source. It temporarily writes the embedded script to a per-user temporary directory and removes it on exit.

- Source: [`src/main.go`](src/main.go) and [`src/ipTIME-WOL.ps1`](src/ipTIME-WOL.ps1).
- Build prerequisites: Go 1.23+; Windows PowerShell 5.1+ for running the program.
- On Windows, run `build.ps1` from the repository root to create `dist/ipTIME-WOL.exe`.
- Cross-compile using `GOOS=windows GOARCH=amd64 CGO_ENABLED=0`.

Additional build details are available in [docs/BUILD.ko.md](docs/BUILD.ko.md).

## Protocol and compatibility

This build sends JSON POSTs to `/cgi/service.cgi` and uses `session/login`, `wol/show`, and `wol/signal`. A fallback to `wol/wake` is attempted only when the router explicitly reports that `wol/signal` is unsupported. Firmware versions and login behavior can differ. See [docs/PROTOCOL.ko.md](docs/PROTOCOL.ko.md).

Protocol references: [maengis/iptime_api](https://github.com/maengis/iptime_api) and [boxqkrtm/iptime-wol-fast](https://github.com/boxqkrtm/iptime-wol-fast). Their code is not included in this repository.

## License

[MIT License](LICENSE). The `ipTIME` name and related trademarks belong to their respective owners. Provided **as is**, without warranty.
