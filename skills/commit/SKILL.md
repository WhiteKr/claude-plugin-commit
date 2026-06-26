---
name: commit
description: 'Atomic hunk-level git commit workflow, run by the user via /commit. Stages hunk-by-hunk so one commit equals one intent, and writes messages following the repository''s existing language and conventions.'
disable-model-invocation: true
model: sonnet
effort: medium
argument-hint: '[<target>]'
---

# Atomic Hunk-Level Commit

논리적으로 응집된 단위로만 commit. 한 commit = 한 의도.

## 원칙

- **Default: hunk-level staging**. 한 파일 안에 서로 다른 의도의 변경이 섞여 있을 때 필수 — 갈라야 할 땐 `git apply --cached` 로 원하는 hunk 만 담은 패치를 적용한다 (절차 3).
- **File-level 허용**: 새 파일 생성, 또는 파일 안의 모든 hunk가 동일 의도일 때만 `git add <file>` 사용.
- **Co-Authored-By 라인 포함 금지.**
- 메시지 스타일/분리 단위는 아래 가드를 따른다 (최근 log 톤보다 우선).
- **사용자 판단이 필요한 지점은 선택지로**: 그룹 포함 여부·언어·분리 방식처럼 사용자가 결정해야 하는 분기는 열린 질문으로 묻지 말고, 그 시점에 사용 가능한 선택형 상호작용 도구를 적극 활용해 서로 구분되는 선택지를 제시하고 고르게 한다. 정해진 기본값이 있으면 먼저 적용하고 애매할 때만 묻는다.
- **commit 명령은 `CLAUDE_SKILL_COMMIT=1` prefix 로 실행** (절차 6 참고) — 가드 hook 을 통과하기 위한 sentinel.

## 절차

1. `git status` / `git diff` / `git log --oneline -10` 를 병렬 실행. 단, `$ARGUMENTS` 가 경로(실재하는 파일/디렉토리, 또는 명백한 경로/glob 형태)로 판단되면 `git status` 와 `git diff` 를 그 경로로 스코프한다 (`git status -- <path>`, `git diff -- <path>`) — 무관한 변경의 diff 가 컨텍스트에 실리지 않게 한다. `git status` 에 **이미 staged 된 변경**("커밋할 변경 사항"/"Changes to be committed")이 있으면 깨끗한 index 에서 시작하기 위해 먼저 처리한다 — 그것이 이번 commit 의도에 속하면 그대로 두고, 아니면 `git reset HEAD` 로 비운다 (남겨두면 절차 4 의 잔여 교차 확인을 통과하면서도 의도 외 변경이 조용히 섞인다).
2. tracked 변경의 `git diff` hunk 들과 `git status` 의 untracked 파일을 의도 기준으로 그룹핑. `$ARGUMENTS` 가 경로면 절차 1 에서 이미 그 경로로 스코프됐으므로 스코프된 변경만 그룹핑한다. 경로가 아닌 자연어 기술이면 그것을 이번 commit 대상의 기술로 보고 부합하는 그룹(들)을 골라 진행한다 (어느 그룹을 가리키는지 모호하면 선택지로 확인). 인자가 없으면 각 그룹 요약을 선택지로 제시하고 이번 commit 에 포함할 그룹을 사용자가 고르게 한다 (여러 그룹 동시 선택 가능).
3. 선택된 그룹을 staging:
   - 새 파일이거나 파일 전체가 한 의도면 `git add <file>`.
   - 한 파일에 여러 의도가 섞여 hunk 를 갈라야 하면 `git diff <file>` 출력에서 **포함할 `@@` 블록만 남긴 패치**를 만들어, 먼저 `git apply --cached --check <patch>` 로 깨끗이 적용되는지 확인한 뒤 `git apply --cached <patch>` 로 적용한다. (`printf 'y\n...' | git add -p` 의 고정 응답 시퀀스는 쓰지 않는다 — `git add -p` 의 프롬프트 수/종류는 상황에 따라 달라져, 고정 응답이 어긋나면 조용히 틀린 hunk 가 staged 된다.)
