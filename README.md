# commit

git commit 작성 규칙 스킬. 커밋 하나에 자기완결적인 변경 하나, 메시지는 저장소 관습 우선.

## 설치

```
/plugin marketplace add WhiteKr/whitekr-claude-plugins
/plugin install commit@whitekr-claude-plugins
```

## 사용

```
/commit [<target>]
```

`/commit` 또는 "커밋해줘" 같은 지시에 스킬이 로드된다. `<target>` 으로 커밋 대상을 지정할 수 있다.

## 규칙

- 무관한 변경은 부분 스테이징으로 나눠 커밋한다.
- 지시받지 않은 기존 변경은 커밋하지 않고 보고한다.
- 메시지는 최근 커밋 로그의 언어·형식·scope 관습을 따른다. 관습이 없으면 Conventional Commits, 한국어는 명사 종결, subject 한 줄.
