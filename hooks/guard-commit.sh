#!/usr/bin/env bash
#
# commit 플러그인 가드 (PreToolUse / Bash)
#
# 모델이 임의로 실행하는 raw `git commit` 을 차단하고, 커밋은 사용자가 직접
# `/commit` 으로 실행하도록 안내한다.
#
# bypass: commit 명령 조각 맨 앞에 prefix (CLAUDE_SKILL_COMMIT=1) 가 붙어 있으면
# 통과시킨다. /commit 스킬은 자신의 commit 에 이 prefix 를 붙여 가드를 지난다 —
# 스킬 자신의 commit 도 같은 Bash 도구를 거치므로 bypass 가 필수다.
#
# 한계: 사용자가 `!git commit ...` (bang 셸 모드) 로 직접 친 명령은 모델의 도구
# 호출이 아니므로 이 hook 이 발동하지 않는다. 그건 사용자 본인의 직접 실행이라
# 차단 대상이 아니다.
#
set -uo pipefail

input=$(cat)

# 빠른 경로: 이 hook 은 모든 Bash 도구 호출마다 실행된다. 명령에 "commit" 이
# 없으면 가드 대상이 아니므로 jq/grep 을 spawn 하기 전에 즉시 통과한다.
# (`git commit` 은 반드시 "commit" 을 포함하므로 놓치는 commit 은 없다.)
case $input in
  *commit*) ;;
  *) exit 0 ;;
esac

# jq 부재 시 명령을 정확히 파싱할 수 없으므로 가드를 통과시킨다(README 에 jq 필요 명시).
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

command_str=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || printf '')

# git commit 계열 탐지: `git` 다음에 옵션(값을 받는 옵션 포함, 예: -m, --amend,
# -C <path>, --author <값>)을 거쳐 `commit` 서브커맨드가 오는 경우. 각 옵션은 뒤에
# 비-옵션 값 토큰을 하나까지 소비할 수 있어 `git --author A commit` 류도 잡는다
# (값에 공백이 있던 경우는 아래 awk 전처리에서 Q 로 축약됨). compound 명령(`cd x && git commit`)도 잡는다.
# `git log --grep=commit` 처럼 commit 이 인자면 commit 앞에 비-옵션 토큰(log)이 끼어
# 매칭이 끊겨 제외된다. `git commit-tree` 는 commit 뒤가 `-` 라 제외된다.
commit_re='(^|[^[:alnum:]._/-])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([[:space:]]|;|&|\||$)'

# command_str 를 awk 한 패스로 전처리하고 조각낸다:
#  (1) 따옴표 구간("..." / '...')을 placeholder Q 로 축약 — 메시지 안의 셸 구분자
#      (`-m "a && b"`)와 공백 품은 옵션 값(`--author "A B"`)이 분할/매칭을 깨지 않게.
#  (2) 셸 구분자(&&, ||, ;, |, &)를 개행으로 바꿔 조각낸다. awk 의 gsub 치환부 "\n" 은
#      GNU/BSD/mawk 모두 실제 개행으로 해석하므로 sed 의 `\n` 비호환(BSD=리터럴 n)을 피한다.
# 그 뒤 git commit 을 담은 조각 중 sentinel 로 시작하지 않는 조각 수를 grep -c 로 센다
# (grep -q 의 SIGPIPE 가 pipefail 과 얽혀 판정을 뒤집던 문제도 없앤다). sentinel 은 자기
# 조각의 commit 만 인가하므로 `cd x && CLAUDE_SKILL_COMMIT=1 git commit` 은 통과하고,
# `CLAUDE_SKILL_COMMIT=1 git commit && git commit` 의 두 번째는 막힌다.
unguarded=$(printf '%s' "$command_str" \
  | awk '{ gsub(/"[^"]*"/, "Q"); gsub(/'\''[^'\'']*'\''/, "Q"); gsub(/\|\||&&|[;|&]/, "\n") } 1' \
  | grep -E "$commit_re" \
  | grep -cvE '^[[:space:]]*CLAUDE_SKILL_COMMIT=1([[:space:]]|$)')

if [ "${unguarded:-0}" -gt 0 ]; then
  # 차단 + 안내
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"git commit 은 사용자가 직접 /commit 으로 실행하는 워크플로우입니다. 모델이 임의로 커밋하지 않습니다. 지금 변경을 커밋하지 말고, 무엇을 커밋할지 한두 줄로 요약한 뒤 사용자에게 '/commit' 입력을 안내하세요."}}
JSON
fi

exit 0