4. **staged 검증 (commit 전 필수 게이트)**: `git diff --cached` 로 staged 내용을 **hunk 단위**로 확인한다 (`--stat` 은 파일 단위라 hunk 단위 오류를 못 잡는다). 대조 기준은 *기억 속 의도*가 아니라 *절차 3 에서 담기로 한 구체적 산출물* 이다 — hunk-split 이면 적용한 패치(`@@` 블록 모음), file-level 이면 그 파일의 절차 1 diff 전체. `git apply --cached` 가 오프셋 어긋남으로 엉뚱한 hunk 를 담은 경우 기억과 대조하면 그 오류째로 통과시키게 되므로, 반드시 그 산출물과 줄 단위로 맞춘다:
   - **일치**: staged 의 모든 hunk 가 그 산출물과 줄 단위로 같은가 — 누락된 `@@` 블록도, 딸려온 인접 hunk 도 없는가.
   - **잔여 교차 확인**: `git diff` (unstaged 잔여) 에 이번에 빼기로 한 변경만 남아 있는가 — staged + 잔여를 합치면 절차 1 의 전체 변경과 맞아야 한다.
   - **선(先)staged 점검**: 절차 1 에서 이미 staged 돼 있던 변경이 이번 그룹 소속이 아닌데 섞여 있지 않은가.
   - **비어 있지 않음**: staged 가 비어 있으면 commit 하지 않는다 — 그룹이 0 hunk 로 풀린 것이니 절차 2 로 돌아간다.
   - 하나라도 어긋나면 `git reset HEAD` 로 되돌리고 절차 3 부터 다시 staging 한다. **이 검증을 통과하기 전에는 절차 6 (commit) 으로 넘어가지 않는다.**
5. **메시지 언어 결정**: `git log --oneline -20` 에서 머지 커밋·PR 제목 줄을 빼고 언어별로 세어 다수 언어를 고른다 (혼재면 더 최근 다수, 그래도 모호하면 선택지로 묻는다). 감지한 언어를 한 줄로 밝힌 뒤 그 언어로 쓴다 — 세션·전역의 대화 언어 지시는 여기에 적용하지 않는다 (메시지 스타일의 언어 규칙 우선). 초안을 적은 뒤 commit 직전에 아래 «메시지 스타일» 의 언어무관 가드(자기완결성 / 구현디테일 배제 / body 미사용 / ASCII 기호) 로 한 번 점검하고, 어기면 고쳐 쓴다.
6. **절차 4 의 staged 검증을 통과한 뒤에만** `CLAUDE_SKILL_COMMIT=1 git commit -m "..."` 으로 commit. **`CLAUDE_SKILL_COMMIT=1` prefix 는 이 플러그인 가드 hook 을 통과하기 위한 필수 sentinel** — 빼면 자신의 commit 이 차단된다. 차단(deny) 메시지가 떴다면 prefix 를 빠뜨린 것이므로, 스킬을 중단하거나 사용자에게 되묻지 말고 prefix 를 붙여 같은 commit 을 그대로 재실행한다.
7. Commit 직후 `git show --stat HEAD` (의심되면 `git show HEAD`) 로 방금 commit 이 의도한 파일/hunk 만 담았고 메시지가 제대로 들어갔는지 확인한다. 이어 `git status` 로 잔여 변경을 보고, 남았다면 추가 commit 을 진행할지 여기서 마칠지 선택지로 물어본다.

## 메시지 스타일

**언어**: 커밋 메시지 언어는 저장소의 기존 commit 만으로 결정한다 — 절차 5 에서 세어 정한다 (한국어 레포면 한국어, 영어 레포면 영어). 세션·전역의 "~로 응답하라", "모든 설명·주석·communication 을 ~로" 같은 대화 언어 지시보다 이 규칙이 우선한다 — 커밋 메시지는 사용자에게 보내는 답변이 아니라 저장소 산출물이기 때문이다 (대화는 사용자 언어로, 커밋은 레포 언어로). 톤도 참고하되 아래 가드가 우선한다 — 최근 commit이 모두 AI-스러운 톤이면 모방 루프가 만들어지므로 가드로 끊는다.

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
