# ipTIME WOL 요청 구조

> 아래 API는 비공식 구현을 참고하고 코드에 반영한 방식입니다. ipTIME이 모든 모델/펌웨어에 대해 호환성을 보장하는 공식 공개 API라는 의미가 아닙니다.

## 접속

사용자가 입력한 관리자 접속 주소와 포트를 이용합니다.

`POST http(s)://<router-host>:<management-port>/cgi/service.cgi`

- `Content-Type: application/json; charset=utf-8`
- `Referer: http(s)://<router-host>:<management-port>/ui/`
- `Origin: http(s)://<router-host>:<management-port>`
- HTTP 응답 쿠키는 동일 HTTP 클라이언트 세션에서 유지합니다.

`<router-host>`는 실제 공유기의 IP 또는 DDNS이고, 관리 포트는 공유기에서 설정합니다. HTTPS는 라우터에서 별도로 설정해야 합니다.

## 인증

```json
{"method":"session/login","params":{"id":"<ADMIN_ID>","pw":"<ADMIN_PASSWORD>"}}
```

로그인 응답이 `result: "done"`인지 확인하고 `efm_session_id` 세션 쿠키를 요구합니다.

**중요:** 위의 암호를 포함한 요청을 HTTP로 전송할 경우 네트워크 구간에서 암호화되지 않습니다.

## WOL 대상 조회

```json
{"method":"wol/show"}
```

응답의 장치 이름과 MAC 주소를 파싱하고 중복 MAC을 제거합니다.

## WOL 전송

우선 시도하는 요청:

```json
{"method":"wol/signal","params":["AA-BB-CC-DD-EE-FF"]}
```

공유기가 해당 메서드를 명시적으로 지원하지 않는다고 응답하는 경우에만 다음 대체 호출을 시도합니다.

```json
{"method":"wol/wake","params":{"mac":"AA:BB:CC:DD:EE:FF"}}
```

공유기 응답의 성공 여부는 확인하지만, 대상 PC의 실제 부팅 여부는 확인하지 않습니다.

## 구현 세부

- `src/ipTIME-WOL.ps1`가 API 호출, 응답 검사, 장치 목록 처리, 바로가기 생성을 수행합니다.
- 로컬 설정 암호는 Windows DPAPI로 보호되며, 공유기 세션 쿠키는 HTTP 클라이언트 쿠키 컨테이너에 유지됩니다.
- 인증서 검증을 비활성화하지 않습니다.

## 참고 자료

- https://github.com/maengis/iptime_api
- https://github.com/boxqkrtm/iptime-wol-fast

두 저장소는 API 동작을 확인하기 위한 **참고 자료**이며, 해당 프로젝트의 코드는 이 저장소에 포함하지 않았습니다. 펌웨어별 실제 응답은 다를 수 있습니다.
