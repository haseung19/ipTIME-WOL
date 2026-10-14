# ipTIME WOL Windows

**Windows에서 ipTIME 공유기의 WOL 등록 PC를 조회하고, 버튼 또는 바탕화면 바로가기로 PC 전원을 켜는 비공식 도구입니다.**

[English README](README.en.md) · [다운로드/실행](#다운로드-및-실행) · [문제 해결](docs/TROUBLESHOOTING.ko.md) · [보안 안내](SECURITY.md)

> **비공식 프로젝트**: EFM네트웍스/ipTIME에서 제작하거나 지원하는 공식 프로그램이 아닙니다.

## 주요 기능

- 공유기 주소(IP 또는 DDNS), 관리 포트, 관리자 ID 및 암호로 접속
- 로그인 후 공유기에 등록된 WOL 대상 PC를 자동 조회
- 선택한 PC에 WOL 명령 전송
- 선택한 PC를 바로 켜는 Windows 바탕화면 원클릭 바로가기 생성
- Windows 계정 기반 DPAPI로 **로컬에 저장하는 암호** 보호
- Python, 별도 라이브러리 또는 설치 프로그램 불필요 (Windows 기본 PowerShell 사용)

## 검증 범위

| 구분 | 내용 |
| --- | --- |
| 사용 보고가 있는 공유기 | **ipTIME BE5100M** |
| 펌웨어 | **15.36.0** |
| 운영 체제 | Windows 10/11, **x64** 용으로 구성 |
| 검증 내용 | 사용자가 로그인, WOL 대상 조회 및 전원 켜기 기능의 정상 작동을 보고함 |
| 다른 모델/버전 | 호환 가능성은 있지만 **검증되지 않음** |

소스의 Windows용 빌드 및 실행 파일 포함 여부는 정적으로 확인했습니다. 모든 Windows 버전·공유기 조합에서의 동작을 보증하지 않습니다.

## 다운로드 및 실행

1. 이 저장소의 **`bin/ipTIME-WOL.exe`** 파일을 내려받거나 [Releases](../../releases)에서 배포 파일을 받습니다. (Releases는 저장소 관리자가 릴리스를 게시한 뒤 이용할 수 있습니다.)
2. 실행 파일을 **앞으로 이동하지 않을 폴더**에 저장한 후 더블클릭합니다.
3. `공유기 접속 주소`(예: `your-router.iptime.org`), `포트`, `프로토콜(HTTP/HTTPS)`, `관리자 ID`, `관리자 암호`를 입력합니다.
4. **`1. 로그인 및 목록 조회`** → PC 선택 → **`2. 선택한 PC 켜기`**를 클릭합니다.
5. 원클릭 실행을 사용하려면 대상 PC 선택 후 **`3. 원클릭 아이콘 생성`**을 누릅니다.
6. 이후 바탕화면의 **`PC 켜기 (ipTIME)`** 바로가기를 더블클릭하면 저장된 대상에 WOL을 요청합니다.

> **중요:** 바로가기는 원래 실행 파일의 경로를 참조합니다. 바로가기 생성 후 `ipTIME-WOL.exe`를 다른 경로로 이동하면 다시 생성해야 합니다.

## 사전 준비

- ipTIME 공유기에서 WOL 대상 PC가 등록되어 있어야 합니다.
- 외부망에서 접속하려면 공유기의 원격 관리가 정상 설정되고 DDNS/IP 및 관리 포트로 접근 가능해야 합니다. 라우터 구성에 따라 VPN 사용도 가능합니다.
- 대상 PC의 BIOS/UEFI, 네트워크 어댑터 및 운영체제에서 WOL이 활성화되어 있어야 합니다. 대개 유선 LAN 연결이 필요합니다.
- 공유기 설정 화면에서 WOL을 직접 실행할 수 있는지 먼저 확인하면 문제 원인을 구분하기 쉽습니다.

## HTTPS 및 보안 안내

**HTTPS 연결은 공유기에서 별도로 설정해야 합니다. 이 프로그램은 HTTPS를 자동 설정하거나 강제하지 않습니다.**

- 프로그램에서 HTTP와 HTTPS를 직접 선택할 수 있습니다.
- **HTTP로 외부망의 공유기 관리자 페이지에 로그인하면 관리자 비밀번호가 전송 구간에서 암호화되지 않습니다.** HTTPS 또는 VPN 연결을 권장합니다.
- HTTPS 인증서 검증은 우회하지 않습니다. 공유기에서 사용 중인 인증서의 유효성과 호스트 이름이 일치해야 합니다.
- 저장된 암호는 Windows 사용자 계정에 연결된 DPAPI로 암호화합니다. 다만 접속 주소, 관리자 ID, MAC 등은 설정 파일에 일반 텍스트로 보관됩니다.
- 공유기 WOL 명령의 성공 응답은 **PC가 부팅 완료되었다는 뜻이 아닙니다.**

자세한 내용: [SECURITY.md](SECURITY.md)

## 설정 저장 위치 및 삭제

원클릭 바로가기 생성 시 다음 파일에 연결 정보 및 선택한 대상 PC가 저장됩니다.

`%LOCALAPPDATA%\ipTIME-WOL\settings.json`

설정을 초기화하려면 앱을 종료한 뒤 이 파일을 삭제합니다. 해당 파일은 저장소에 포함되지 않으며, 다른 사람에게 전달하거나 GitHub 이슈에 첨부하지 마십시오.

## 소스 빌드

배포 EXE는 Go로 작성한 실행기 안에 PowerShell GUI를 포함하는 **하나의 Windows 실행 파일**입니다. 실행 시 사용자 임시 폴더에 PowerShell 스크립트를 잠시 생성하고 종료 시 삭제합니다.

- 소스: [`src/main.go`](src/main.go), [`src/ipTIME-WOL.ps1`](src/ipTIME-WOL.ps1)
- 빌드 환경: Go 1.23 이상, Windows PowerShell 5.1 이상
- Windows에서 저장소 루트의 `build.ps1`을 실행하면 `dist/ipTIME-WOL.exe`가 생성됩니다.
- Windows 외의 Go 개발 환경에서는 `GOOS=windows`, `GOARCH=amd64`, `CGO_ENABLED=0`으로 교차 컴파일할 수 있습니다.

자세한 안내: [docs/BUILD.ko.md](docs/BUILD.ko.md)

## 프로젝트 파일

```text
ipTIME-WOL-Windows/
├─ README.md                 # 한국어 소개와 사용법
├─ README.en.md              # English instructions
├─ LICENSE                   # MIT
├─ SECURITY.md               # 암호 저장, HTTP/HTTPS 주의사항
├─ CHANGELOG.md              # 변경 이력
├─ CONTRIBUTING.md           # 기여 및 버그 제보
├─ build.ps1                 # Windows 빌드 스크립트
├─ go.mod
├─ src/
│  ├─ main.go                # 단일 EXE 실행기 (Go)
│  └─ ipTIME-WOL.ps1         # GUI, 로그인, 목록 조회, WOL
├─ bin/
│  ├─ ipTIME-WOL.exe         # 바로 실행 가능한 기존 배포 EXE
│  └─ SHA256SUMS.txt         # EXE 무결성 해시
└─ docs/                     # 빌드·프로토콜·문제 해결 문서
```

## API 개요

현재 구현은 관리 포트의 `/cgi/service.cgi`에 JSON 요청을 전송합니다. `session/login` → `wol/show` → `wol/signal` 순서이며, `wol/signal`이 명시적으로 미지원인 경우에만 `wol/wake`를 대체 호출합니다. [구현 상세](docs/PROTOCOL.ko.md)

## 라이선스 및 출처

- 라이선스: [MIT](LICENSE)
- 프로토콜 참고: [maengis/iptime_api](https://github.com/maengis/iptime_api), [boxqkrtm/iptime-wol-fast](https://github.com/boxqkrtm/iptime-wol-fast)
- 이 프로젝트는 위 저장소의 코드를 포함하지 않습니다. 외부 프로젝트별 라이선스는 각각의 원저작자에게 귀속됩니다.
- `ipTIME` 명칭 및 상표는 각 권리자에게 귀속됩니다.

## 면책 고지

이 소프트웨어는 어떠한 보증 없이 제공됩니다. 공유기 관리 포트 노출이나 인증정보 관리에서 발생하는 위험은 사용자가 검토해야 합니다.
