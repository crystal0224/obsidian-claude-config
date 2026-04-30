---
description: Bulk-inject a frontmatter field into matched .md files. Two patterns (insert if existing frontmatter, prepend if not). Dry-run by default; --apply to write.
command-type: mutation
---

# /frontmatter-migrate `<field>` `<value>` `<glob>` `[--apply]`

여러 `.md` 파일에 동일한 frontmatter 필드를 일괄 주입. P1.2-P1.4 에서 24 파일 × 4 라운드 수동 작업했던 패턴을 1 command 로 압축.

## 사용법

```
/frontmatter-migrate command-type diagnostic '~/.claude/commands/find-text.md ~/.claude/commands/sparse-check.md'
/frontmatter-migrate audience LLM '/Users/crystal/Desktop/work/permanent-notes/*.md' --apply
```

## 인수

| 인수 | 의미 | 예시 |
|------|------|------|
| `<field>` | YAML 필드명 | `command-type`, `audience`, `agent-type` |
| `<value>` | 값 (문자열, 따옴표 자동 처리) | `diagnostic`, `LLM`, `mutation` |
| `<glob>` | 대상 파일들 (glob 또는 공백 구분 리스트) | `~/.claude/commands/*.md`, 명시적 파일들 |
| `--apply` | 미지정 시 dry-run, 지정 시 실제 쓰기 | (옵션) |

## 동작 두 패턴

### Pattern A — 파일에 frontmatter 이미 존재
첫 줄이 `---` 이면, 닫는 `---` 직전에 `<field>: <value>` 라인 INSERT.

```
Before:                After:
---                    ---
description: ...       description: ...
---                    <field>: <value>
                       ---
# H1                   # H1
```

### Pattern B — frontmatter 없음
파일 시작에 4-line block PREPEND. `description` 값은 H1 텍스트에서 자동 추출.

```
Before:                After:
# H1                   ---
                       description: <H1 text>
                       <field>: <value>
                       ---

                       # H1
```

## 실행 단계

1. **Glob 확장 + 파일 카운트 보고**
   ```
   Matched 11 files. Patterns: 7 with frontmatter, 4 without.
   ```

2. **Dry-run (--apply 없을 때)**
   - 각 파일의 적용될 변경을 diff 형식으로 표시
   - 파일은 수정하지 않음
   - 마지막에 "Run with --apply to write" 안내

3. **--apply 모드**
   - **확인 게이트** (mutation 명령어 규약): "Will write N files. Proceed? (y/n)"
   - 각 파일 처리, 결과 OK/SKIP/ERROR 보고
   - field 가 `command-type` 인 경우, 종료 후 자동으로 `~/Desktop/new/1-Projects/obsidian-claude-config/scripts/validate-command-types.sh` 실행하여 검증

## 안전장치

- **Pattern A 에서 동일 필드 이미 존재**: SKIP 보고, 덮어쓰지 않음 (충돌 회피)
- **Pattern B 에서 H1 이 없음**: ERROR — 사용자가 description 직접 제공 필요 (`--description="..."` 플래그 추가 가능, 향후)
- **백업**: 변경 전 파일 mtime 기록. 사용자가 git/Time Machine 등 외부 mechanism 으로 복구 (이 명령어는 백업 안 함, 단일 책임)

## 면제 / 예외

- `*.md` 가 아닌 파일은 silently skip
- 빈 파일은 ERROR (frontmatter 만 있는 파일은 의미 없음)
- 심볼릭 링크는 target 을 따라가서 수정 (Crystal 의 plugin 패턴과 일관)

## 사용 시나리오

이 명령어가 도움 되는 케이스:
- 새 frontmatter 필드 도입 (예: Phase 2 에서 agent-type 추가 시)
- 기존 표준 적용 (Phase 3 에서 영문 description 강제 시)
- 다 vault 가로지르는 일괄 마이그레이션

도움 안 되는 케이스:
- 파일별 다른 값 필요 (스크립트 직접 작성 권장)
- frontmatter 안의 복잡한 구조 (배열, 중첩 객체) 추가 — 이 명령어는 단순 스칼라 필드만 지원

## 관련

- `~/Desktop/new/1-Projects/obsidian-claude-config/scripts/validate-command-types.sh` — `command-type` 필드 검증
- CLAUDE.md "## 명령어 실행 규칙 (command-type 기반)" — diagnostic/mutation/meta 분류 규약
- spec: `~/Desktop/new/1-Projects/obsidian-claude-config/specs/2026-04-30-cmds-inspired-claude-config-design.md` (§3 C2)
