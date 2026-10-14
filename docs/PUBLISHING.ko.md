# GitHub Public 업로드 절차

## 처음 게시하는 경우

1. GitHub에서 **New repository**를 선택합니다.
2. 예: `ipTIME-WOL-Windows` 이름을 입력하고 **Public**을 선택합니다.
3. README/Licence/.gitignore 자동 생성 옵션은 선택하지 않습니다. 패키지에 파일이 이미 포함되어 있습니다.
4. ZIP을 압축 해제합니다.
5. 저장소의 **Add file → Upload files**에서 압축 해제한 프로젝트 폴더 **안의 파일과 하위 폴더**를 업로드하고 커밋합니다.
6. 업로드 후 `README.md`, `src/`, `bin/ipTIME-WOL.exe`, `LICENSE`가 보이는지 확인합니다.

ZIP 파일 자체만 업로드하면 README가 저장소 홈에 표시되지 않으므로, 반드시 압축을 해제하여 **내용물**을 업로드하십시오.

## 첫 번째 릴리스 만들기

1. 저장소의 **Releases → Draft a new release**를 선택합니다.
2. 태그 `v0.1.0`, 제목 `v0.1.0 - BE5100M 15.36.0`을 지정합니다.
3. 릴리스 노트에는 `CHANGELOG.md`의 0.1.0 내용과 검증된 공유기/펌웨어 범위를 적습니다.
4. `bin/ipTIME-WOL.exe`를 릴리스 자산으로 업로드합니다.
5. 공개한 릴리스의 파일이 저장소에 포함된 EXE와 동일한지 해시로 확인하십시오.

참고: 이 패키지는 **Git 저장소 데이터(.git)를 포함하지 않습니다.** GitHub에서 저장소를 만들고 최초 커밋하면 됩니다.
