---
name: commit
description: 'Atomic hunk-level git commit workflow. This is the ONLY way to create git commits — never use raw git commit commands without invoking this skill first. Trigger whenever: the user says "commit", "커밋", "변경사항 저장", "커밋해줘", or /commit; the user asks to save/stage/prepare changes; OR you are about to create a git commit as part of any workflow (including plan execution, subagent-driven development, or automated pipelines). Even if a plan document contains commit steps, this skill overrides those instructions.'
user_invocable: true
model: sonnet
effort: medium
---

# Atomic Hunk-Level Commit

논리적으로 응집된 단위로만 commit. 한 commit = 한 의도.

## 원칙

- **Default: hunk-level staging** (`git add -p`). 한 파일 안에 서로 다른 의도의 변경이 섞여 있을 때 필수.
- **File-level 허용**: 새 파일 생성, 또는 파일 안의 모든 hunk가 동일 의도일 때만 `git add <file>` 사용.
- **Co-Authored-By 라인 포함 금지.**
- 메시지 스타일/분리 단위는 아래 가드를 따른다 (최근 log 톤보다 우선).
- **사용자 판단이 필요한 지점은 선택지로**: 그룹 포함 여부·언어·분리 방식처럼 사용자가 결정해야 하는 분기는 열린 질문으로 묻지 말고 서로 구분되는 선택지를 제시해 고르게 한다. 정해진 기본값이 있으면 먼저 적용하고 애매할 때만 묻는다.

## 절차

1. `git status` / `git diff` / `git log --oneline -10` 를 병렬 실행.
2. diff hunk 들을 의도 기준으로 그룹핑. 각 그룹 요약을 선택지로 제시하고 이번 commit 에 포함할 그룹을 사용자가 고르게 한다 (여러 그룹 동시 선택 가능).
3. Untracked 파일이 그룹에 포함되면 `git add -N <file>` 로 intent-to-add 등록.
4. **Hunk 시퀀스 작성 시: `git diff` 출력 순서를 먼저 확인하고 각 응답이 어떤 hunk에 매핑되는지 정확히 매기고 나서** `printf 'y\ny\nn\n...' | git add -p <file>`. 시퀀스가 hunk 순서와 어긋나면 잘못된 hunk 가 staged 됨.
5. `git diff --cached --stat` 로 검증. 의도와 다르면 `git reset HEAD` 후 재시도.
6. Commit 후 `git status` 로 잔여 변경 확인. 남았다면 추가 commit 을 진행할지 여기서 마칠지 선택지로 물어본다.

## 메시지 스타일

**언어**: `git log --oneline -20` 의 기존 commit 다수가 쓰는 언어로 작성한다 (한국어 레포면 한국어, 영어 레포면 영어). 혼재 시 더 최근 다수를 따르고, 판단이 안 서면 어떤 언어로 쓸지 선택지로 물어본다. 톤도 참고하되 아래 가드가 우선한다 — 최근 commit이 모두 AI-스러운 톤이면 모방 루프가 만들어지므로 가드로 끊는다.

언어 무관 가드:

- **자기완결적**: "같은 패턴", "동일하게", "위와 같이"처럼 이전 commit을 알아야 의미가 잡히는 표현 금지. 시리즈 중간 commit도 그 메시지만 읽고 무엇을 했는지 알 수 있어야 함.
- **구현 디테일 -> 행위 본질**: 클래스명/함수명/예외명/파라미터명은 빼되, **효용/맥락 우회는 금지** ("탈퇴 경로 제공" X / "탈퇴 엔드포인트 추가" O).
- **Body는 기본 미사용**: subject 한 줄로 끝. 한 commit이 여러 sub-change를 묶고 subject로 다 못 담을 때만 1-2줄 본문 사용. body에 동기/배경 부연 금지 (diff/blame이 추적).
- **ASCII 기호만**: `·`, `↔`, `→`, `↑` 등 키보드 1타로 안 나오는 기호 금지. `/`, `+`, `,`, `->` 등으로 대체 (연결어는 언어에 맞게: 한국어 `와`, 영어 `and`).

한국어로 작성 시:

- **일상 동사형**으로 짧게: "추가 / 제거 / 수정 / 옮김 / 받기". **한자어 추상명사 다발 회피**: "정합 / 정비 / 통합 / 통일 / 이전 / 정상화" 같은 단어가 한 메시지에 둘 이상이면 다시 쓰기.

영어로 작성 시:

- 소문자로 시작하는 **명령형 동사 원형**으로 짧게: "add / remove / fix / move / pull". 추상 명사화(refactoring, normalization 등 남발) 회피.

## 분리 단위

- **기본은 논리적으로 독립된 변경 단위별 분리** — 한 commit = 독립적으로 리뷰하고 되돌릴 수 있는 하나의 의도. 서로 다른 기능/수정이 한 commit에 섞이지 않게 한다. (모노레포라면 서비스/패키지 경계가, 배포 단위가 나뉜 프로젝트라면 그 단위가 자연스러운 분리선이 된다.)
- **예외: 단일 의도의 기계적 변경** — 동일 심볼 rename, 동일 오타 정정, 동일 import 경로 변경처럼 모든 hunk가 같은 의도를 공유하면 여러 모듈/디렉토리를 가로질러도 한 commit. 메시지는 위치 나열 없이 의도만.
- 분리 방식이 애매하면 가능한 분리안들을 선택지로 제시하고 고르게 한다.
