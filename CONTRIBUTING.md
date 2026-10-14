# 기여 안내 / Contributing

버그 리포트, 설명서 개선 및 **다른 ipTIME 모델·펌웨어에서의 검증 결과**를 환영합니다.

## 버그 리포트에 필요한 정보

- 공유기 모델명 및 정확한 펌웨어 버전
- Windows 버전과 x64 여부
- 연결 단계: 접속 / 인증 / 목록 조회 / WOL 명령 / 원클릭 바로가기
- 오류 문구 중 개인정보를 제거한 내용
- 공유기 관리자 화면에서 WOL이 동작하는지 여부

**절대 첨부하지 말아야 할 내용:** 암호, `settings.json`, 관리자 ID, 실제 DDNS/공인 IP, 세션 쿠키, 실사용 MAC 주소. 공개 이슈에서는 예시 값으로 대체하십시오.

## 코드 변경

- 실제 장비에서 확인되지 않은 API 방식을 모든 모델에서 동작하는 것처럼 문서화하지 마십시오.
- 로그인/목록 조회/WOL 전송을 각각 별개 결과로 확인할 수 있도록 유지하십시오.
- HTTP를 임의로 금지하지 않되 경고 문구를 제거하거나 인증서 검증을 우회하지 마십시오.
- PowerShell GUI 소스는 `src/ipTIME-WOL.ps1`에 있고 Go 실행기는 `src/main.go`에 있습니다.
- 변경 뒤에는 `build.ps1`로 EXE를 빌드하고, 가능하면 실제 장비에서 검증하십시오.

## English

Contributions and model/firmware compatibility reports are welcome. Please provide the router model, exact firmware version, Windows version, failure stage, and redacted error details. **Never publish credentials, actual router hostnames or IPs, session cookies, saved settings, or real target MAC addresses.** Keep transport-security warnings and TLS validation intact.
