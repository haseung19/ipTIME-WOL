# 소스 빌드 및 배포

## 바이너리 구조

- `src/main.go`: Go 기반 Windows GUI 실행기. Windows PowerShell을 실행하고 임시 `.ps1` 파일을 종료 시 삭제합니다.
- `src/ipTIME-WOL.ps1`: Windows Forms UI, 인증, WOL 목록 조회, WOL 신호 송신, 바탕화면 바로가기 생성 기능.
- `bin/ipTIME-WOL.exe`: 사용자가 전달받았던 기존 단일 실행 파일을 **수정 없이 포함**한 배포본입니다.

> 실행 중 PowerShell 스크립트가 잠시 임시 폴더에 생성되는 것은 의도된 동작입니다. `-ExecutionPolicy Bypass` 옵션은 해당 PowerShell 프로세스에만 적용되며 시스템 전체 실행 정책을 영구 변경하지 않습니다.

## Windows에서 빌드

필수: **Go 1.23 이상**, Windows 10/11 x64. 프로그램을 실행할 때는 Windows 기본 PowerShell 5.1이 필요합니다.

1. Go를 설치하고 `go version`으로 설치 여부를 확인합니다.
2. 저장소 루트의 `build.ps1`을 PowerShell에서 실행합니다.
3. 컴파일 성공 시 `dist/ipTIME-WOL.exe`가 만들어집니다.
4. 새로운 빌드는 별도로 테스트한 후 배포하십시오.

PowerShell에서 로컬 스크립트 실행 정책에 막힌 경우 컴퓨터의 보안 정책을 임의로 변경하지 마십시오. 신뢰한 저장소인지 확인하고 승인된 방식으로 실행하십시오.

## 해시 확인

포함된 원본 배포본의 SHA-256 값은 [`bin/SHA256SUMS.txt`](../bin/SHA256SUMS.txt)에서 확인할 수 있습니다. Windows에서 `Get-FileHash -Algorithm SHA256 .\bin\ipTIME-WOL.exe` 결과와 비교하십시오.

**소스를 새로 빌드한 파일은 Go 버전, 빌드 옵션 및 빌드 환경에 따라 해시가 다를 수 있습니다.** 파일 해시가 다르다는 사실만으로 악성 파일이거나 동작이 다르다고 판단할 수는 없습니다.

## GitHub 배포

- 사용자가 바로 실행할 파일은 `bin/ipTIME-WOL.exe`입니다.
- GitHub **Releases**를 생성할 때 이 파일을 릴리스 자산(asset)으로 추가하면 사용자가 더 쉽게 받습니다.
- 저장소에 포함된 EXE와 대응하는 PowerShell 소스는 바이트 단위로 대조해 확인했습니다.
- 신규 릴리스에서는 버전, 확인된 공유기/펌웨어, 파일 해시, 변경 사항을 갱신하십시오.
