# commit

논리적으로 응집된 단위로만 git commit을 만드는 워크플로우 스킬. 한 commit = 한 의도.

## 설치

```
/plugin marketplace add WhiteKr/whitekr-claude-plugins
/plugin install commit@whitekr-claude-plugins
```

## 사용

```
/commit
```

커밋은 **사용자가 `/commit` 으로 직접 실행할 때만** 동작합니다. 모델은 이 스킬을 스스로 발동하지 않습니다 (`disable-model-invocation: true`) — 커밋 타이밍은 사용자가 쥡니다.

## 동작

- 기본은 **hunk 단위 staging** — 한 파일에 서로 다른 의도가 섞여 있어도 의도별로 나눠 커밋합니다.
- 커밋 메시지는 **레포의 기존 커밋 언어/관례를 따릅니다** (한국어 레포면 한국어, 영어 레포면 영어).
- Co-Authored-By 라인을 넣지 않습니다.

## 가드 hook

모델이 `/commit` 을 거치지 않고 임의로 `git commit` 을 실행하려 하면, PreToolUse hook(`hooks/guard-commit.sh`)이 이를 차단하고 변경 요약 후 사용자에게 `/commit` 입력을 안내하도록 모델을 되돌립니다. 커밋 거버넌스를 사용자 트리거 전용으로 강제하는 장치입니다.

- 스킬이 `/commit` 으로 실행하는 commit 은 명령에 sentinel(`CLAUDE_COMMIT_SKILL=1`)을 붙여 가드를 통과합니다.
- hook 은 stdin JSON 파싱에 `jq` 를 사용합니다. `jq` 가 없으면 가드는 통과(no-op)합니다.
- **한계**: 사용자가 `!git commit ...`(bang 셸 모드)로 직접 친 명령은 모델의 도구 호출이 아니므로 hook 이 발동하지 않습니다. 이는 사용자 본인의 직접 실행이라 차단 대상이 아닙니다.
