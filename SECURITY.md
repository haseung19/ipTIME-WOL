# 보안 안내 / Security

## HTTP vs HTTPS

이 프로그램은 HTTP와 HTTPS를 모두 지원하며 **어느 쪽도 강제하지 않습니다.** HTTPS를 사용하려면 **ipTIME 공유기에서 HTTPS 관리자 접속과 인증서를 별도 설정**해야 합니다. 프로그램이 공유기 설정을 변경하지는 않습니다.

- HTTP로 관리자 로그인을 수행하면 관리 계정과 비밀번호가 네트워크 전송 구간에서 **암호화되지 않습니다**. 특히 외부망에서는 HTTPS 또는 VPN을 권장합니다.
- HTTPS를 선택하더라도 유효한 인증서가 필요합니다. 인증서 검증을 무시하거나 자동으로 우회하지 않습니다.
- 원격 관리 인터페이스를 인터넷에 공개할 경우, 누구나 접속을 시도할 수 있습니다. 필요한 접속 범위로 제한하고 계정을 안전하게 관리하십시오.

## 로컬 개인정보 및 설정

원클릭 바로가기를 만들면 `%LOCALAPPDATA%\ipTIME-WOL\settings.json`에 주소, 포트, 관리자 ID, 선택 대상의 이름과 MAC 및 암호화된 비밀번호가 저장됩니다.

- **비밀번호**: Windows PowerShell의 `ConvertFrom-SecureString`을 사용하여 현재 Windows 사용자의 DPAPI로 보호합니다. 다른 Windows 계정이나 PC에서는 일반적으로 복호화할 수 없습니다.
- **다른 값**: 접속 주소, 관리자 ID, 대상 PC 이름/MAC은 암호화되지 않습니다.
- **주의**: 설정 파일이 노출되지 않도록 관리하십시오. 같은 Windows 계정으로 코드를 실행할 수 있는 프로그램에 대해서는 DPAPI가 완전한 격리 수단이 아닙니다.
- 해당 파일은 프로그램 공개 ZIP/저장소에 포함되지 않습니다. 설정을 초기화하려면 프로그램을 종료한 뒤 파일을 삭제하십시오.

## 실행 구조 및 Windows 보안 경고

배포 EXE는 Go 실행기로, PowerShell UI 스크립트를 포함합니다. 실행 시 사용자 임시 폴더에 스크립트를 쓰고 Windows PowerShell 5.1을 `-ExecutionPolicy Bypass` 인수와 함께 실행한 후 종료 시 임시 파일을 삭제합니다. **PowerShell을 실행한다는 점과 실행 정책 우회 인수는 사용자가 판단할 수 있도록 공개합니다.** 정책 설정을 영구 변경하지는 않습니다.

개인 제작 및 미서명 실행 파일은 Windows SmartScreen/보안 솔루션에서 경고를 받을 수 있습니다. 출처를 확인하고 [소스코드](src/) 및 [SHA-256 체크섬](bin/SHA256SUMS.txt)을 검토하십시오. 보안 기능의 비활성화를 권장하지 않습니다.

## API와 동작 범위

- `session/login` → `wol/show` → `wol/signal` (명시적 미지원 시 `wol/wake` 시도)
- 관리자 로그인 실패, WOL 등록 대상 없음, API 오류는 실패로 표시됩니다.
- WOL API가 성공 응답을 보내더라도 실제 PC 부팅 여부를 검증하지 않습니다.
- DDNS/IP와 관리 포트는 사용자가 직접 입력합니다. 프로그램은 포트포워딩이나 공유기 설정을 자동 변경하지 않습니다.

## 버그 및 취약점 제보

버그를 공개 이슈로 남기기 전에 다음 정보를 제거하십시오: 공유기 주소/DDNS, 공인 IP, 관리자 ID, 비밀번호, 세션 쿠키(`efm_session_id`), `settings.json` 및 실제 MAC 주소. 취약점처럼 공개가 위험한 내용은 GitHub 저장소의 **Private vulnerability reporting** 기능이 활성화된 경우 해당 기능을 이용하십시오. 기능이 없으면 인증정보가 포함된 재현 절차를 공개하지 마십시오.

---

**English summary:** HTTP administrator credentials are sent without transport encryption. HTTPS must be configured on the router separately; this app does not enforce it or bypass TLS certificate validation. Passwords saved for one-click use are protected by the current Windows user's DPAPI, while hostnames and MAC addresses are not encrypted. Do not share `settings.json`, session cookies, or credentials. The EXE invokes an embedded PowerShell GUI via a temporary `.ps1` and `-ExecutionPolicy Bypass` (without changing machine policy permanently).
