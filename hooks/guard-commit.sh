#!/usr/bin/env bash
#
# commit 플러그인 가드 (PreToolUse / Bash)
#
# 모델이 임의로 실행하는 raw `git commit` 을 차단하고, 커밋은 사용자가 직접
# `/commit` 으로 실행하도록 안내한다.
#
# 사용자가 `/commit` 으로 스킬을 실행하면 스킬이 commit 명령 앞에 sentinel
# (CLAUDE_COMMIT_SKILL=1) 을 붙인다. 그 sentinel 이 명령 문자열에 있으면 이
# 가드를 통과한다 — 스킬 자신의 commit 도 같은 Bash 도구를 거치므로 bypass 가 필수다.
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

# git commit 계열 탐지: `git` 다음에 옵션(-m, --amend, -C <path> 등)을 거쳐
# `commit` 서브커맨드가 오는 경우. compound 명령(`cd x && git commit`)도 잡는다.
# `git log --grep=commit` 처럼 commit 이 인자로 붙은 경우는 commit 앞이 공백이
# 아니라 제외된다. `git commit-tree` 같은 plumbing 은 commit 뒤가 `-` 라 제외된다.
commit_re='(^|[^[:alnum:]._/-])git([[:space:]]+(-[^[:space:]]+|-[Cc][[:space:]]+[^[:space:]]+))*[[:space:]]+commit([[:space:]]|;|&|\||$)'

# 명령을 셸 구분자(&&, ||, ;, |, &, 개행)로 조각낸 뒤, git commit 을 담은 조각이
# 하나라도 sentinel 로 시작하지 않으면 차단한다. sentinel 은 자기 조각의 commit
# 만 인가하므로 `cd x && CLAUDE_COMMIT_SKILL=1 git commit` 은 통과하고,
# `CLAUDE_COMMIT_SKILL=1 git commit && git commit` 의 두 번째 commit 은 막는다.
# sentinel 이 조각 맨 앞이 아니면 인가 안 되므로 인자에 심는 우회도 막힌다.
if printf '%s' "$command_str" \
  | sed -E 's/(\|\||&&|[;|&])/\n/g' \
  | grep -E "$commit_re" \
  | grep -qvE '^[[:space:]]*CLAUDE_COMMIT_SKILL=1([[:space:]]|$)'; then
  # 차단 + 안내
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"git commit 은 사용자가 직접 /commit 으로 실행하는 워크플로우입니다. 모델이 임의로 커밋하지 않습니다. 지금 변경을 커밋하지 말고, 무엇을 커밋할지 한두 줄로 요약한 뒤 사용자에게 '/commit' 입력을 안내하세요."}}
JSON
fi

exit 0
