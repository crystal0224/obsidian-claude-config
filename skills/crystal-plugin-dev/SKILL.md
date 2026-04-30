---
name: crystal-plugin-dev
description: Use when working with Crystal-specific Claude Code plugin/skill/agent gotchas. Covers CLAUDECODE env nesting (cannot call claude inside a session), tool-use-omission explicit declaration, exact-match vs substring placeholder detection, vite build for quick TS sanity check, AskUserQuestion with options instead of free text, custom agent YAML frontmatter restrictions (single-line description only, no tools/model fields), and the skill/agent registry session-lifecycle trap (changes don't take effect in the same session). Complements (does not replace) plugin-dev:plugin-structure / skill-creator skills.
---

# Crystal Plugin Dev — Crystal-specific Footguns

본인 환경에서 직접 부딪힌 함정만 모은 reference. 일반 플러그인 가이드는 `plugin-dev:*` / `skill-creator` 스킬 사용.

## When this skill activates

- 플러그인 구조 작업 (`.claude-plugin/plugin.json`, GitHub deploy)
- custom agent 추가 (frontmatter 인식 안 될 때)
- 스킬 작성 후 같은 세션에서 동작 안 함 → 레지스트리 로드 시점 트랩
- AskUserQuestion 분기 불안정

## 1. 플러그인 구조 (참조용)

Claude Code 플러그인은 다음 구조를 따른다:
```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # 플러그인 메타데이터 (필수)
├── skills/
│   ├── skill-name.md        # 메인 스킬 파일 (frontmatter 필수)
│   └── references/          # 참조 파일들
└── README.md
```

플러그인 메타데이터 (`plugin.json`):
```json
{
  "name": "plugin-name",
  "description": "플러그인 설명",
  "version": "1.0.0",
  "author": {
    "name": "작성자",
    "email": "email@example.com"
  },
  "homepage": "https://github.com/username/plugin-name",
  "repository": {
    "type": "git",
    "url": "https://github.com/username/plugin-name.git"
  },
  "keywords": ["keyword1", "keyword2"],
  "skills": "./skills/"
}
```

## 2. 로컬 테스트 — Symlink 패턴

### 심볼릭 링크 (개발 중 추천)
```bash
mkdir -p ~/.claude/skills/plugin-name
ln -s ~/path/to/plugin/skills/skill-name.md ~/.claude/skills/plugin-name/SKILL.md
ln -s ~/path/to/plugin/skills/references ~/.claude/skills/plugin-name/references
```

### 테스트 실행
```bash
claude
/plugin-name
```

### 테스트 후 정리
```bash
rm -rf ~/.claude/skills/plugin-name
# 또는 백업 복원
mv ~/.claude/skills/plugin-name.backup ~/.claude/skills/plugin-name
```

## 3. GitHub 배포

### 1. Git 저장소 생성 및 푸시
```bash
cd ~/path/to/plugin
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/username/plugin-name.git
git push -u origin main
```

### 2. 사용자 설치 방법
```bash
# Claude Code에서 설치
/plugin install username/plugin-name

# 또는 Git 클론 후 설치
git clone https://github.com/username/plugin-name.git
cd plugin-name
claude plugin install .
```

### 필수 파일 체크리스트
- [ ] `.claude-plugin/plugin.json` - 메타데이터
- [ ] `skills/skill-name.md` - 메인 스킬 (frontmatter 포함)
- [ ] `README.md` - 사용 설명서
- [ ] `LICENSE` - 라이선스 파일 (MIT 권장)
- [ ] `.gitignore` - 불필요한 파일 제외

## 4. Crystal-specific 함정 7개

### CLAUDECODE 환경 변수 — 중첩 claude 호출 불가
`CLAUDECODE=1` 환경 변수가 설정되어 있으면 Claude Code 세션 내부에서
`claude` CLI를 다시 호출할 수 없다. (중첩 세션 차단)
스킬에서 외부 스크립트(예: convert_resume.py)를 사용자에게 안내할 때
반드시 "별도 터미널에서 실행"임을 명시해야 한다.

### 도구 미사용 단계 명시
스킬의 특정 단계에서 아무 도구도 호출하지 말아야 할 경우,
명시적으로 "(어떤 도구도 사용하지 않습니다)" 라고 적어야 한다.
안 적으면 Claude가 불필요한 도구를 호출할 수 있다.

### 플레이스홀더 감지 — 정확 일치 vs 부분 문자열
이메일 같은 필드의 플레이스홀더 감지는 부분 일치(substring)가 아닌
정확 일치(exact match)로 해야 한다.
예: `email === "hong@example.com"` (O) / `email.includes("example")` (X)
실제 이메일에 "example"이 포함될 수 있기 때문.

### vite build — tsconfig 없이 TypeScript 검증 가능
`vite build`는 tsconfig.json 없이도 TypeScript 파일의 문법 오류를 잡아낸다.
스킬 스모크 테스트 시 빠른 검증 수단으로 사용할 수 있다.
(단, `tsc --noEmit`보다 검증 수준이 낮으므로 빠른 sanity check 용도로만 사용)

### AskUserQuestion — 자유 입력 대신 options 활용
오류 처리 분기를 자유 텍스트(free text)로 받으면 분기 처리가 불안정하다.
가능한 한 options 목록으로 오류 유형을 제한하면 스킬 흐름이 안정된다.
catch-all은 "기타" 옵션으로 처리하고 graceful fallback을 제공한다.

### Custom 에이전트 — YAML frontmatter 제한사항
에이전트 파일(`.md`)의 YAML frontmatter에 `tools`, `model` 필드나
멀티라인 `description: |` 구문을 사용하면 Task 도구의 에이전트 레지스트리에서
인식되지 않을 수 있다.

**작동하는 패턴** (html-layout-reviewer 등):
```yaml
---
name: my-agent
description: 한 줄로 간결하게 작성한 에이전트 설명
---
```

**인식 안 되는 패턴**:
```yaml
---
name: my-agent
description: |
  여러 줄에 걸친
  상세한 설명
tools:
  - Read
  - Edit
model: sonnet
---
```

**해결 방법:**
1. `description`은 반드시 한 줄로 작성
2. 상세 설명은 frontmatter 아래 본문에 `## Summary` 섹션으로 이동
3. `tools`, `model` 필드 포함 시 인식 여부를 반드시 새 세션에서 테스트
4. 심볼릭 링크 에이전트도 동일 제약 적용됨

### Custom 에이전트 — 레지스트리 로드 시점 (세션 라이프사이클)
에이전트 레지스트리는 **세션 시작 시점에 한 번만 로드**된다.
세션 도중에 생성하거나 수정한 에이전트 파일은 해당 세션에서 Task 도구로 인식되지 않는다.
파일 형식/인코딩이 완전히 정상(UTF-8, BOM 없음, 한 줄 description)이어도 동일하다.

**증상:**
- 에이전트 파일이 `~/.claude/agents/`에 존재하고 형식도 올바르지만
- 같은 세션(또는 continuation 세션) 내에서 Task 도구에 해당 이름이 나타나지 않음

**원인:** 레지스트리는 세션 시작 시 스냅샷으로 고정됨. continuation 세션도 원래 세션의 레지스트리를 그대로 사용.

**에이전트 개발 필수 절차:**
1. 에이전트 파일 생성/수정
2. 형식 검증 (위 frontmatter 제한사항 확인)
3. **현재 세션 완전 종료**
4. 새 세션에서 `Task(subagent_type="agent-name")` 으로 인식 테스트
5. 같은 세션에서 만들고 바로 테스트하면 항상 실패 — 이것은 정상 동작

**디버그 순서:** 형식 문제 vs 레지스트리 로드 시점 문제를 먼저 구분할 것.
`/agent-format-check`로 형식 검증 → 새 세션에서 `/agent-smoke-test`로 인식 확인.
