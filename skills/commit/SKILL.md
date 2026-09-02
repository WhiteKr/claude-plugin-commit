---
name: commit
description: git commit 작성 규칙. 사용자가 /commit 을 치거나 "커밋해줘", "commit" 등 커밋을 지시할 때 로드한다. 변경 분리, 메시지 관습, 스테이징 원칙을 담는다.
argument-hint: '[<target>]'
---

# Commit

커밋 하나는 자기완결적인 변경 하나만 담는다.

## 절차

1. `git status`, `git diff`, `git log --oneline -20` 을 확인한다. `$ARGUMENTS` 가 있으면 그것이 이번 커밋 대상이다.
2. 무관한 변경이 섞여 있으면 부분 스테이징(`git add -p` 또는 `git apply --cached`)으로 나눈다.
3. 지시받지 않은 기존 변경이 섞여 있으면 함께 커밋하지 말고 보고한다.
4. `git diff --cached` 로 스테이징 내용을 확인한 뒤 커밋한다.

## 메시지

최근 커밋 로그를 표본으로 저장소의 언어·형식·scope 관습을 따른다. 관습이 없거나 불분명하면 아래를 쓴다.

- 형식은 Conventional Commits를 따르되, scope는 패키지 경계가 뚜렷할 때만 쓴다.
- description이 한국어면 명사 종결로 쓴다. `타임아웃 처리 추가`처럼 행위 명사로 끝낸다.
- subject 한 줄로 끝낸다. body는 이유를 코드에서 읽을 수 없을 때만 붙인다.
