# obsidian-claude-config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the 4 patterns adopted in the design spec (`specs/2026-04-30-cmds-inspired-claude-config-design.md`) — split monolithic CLAUDE.md into auto-loading skills, add English description standard for AI-searchable Obsidian notes, classify 24 slash commands by side-effect risk, and fold audit-trail into the note skill.

**Architecture:** Plugin-style repo at `~/Desktop/new/1-Projects/obsidian-claude-config/` (source of truth) with skills/commands symlinked to `~/.claude/skills/` and `~/.claude/commands/` (active install). Implementation in 3 phases ordered by risk (low → medium → net-new). Each phase ends with a smoke test in a fresh session because skill registry only loads at session start.

**Tech Stack:** Bash (validators + sed-aware edits), Markdown (skills, commands, CLAUDE.md), YAML frontmatter, Git (per-task commits), gh CLI (push).

**Critical guardrail:** Crystal's persona section (부정사전, 긍정 선호, 상호작용 리듬, 4공리) must NOT be moved out of CLAUDE.md. It is the only content that must remain always-loaded across all sessions. Any task that touches CLAUDE.md verifies persona presence after edit.

---

## Phase 1 — §3: Command-type classification (LOW RISK)

24 command files in `~/.claude/commands/` get a `command-type: diagnostic | mutation | meta` field; CLAUDE.md gets one execution-rules paragraph. No new skills, no symlinks, fully reversible.

### Task 1.1: Create command-type validator script

**Files:**
- Create: `~/Desktop/new/1-Projects/obsidian-claude-config/scripts/validate-command-types.sh`

- [ ] **Step 1: Write the validator**

```bash
#!/bin/bash
# Validates that all ~/.claude/commands/*.md have a command-type field
# with value in {diagnostic, mutation, meta}.
# Exit 0 if all pass, 1 if any fail.

set -e

COMMANDS_DIR="${HOME}/.claude/commands"
VALID_TYPES=("diagnostic" "mutation" "meta")
errors=0
total=0

for file in "${COMMANDS_DIR}"/*.md; do
  total=$((total+1))
  basename=$(basename "${file}")
  type=$(awk '/^---$/{f=!f; next} f && /^command-type:[[:space:]]*/{
    sub(/^command-type:[[:space:]]*/, ""); print; exit
  }' "${file}")

  if [ -z "${type}" ]; then
    echo "MISS  ${basename}: no command-type field"
    errors=$((errors+1))
    continue
  fi

  if [[ ! " ${VALID_TYPES[*]} " =~ " ${type} " ]]; then
    echo "BAD   ${basename}: invalid value '${type}'"
    errors=$((errors+1))
    continue
  fi

  echo "OK    ${basename}: ${type}"
done

echo ""
echo "Total: ${total} files, ${errors} errors"
[ "${errors}" -eq 0 ] && exit 0 || exit 1
```

- [ ] **Step 2: Make executable**

```bash
chmod +x ~/Desktop/new/1-Projects/obsidian-claude-config/scripts/validate-command-types.sh
```

- [ ] **Step 3: Run it (expect FAIL)**

```bash
~/Desktop/new/1-Projects/obsidian-claude-config/scripts/validate-command-types.sh
```

Expected: 24 `MISS` lines, exit 1. This is the failing test for Phase 1.

### Task 1.2: Add `command-type: diagnostic` to 11 commands

**Files (all in `~/.claude/commands/`):**
- Modify (existing frontmatter): `find-text.md`, `sparse-check.md`, `xlsx-spot-check.md`, `project-status.md`, `agent-format-check.md`, `lint-exceptions-check.md`, `pypi-verify.md` (7 files)
- Modify (no frontmatter — add full block): `crystal-negatives-check.md`, `openapi-check.md`, `railway-status.md`, `xlsx-schema-dump.md` (4 files)

- [ ] **Step 1: For files WITH existing frontmatter — insert one line**

For each of the 7 files, add `command-type: diagnostic` as the last line inside the `---` block. Example for `sparse-check.md`:

Before:
```yaml
---
description: APFS sparse file 진단 — stat / du / file / wc 한 번에 실행 + verdict
---
```

After:
```yaml
---
description: APFS sparse file 진단 — stat / du / file / wc 한 번에 실행 + verdict
command-type: diagnostic
---
```

Repeat for: `find-text.md`, `xlsx-spot-check.md`, `project-status.md`, `agent-format-check.md`, `lint-exceptions-check.md`, `pypi-verify.md`.

- [ ] **Step 2: For files WITHOUT frontmatter — prepend a 4-line block**

For each of the 4 files, prepend a frontmatter block with a `description` synthesized from the file's H1 line, plus `command-type`. Example for `crystal-negatives-check.md`:

Before (file starts with content):
```markdown
# Crystal Negatives Check
...
```

After:
```markdown
---
description: Crystal Negatives Check
command-type: diagnostic
---

# Crystal Negatives Check
...
```

Specific descriptions for the 4 files:

| File | description: |
|------|--------------|
| `crystal-negatives-check.md` | `Crystal Negatives Check` |
| `openapi-check.md` | `OpenAPI Check` |
| `railway-status.md` | `Railway Status` |
| `xlsx-schema-dump.md` | `xlsx Schema Dump` |

- [ ] **Step 3: Run validator on diagnostic batch**

```bash
~/Desktop/new/1-Projects/obsidian-claude-config/scripts/validate-command-types.sh | grep -E "diagnostic|MISS|BAD"
```

Expected: 11 lines showing `OK ... diagnostic`, plus the remaining 13 commands still showing `MISS`. Exit 1 still.

### Task 1.3: Add `command-type: mutation` to 10 commands

**Files (all in `~/.claude/commands/`):**
- Modify (existing frontmatter): `fifo-commit.md`, `git-sync-recover.md`, `netlify-prep.md`, `railway-env-push.md`, `rehearsal.md` (5 files)
- Modify (no frontmatter): `sk-deploy.md`, `ss.md`, `tsc-quick.md`, `railway-safe-deploy.md`, `ttimes-deploy.md` (5 files)

Wait — verify `ttimes-deploy.md` exists. If not, the spec inventory was wrong and only 9 mutation commands.

- [ ] **Step 1: Verify ttimes-deploy.md presence**

```bash
ls ~/.claude/commands/ttimes-deploy.md 2>&1
```

If "No such file": adjust the count in this task to 9 mutations. If file exists: proceed with 10.

- [ ] **Step 2: For files WITH frontmatter — insert one line**

Add `command-type: mutation` to the 5 files that have frontmatter (`fifo-commit.md`, `git-sync-recover.md`, `netlify-prep.md`, `railway-env-push.md`, `rehearsal.md`).

- [ ] **Step 3: For files WITHOUT frontmatter — prepend block**

Same pattern as Task 1.2 Step 2. Specific descriptions:

| File | description: |
|------|--------------|
| `sk-deploy.md` | `SK Self-Profiling 배포` |
| `ss.md` | `스크린샷 + 분석` |
| `tsc-quick.md` | `TSC Quick` |
| `railway-safe-deploy.md` | `Railway Safe Deploy` |
| `ttimes-deploy.md` | `TTimes 배포` (only if file exists) |

- [ ] **Step 4: Run validator on mutation batch**

```bash
~/Desktop/new/1-Projects/obsidian-claude-config/scripts/validate-command-types.sh | grep mutation
```

Expected: 9 or 10 `OK ... mutation` lines.

### Task 1.4: Add `command-type: meta` to 3 commands

**Files (all in `~/.claude/commands/`, all with existing frontmatter):**
- Modify: `skill-add-branch.md`, `skill-trace-path.md`, `agent-smoke-test.md`

- [ ] **Step 1: Insert one line into each**

Add `command-type: meta` as the last line inside the `---` block of all 3 files.

- [ ] **Step 2: Run final validator (expect PASS)**

```bash
~/Desktop/new/1-Projects/obsidian-claude-config/scripts/validate-command-types.sh
```

Expected: All 24 (or 23) files OK. Exit 0.

If any `MISS` remains: review the count — `draft-linkedin.md` was not classified above. Decide its category (it's `mutation` — it generates content output) and add `command-type: mutation`. Re-run validator.

- [ ] **Step 3: Confirm draft-linkedin classification**

```bash
grep -A1 "^---$" ~/.claude/commands/draft-linkedin.md | head -5
```

If no `command-type` field present: add `command-type: mutation` (it produces a LinkedIn draft note — has output side-effect). Re-run validator until exit 0.

### Task 1.5: Add execution-rules paragraph to CLAUDE.md

**Files:**
- Modify: `~/.claude/CLAUDE.md` — append a new `### 명령어 실행 규칙` subsection inside the existing `## 에이전트 활용` section (around line 50-60 area, between `## 원칙` and the next major section).

- [ ] **Step 1: Identify insertion point**

```bash
grep -n "^## " ~/.claude/CLAUDE.md | head -10
```

Find the line range for `## 에이전트 활용` and `## 원칙` sections.

- [ ] **Step 2: Insert paragraph after `## 원칙` section closes**

Append the following block. Locate the `## 원칙` section, find its closing (next `##` heading or end of section), and insert before that next heading:

```markdown
## 명령어 실행 규칙 (command-type 기반)

각 슬래시 명령어 .md 파일의 frontmatter `command-type` 필드를 확인하여 행동 결정:

- **`diagnostic`**: 호출 즉시 실행, 결과만 보고. 확인 X.
  → 4공리 #1 ("최소 마찰") 자동 적용
- **`mutation`**: 실행 전 1줄 확인 ("X에 Y합니다, 진행할까요?"). deploy/railway/git 계열은 영향 범위 명시.
  → 4공리 #2 ("Explicit Action") 자동 적용
- **`meta`**: 스킬/에이전트/명령어 정의 변경은 같은 세션 효력 없음 — 사용자에게 명시.
  (CLAUDE.md "Claude Code 스킬 레지스트리 로드 시점" 함정 참조)

새 명령어 추가 시 frontmatter에 `command-type` 필드 누락 안 되게.
검증: `~/Desktop/new/1-Projects/obsidian-claude-config/scripts/validate-command-types.sh`
```

- [ ] **Step 3: Verify CLAUDE.md still loads (lint)**

```bash
wc -l ~/.claude/CLAUDE.md
grep -c "^부정 사전\|^긍정 선호\|^상호작용 리듬" ~/.claude/CLAUDE.md
```

Expected: line count increased by ~14 lines, persona keywords still present (≥1 hit).

### Task 1.6: Phase 1 commit

**Files:**
- All Phase 1 changes

- [ ] **Step 1: Stage repo-side changes**

```bash
cd ~/Desktop/new/1-Projects/obsidian-claude-config
git add scripts/validate-command-types.sh
git status
```

Expected: `scripts/validate-command-types.sh` staged (new file).

- [ ] **Step 2: Stage non-repo changes summary**

The Phase 1 file edits live at `~/.claude/commands/*.md` and `~/.claude/CLAUDE.md` — these are NOT in the repo (this is the install side). For now, those changes stay uncommitted (they will be captured by future symlinks in Phase 2/3).

Optional: copy the modified command files into the repo `commands/` folder as templates for future installs:

```bash
cd ~/Desktop/new/1-Projects/obsidian-claude-config
mkdir -p commands/templates
# Optional — only if user wants to track them:
# cp ~/.claude/commands/*.md commands/templates/
```

For Phase 1, skip the optional copy. Just commit the validator.

- [ ] **Step 3: Commit and push**

```bash
cd ~/Desktop/new/1-Projects/obsidian-claude-config
git commit -m "$(cat <<'EOF'
feat(§3): command-type validator + classify 24 slash commands

- scripts/validate-command-types.sh checks {diagnostic, mutation, meta} field
- Diagnostic (11): find-text, *-check, *-status, find-text, etc.
- Mutation (10-11): deploy/railway/git/build commands
- Meta (3): skill/agent self-management
- ~/.claude/CLAUDE.md gets execution-rules paragraph (off-repo edit)

Phase 1 of the design at specs/2026-04-30-cmds-inspired-claude-config-design.md.
EOF
)"
git push
```

---

## Phase 2 — §1: CLAUDE.md split + 3 skills (MEDIUM RISK)

Extract 3 skills from CLAUDE.md content; slim CLAUDE.md to ~80 lines while keeping persona intact; symlink skills into `~/.claude/skills/`. **Tested only by fresh session at end of phase** because skill registry loads once at session start.

### Task 2.1: Backup current CLAUDE.md

**Files:**
- Create: `~/.claude/CLAUDE.md.backup-pre-§1`

- [ ] **Step 1: Copy current state**

```bash
cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.backup-pre-§1
ls -la ~/.claude/CLAUDE.md.backup-pre-§1
```

Expected: backup file exists, same size as current CLAUDE.md.

### Task 2.2: Create `crystal-multi-agent-orchestration` skill

**Files:**
- Create: `~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-multi-agent-orchestration/SKILL.md`

Content sources (extract from CLAUDE.md, current ~lines 76-216):
- Diff-aware Sync 패턴 section
- orchestrate-audit 2층 체크 section (with all sub-bullets: Spec-Validator, Council, Post-audit Amendments, Worker Bash fallback, etc.)
- 병렬 배치 커밋 게이트 — FIFO 전담 커밋 패턴 section (with 옴니버스 Worker rule)

- [ ] **Step 1: Create directory + write SKILL.md**

```bash
mkdir -p ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-multi-agent-orchestration
```

Then write the SKILL.md file with this structure:

```markdown
---
name: crystal-multi-agent-orchestration
description: Use when designing or executing multi-stage build pipelines (TTS/video/PDF/deploy), dispatching parallel agents requiring verification, or staging batch git commits. Covers Diff-aware Sync caching pattern, orchestrate-audit 2-tier verification (Worker→Auditor→Reviewer), Spec-Validator pre-pass, Council 3-perspective for integration work, Post-audit Amendments pattern, FIFO commit gate, omnibus Worker rule for same-file changes, Worker Bash failure → Main fallback, stale-artifact single-source-of-truth rule.
---

# Crystal Multi-Agent Orchestration Patterns

복잡한 멀티스텝 작업의 설계·실행에서 학습된 패턴 모음. 본문은 CLAUDE.md (366-line monolith) 에서 추출하여 description-trigger 스킬화.

## When this skill activates

다음 키워드/맥락에서 자동 활성:
- "병렬 에이전트", "Worker 디스패치"
- 멀티스테이지 빌드 (TTS · video · PDF · deploy)
- "audit", "council", "code-reviewer 외 추가 검증"
- "/fifo-commit" 또는 batch git 작업
- "옴니버스 Worker", 같은 파일 다중 수정

## 1. Diff-aware Sync 패턴 (2026-04-24+)

[기존 CLAUDE.md 내용 그대로 복사 — Diff-aware Sync 7가지 핵심 + 효과 + 참고 링크]

## 2. orchestrate-audit 2층 체크 (2026-04-19+)

[기존 CLAUDE.md 내용 그대로 — 1층/2층 + Auditor 원칙 + Spec-Validator + Council + Post-audit Amendments + Docs↔Code race + Worker Bash fallback + Audit time vs Build time + Stale 산출물 함정 (전체 11개 sub-bullet 모두)]

## 3. 병렬 배치 커밋 게이트 — FIFO 전담 커밋 패턴 (2026-04-24+)

[기존 CLAUDE.md 내용 그대로 — 증상/복구/예방 옵션 C + 옴니버스 Worker 패턴]

## 위험 신호 (이 패턴들을 어겼을 때)

- "한 Worker 커밋에 다른 Worker 변경분 끼어듦" → FIFO commit 위반
- "Auditor PASS 인데 통합 시점에 버그 발견" → Council 3-perspective 누락
- "Worker 자기보고는 OK인데 코드 미반영" → Auditor 가 자기보고 신뢰함 (코드 직접 Read 안 함)
- "8.3MB pack 0B 됐는데 영구 손실로 판단" → APFS sparse 자연 복구 가능 (별도 skill `crystal-infra-recovery`)
```

**Note:** The `[기존 ... 그대로 복사]` markers are placeholders for the actual content extraction. Implementing engineer must `cat ~/.claude/CLAUDE.md.backup-pre-§1` and copy the matching sections verbatim into each section block.

- [ ] **Step 2: Verify file size and content**

```bash
wc -l ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-multi-agent-orchestration/SKILL.md
grep -c "Diff-aware\|orchestrate-audit\|FIFO" ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-multi-agent-orchestration/SKILL.md
```

Expected: ≥150 lines (substantial), grep ≥3 matches.

### Task 2.3: Create `crystal-infra-recovery` skill

**Files:**
- Create: `~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-infra-recovery/SKILL.md`

Content sources (from CLAUDE.md backup):
- 편집기 자동저장의 인라인 CSS 삽입 주의 section
- APFS 스파스 파일 복구 패턴 section (full content including diagnostic, natural recovery insight, recovery order)
- Vite 번들 제외 — CDN dynamic import 패턴 section

- [ ] **Step 1: Create directory + write SKILL.md**

```bash
mkdir -p ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-infra-recovery
```

Structure:

```markdown
---
name: crystal-infra-recovery
description: Use when investigating macOS APFS sparse files (logical N bytes but du shows 0B), Vite builds hanging at transform stage with no output, or Obsidian browser-based slide editor injecting fixed-px CSS that breaks cqw responsive layouts. Covers root causes, diagnostic gates, and recovery procedures including the natural-recovery wait pattern for APFS, vite-ignore CDN dynamic import for ML/WASM packages, and pre-deploy regex scan for inline px styles.
---

# Crystal Infra Recovery — macOS / Vite / Obsidian Editor

Mac (APFS) · Vite build · Obsidian 편집기 자동저장의 함정 3개 모음.

## When this skill activates

- "0B 파일", "스파스", "logical vs physical" mismatch
- "vite build 멈춤", "transform 단계 출력 0"
- "고정 px width", "cqw 깨짐", "Obsidian 편집기 자동저장"

## 1. 편집기 자동저장의 인라인 CSS 삽입 주의

[CLAUDE.md 원문 — pre-deploy regex `grep 'width: [0-9]*px'` 권장]

## 2. APFS 스파스 파일 복구 패턴 (2026-04-26+)

[CLAUDE.md 원문 — `tmutil destinationinfo` 1순위, du -h 0B ≠ 영구 손실, 자연 복구 인사이트, 복구 순서 3단계]

## 3. Vite 번들 제외 — CDN dynamic import 패턴 (2026-04-26+)

[CLAUDE.md 원문 — `/* @vite-ignore */` + 부수 학습 (vite stdout buffering)]
```

**Note:** Engineer fills `[CLAUDE.md 원문]` brackets with verbatim section content from `~/.claude/CLAUDE.md.backup-pre-§1`.

- [ ] **Step 2: Verify**

```bash
wc -l ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-infra-recovery/SKILL.md
grep -c "APFS\|vite-ignore\|편집기" ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-infra-recovery/SKILL.md
```

Expected: ≥80 lines, grep ≥3 matches.

### Task 2.4: Create `crystal-plugin-dev` skill

**Files:**
- Create: `~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-plugin-dev/SKILL.md`

Content sources (from CLAUDE.md backup):
- 플러그인 구조 + 메타데이터 + 로컬 테스트 + GitHub 배포 sections (~lines 217-280)
- 스킬 작성 시 주의사항 sub-sections (CLAUDECODE 환경 변수, 도구 미사용 단계, 플레이스홀더 정확 일치, vite build TS, AskUserQuestion options, custom 에이전트 frontmatter, 레지스트리 로드 시점)

- [ ] **Step 1: Create directory + write SKILL.md**

```bash
mkdir -p ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-plugin-dev
```

Structure:

```markdown
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

[CLAUDE.md 원문 — 디렉토리 구조 + plugin.json 메타데이터]

## 2. 로컬 테스트 — Symlink 패턴

[CLAUDE.md 원문 — mkdir + ln -s + 테스트 후 정리]

## 3. GitHub 배포

[CLAUDE.md 원문 — 1. Git 저장소 생성 / 2. 사용자 설치 방법]

## 4. Crystal-specific 함정 7개

### CLAUDECODE 환경 변수 — 중첩 claude 호출 불가
[CLAUDE.md 원문]

### 도구 미사용 단계 명시
[CLAUDE.md 원문]

### 플레이스홀더 감지 — 정확 일치 vs 부분 문자열
[CLAUDE.md 원문]

### vite build — tsconfig 없이 TypeScript 검증 가능
[CLAUDE.md 원문]

### AskUserQuestion — 자유 입력 대신 options 활용
[CLAUDE.md 원문]

### Custom 에이전트 — YAML frontmatter 제한사항
[CLAUDE.md 원문 — 작동 패턴 vs 인식 안 되는 패턴]

### Custom 에이전트 — 레지스트리 로드 시점 (세션 라이프사이클)
[CLAUDE.md 원문 — 스냅샷 고정, continuation 세션도 동일, 새 세션 필수]
```

- [ ] **Step 2: Verify**

```bash
wc -l ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-plugin-dev/SKILL.md
grep -c "CLAUDECODE\|레지스트리\|AskUserQuestion\|frontmatter" ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-plugin-dev/SKILL.md
```

Expected: ≥120 lines, grep ≥4 matches.

### Task 2.5: Slim `~/.claude/CLAUDE.md` to ~120 lines

**Files:**
- Modify: `~/.claude/CLAUDE.md`

Target outcome: lines reduced from 366 → ~120 (slightly more than the 80 target in the design, because Phase 1 added 14 lines for execution rules; we keep persona intact at full size).

Sections to KEEP (in order):
1. **NEW: Essential (Post-Compact) — 5 lines** (D3 pattern borrowed)
2. **(promoted)**: Persona section — 부정 사전 / 반복 금기 / 긍정 선호 / 상호작용 리듬 / 페르소나 프로필 / 실행 원칙 4 공리 (current ~lines 303-366)
3. **Skill·Agent 활용 원칙** (current ~lines 31-50, includes the new execution rules from Phase 1)
4. **파일 생성 정책 + 스킬 레지스트리 로드 시점 (간략)** (current intro + brief mention)
5. **프로젝트별 스킬 레퍼런스** — pptx-to-md, my-day1, portfolio-setup, presentation-harness, livekit-agents-checklist, interview-highlight, /railway-env-push (current ~lines 4-26)
6. **NEW: Learned-Patterns Reference** (1 paragraph pointing to 3 new skills)

Sections to REMOVE (now lives in skills):
- Diff-aware Sync 패턴 → `crystal-multi-agent-orchestration`
- 편집기 자동저장 / APFS / Vite CDN → `crystal-infra-recovery`
- orchestrate-audit / FIFO commit → `crystal-multi-agent-orchestration`
- 플러그인 구조 + 스킬 작성 시 주의사항 → `crystal-plugin-dev`

- [ ] **Step 1: Verify backup exists**

```bash
ls -la ~/.claude/CLAUDE.md.backup-pre-§1
```

Expected: file exists, ~366 lines.

- [ ] **Step 2: Create new slim CLAUDE.md**

Write new content to `~/.claude/CLAUDE.md`. Skeleton:

```markdown
# Crystal Personal Operating System

## Essential (Post-Compact)

> 컨텍스트 압축 후에도 반드시 기억:
> 1. **페르소나 코어**: 부정사전 5개 ("엉망진창"/"조잡"/"식상"/"딱딱"/"헐빈")
> 2. **실행 4공리**: 최소 마찰 / Explicit Action / 범위 준수 / Escape Hatch 제공
> 3. **Obsidian 4 vault** (`sk_old`, `work`, `new`, `leadership/기타`) 멀티 운영
> 4. **명령어 분류**: `command-type` 필드 (diagnostic 즉시 / mutation 확인 / meta 새 세션 검증)
> 5. **학습 패턴 3개** auto-loading 스킬: crystal-multi-agent-orchestration / crystal-infra-recovery / crystal-plugin-dev

---

## 1. Persona & Interaction Rules

### 부정 사전 (이 5개가 나오면 즉시 재작업)
[CLAUDE.md.backup §"부정 사전" 섹션 그대로]

### 반복 금기 원칙
[backup §"반복 금기 원칙" 그대로]

### 긍정 선호 (잘 통과하는 접근)
[backup §"긍정 선호" 그대로]

### 상호작용 리듬
[backup §"상호작용 리듬" 그대로]

### 페르소나 프로필
[backup §"페르소나 프로필" 그대로]

### 실행 원칙 (4 Claude Design 공리)
[backup §"실행 원칙" 그대로]

---

## 2. Skill·Agent 활용 원칙

### 스킬 활용
[backup §"스킬 활용" 그대로]

### 에이전트 활용
[backup §"에이전트 활용" 그대로]

### 원칙
[backup §"원칙" 그대로]

### 명령어 실행 규칙 (command-type 기반)
[Phase 1에서 추가한 14줄 그대로 유지]

---

## 3. File Creation Policy

[backup §"# File Creation Policy" 그대로 — `.md 파일을 포함한 모든 파일을 필요할 때 자유롭게 생성할 수 있다...`]

## 4. Claude Code 스킬 레지스트리 로드 시점

[backup §"## Claude Code 스킬 레지스트리 로드 시점" 그대로 — 짧은 1단락]

---

## 5. 프로젝트별 스킬 레퍼런스

[backup §"# Skills" 섹션 그대로 — pptx-to-md / my-day1 / portfolio-setup / presentation-harness / livekit-agents-checklist / interview-highlight / /railway-env-push]

---

## 6. Learned Patterns (auto-loading skills)

학습된 워크플로 패턴은 이제 description-trigger 스킬로 분리. 관련 키워드/맥락에서 자동 로드:

- **crystal-multi-agent-orchestration** — Diff-aware Sync, orchestrate-audit 2층, FIFO commit, 옴니버스 Worker, Council 3-perspective. 트리거: "병렬", "Worker", "audit", "파이프라인"
- **crystal-infra-recovery** — APFS sparse, Vite CDN dynamic import, Obsidian 편집기 px 삽입. 트리거: "0B", "vite hang", "고정 px"
- **crystal-plugin-dev** — Crystal-specific 플러그인/스킬/에이전트 함정 7개. 트리거: "plugin.json", "AskUserQuestion", "frontmatter 인식 안 됨"

소스: ~/Desktop/new/1-Projects/obsidian-claude-config/skills/
```

**Note:** The `[backup §...]` markers indicate verbatim copy from the backup file. Engineer reads the backup, locates the named section, and pastes content into the new CLAUDE.md.

- [ ] **Step 3: Verify size + persona presence**

```bash
wc -l ~/.claude/CLAUDE.md
grep -c "엉망진창\|조잡하다\|식상하다\|딱딱하다\|헐빈하다" ~/.claude/CLAUDE.md
grep -c "최소 마찰\|Explicit Action\|범위 준수\|Escape Hatch" ~/.claude/CLAUDE.md
```

Expected: 100-140 lines (target: ~120). Persona keywords ≥5 hits. 4공리 keywords ≥4 hits.

- [ ] **Step 4: Diff against backup to spot accidental loss**

```bash
diff <(grep "^##" ~/.claude/CLAUDE.md.backup-pre-§1 | sort) \
     <(grep "^##" ~/.claude/CLAUDE.md | sort)
```

Review the diff. Sections that disappeared should ONLY be: `Diff-aware Sync`, `편집기 자동저장`, `APFS 스파스`, `Vite 번들 제외`, `orchestrate-audit`, `병렬 배치 커밋 게이트`, `플러그인 구조`, `로컬 테스트`, `GitHub 배포`, `필수 파일 체크리스트`, `스킬 작성 시 주의사항` (and their sub-sections).

If anything ELSE disappeared (especially persona-related): restore from backup.

### Task 2.6: Symlink skills into `~/.claude/skills/`

**Files:**
- Create: `~/.claude/skills/crystal-multi-agent-orchestration` (symlink)
- Create: `~/.claude/skills/crystal-infra-recovery` (symlink)
- Create: `~/.claude/skills/crystal-plugin-dev` (symlink)

- [ ] **Step 1: Create symlinks**

```bash
ln -s ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-multi-agent-orchestration ~/.claude/skills/crystal-multi-agent-orchestration
ln -s ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-infra-recovery ~/.claude/skills/crystal-infra-recovery
ln -s ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-plugin-dev ~/.claude/skills/crystal-plugin-dev
```

- [ ] **Step 2: Verify symlinks resolve to SKILL.md**

```bash
ls -la ~/.claude/skills/crystal-multi-agent-orchestration/SKILL.md
ls -la ~/.claude/skills/crystal-infra-recovery/SKILL.md
ls -la ~/.claude/skills/crystal-plugin-dev/SKILL.md
```

Expected: each shows the file with size > 0 (resolves through symlink to actual SKILL.md in repo).

### Task 2.7: Phase 2 commit

- [ ] **Step 1: Stage and commit repo changes**

```bash
cd ~/Desktop/new/1-Projects/obsidian-claude-config
git add skills/crystal-multi-agent-orchestration/ skills/crystal-infra-recovery/ skills/crystal-plugin-dev/
git status
```

Expected: 3 new SKILL.md files staged.

- [ ] **Step 2: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(§1): extract 3 auto-loading skills + slim CLAUDE.md

Skills (description-triggered):
- crystal-multi-agent-orchestration: Diff-aware Sync, orchestrate-audit 2-tier, FIFO commit, omnibus Worker
- crystal-infra-recovery: APFS sparse natural-recovery, Vite CDN exclusion, Obsidian editor px injection
- crystal-plugin-dev: 7 Crystal-specific plugin/skill/agent footguns

CLAUDE.md (off-repo):
- 366 lines → ~120 lines
- Persona section preserved verbatim, promoted from bottom to top
- New "Essential (Post-Compact)" 5-line TL;DR (D3 pattern)
- Pattern sections removed (now in skills); reference paragraph added
- Backup at ~/.claude/CLAUDE.md.backup-pre-§1

Symlinks: ~/.claude/skills/crystal-* → repo skills/
Phase 2 of design at specs/2026-04-30-cmds-inspired-claude-config-design.md.
EOF
)"
git push
```

### Task 2.8: Smoke test (FRESH SESSION REQUIRED)

**Important:** Skill registry loads at session start. Following steps must be run in a NEW Claude Code session.

- [ ] **Step 1: Hand-off note for next session**

Tell user:

> Phase 2 done. Skill registry needs a fresh session to load the 3 new skills.
> Next session, please test by saying one of these prompts:
> - "병렬 워커로 작업 분할하고 audit 받고 싶어" → expect crystal-multi-agent-orchestration to auto-load
> - "이 파일이 0B인데 손실된 건가" → expect crystal-infra-recovery to auto-load
> - "plugin.json 작성하는데 함정 있어?" → expect crystal-plugin-dev to auto-load
> If a skill doesn't auto-load: check that ~/.claude/skills/crystal-* symlinks resolve, and that the SKILL.md description contains the trigger keywords.

- [ ] **Step 2: Document smoke-test outcome**

After fresh-session test, document results in:

```bash
cat >> ~/Desktop/new/1-Projects/obsidian-claude-config/specs/2026-04-30-cmds-inspired-claude-config-design.md <<'EOF'

## Phase 2 smoke test results (filled after fresh session)

- [ ] crystal-multi-agent-orchestration auto-loaded: yes/no
- [ ] crystal-infra-recovery auto-loaded: yes/no
- [ ] crystal-plugin-dev auto-loaded: yes/no
- [ ] CLAUDE.md persona keywords still in default context: yes/no
- [ ] CLAUDE.md token load reduced from baseline: yes/no (estimate)
EOF
```

Commit + push the smoke test results once filled.

---

## Phase 3 — §2 + §4: Note frontmatter standard (NET-NEW)

Create `crystal-note-frontmatter` skill (defines 5 required properties + audit-trail optional fields) and `/desc-check` command (read-only diagnostic for missing/Korean/low-info descriptions).

### Task 3.1: Create `crystal-note-frontmatter` skill

**Files:**
- Create: `~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-note-frontmatter/SKILL.md`

- [ ] **Step 1: Create directory + write SKILL.md**

```bash
mkdir -p ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-note-frontmatter
```

Write the following content:

```markdown
---
name: crystal-note-frontmatter
description: Use when creating a new note in any of Crystal's 4 Obsidian vaults if the note will be referenced by AI assistants (Permanent Notes, Project Notes, Output Notes, Reference Notes). Defines the 5 required frontmatter properties with English description rule for LLM searchability. Auto-stubs description and optional command-audit fields when invoked at note creation. Skip for Daily Notes, Inbox clippings, or scratch capture.
---

# Crystal Note Frontmatter Standard

Crystal의 Obsidian 4 vault (`sk_old`, `work`, `new`, `leadership/기타`) 에 신규 노트 작성 시 적용하는 metadata 표준. AI가 노트를 검색·참조할 때 사용하는 영어 description 강제.

## When this skill activates

- "새 노트 만들어", "Permanent Note 작성"
- "Project Note 정리", "Output Note 합성"
- 4개 vault 중 하나에서 신규 .md 파일 작성 흐름

자동 활성 스킵: Daily Notes / Inbox 클리핑 / scratch.

## 5 Required Properties

```yaml
---
type:           # note, meeting, people, terminology, project, output, reference 등
aliases: []
description:    # English 1-2 sentences, action-oriented (REQUIRED)
date created:   # ISO 8601 (YYYY-MM-DD or YYYY-MM-DDTHH:mm)
tags: []
---
```

## description Rule (CRITICAL)

영어로 1-2 문장. Skill/tool description 스타일 — 기계 가독, action-oriented.

❌ 나쁜 예:
- "회의록", "리서치 노트", "강의 자료" (정보 없음)
- "이 노트는 ..." (무의미한 prefix)
- 한국어 (LLM 검색 hint 효과 약함)

✅ 좋은 예:
- "Meeting minutes from 2026-04-19 SK People Intelligence kick-off. Contains stakeholder map and Phase 1 deliverable agreement. Reference when scoping Phase 2 work."
- "Reference notes on Karpathy's nano-LLM tutorial. Maps schema→harness duality to CMDS structure. Use when explaining LLM Wiki to non-technical audiences."
- "Lecture script draft for 2026-05 LG CNS Ch5 (probability). Contains 8-slide structure and narration timing notes. Reference for video render."

## Type→Scope Decision Matrix

| Type | Apply description? |
|------|-------------------|
| `note` (Permanent — evergreen) | ✅ YES |
| `project` (active project tracking) | ✅ YES |
| `output` (lecture/consulting deliverable) | ✅ YES |
| `reference` (resource/link collection) | ✅ YES |
| `meeting` | ✅ YES (search by date+org) |
| `people` | ✅ YES (search by role+context) |
| `daily` | ⏭ skip (ephemeral) |
| `clipping` (Inbox 가공 전) | ⏭ skip |
| `scratch` | ⏭ skip |

## Optional Audit-Trail Fields (§4 absorbed)

노트가 슬래시 명령어 흐름에서 생성되었으면 다음 옵션 필드 stub:

```yaml
createdByCommand: /draft-linkedin   # which command produced this
createdInSession: 2026-04-30        # session date (optional)
sourceRefs:                         # input wikilinks (N→1 traceability)
  - "[[원본 LinkedIn 글 1]]"
  - "[[관련 강의 노트]]"
sessionPurpose: "한 줄 — 왜 만들었는가"
```

비-필수. 빠뜨려도 OK. 스킬은 stub만 제공, 사용자가 채우거나 비움.

## Self-Stub Instructions for Claude

이 스킬이 활성화되어 새 노트를 작성할 때:

1. **type 결정**: 위 매트릭스에서 노트 의도 매칭
2. **description draft**: 1-2 문장 영어. 본문 작성 후 마지막에 갱신.
3. **aliases**: 노트 제목의 한국어/영어 변형
4. **date created**: 오늘 ISO 8601
5. **tags**: 도메인 키워드 3-7개
6. **(옵션)** 명령어 흐름이면 audit-trail 4 fields stub

## Migration Policy

기존 노트 일괄 변경 X. **신규부터만**.
선택적 backfill: `/desc-check` 결과 보고 자주 검색되는 노트만 수동 업데이트.

## Validation

`/desc-check <folder>` 명령어로 description 누락·한국어·저정보 노트 진단.
```

- [ ] **Step 2: Verify**

```bash
wc -l ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-note-frontmatter/SKILL.md
grep -c "description\|type\|action-oriented" ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-note-frontmatter/SKILL.md
```

Expected: ≥80 lines, grep ≥5.

### Task 3.2: Create `/desc-check` command

**Files:**
- Create: `~/Desktop/new/1-Projects/obsidian-claude-config/commands/desc-check.md`

- [ ] **Step 1: Write command spec**

```markdown
---
description: Read-only diagnostic for note description quality across Crystal's Obsidian vaults. Reports missing description, Korean description, and low-information descriptions.
command-type: diagnostic
---

# /desc-check [folder]

Crystal의 Obsidian 노트 frontmatter `description` 필드를 진단. Read-only — 자동 수정 X.

## 사용법

```
/desc-check                          # 현재 디렉토리 .md 스캔
/desc-check ~/Desktop/work           # 지정 폴더
/desc-check ~/Desktop/new --type=output   # 타입별 필터
```

## 검사 항목

1. **MISSING**: frontmatter 또는 description 필드 자체 없음
2. **KOREAN**: description 절반 이상이 한글 (LLM 검색 hint 약화)
3. **LOWINFO**: 5단어 이하 / "이 노트", "this is", "회의록" 같은 무정보 패턴

## 실행 단계

1. 입력 path resolve (없으면 cwd)
2. 재귀적으로 `*.md` 스캔
3. 각 파일에 대해:
   - YAML frontmatter 추출 (`awk '/^---$/{f=!f; next} f{print}'`)
   - `description:` 필드 추출
   - 3가지 검사 적용
4. 결과 분류 출력:
   ```
   [MISSING]
     - path/to/note1.md
     - path/to/note2.md
   [KOREAN]
     - path/to/note3.md → "회의록 정리"
   [LOWINFO]
     - path/to/note4.md → "this is a test"
   
   Total: 42 .md scanned, 3 MISSING, 1 KOREAN, 1 LOWINFO
   ```
5. 면제 타입 (`daily`, `clipping`, `scratch`) 자동 스킵 — 카운트에서 제외하고 별도 표시
6. 자동 수정 X — 사용자가 결과 보고 결정

## 휴리스틱 디테일

- KOREAN 판정: description 문자 중 한글(가-힣) 비율 > 50%
- LOWINFO 판정: 단어 수 ≤ 5 OR 정규식 매칭 `^(이\s*노트|this\s+is|회의록|note|memo)$`

## 면제 타입

스킬 `crystal-note-frontmatter`의 Type→Scope 매트릭스 참조:
- daily / clipping / scratch → 검사 면제

## 출력 예시 빈 vault

```
✓ All 42 notes have valid English description
   (2 daily, 5 clippings, 1 scratch — exempt)
```
```

- [ ] **Step 2: Verify**

```bash
wc -l ~/Desktop/new/1-Projects/obsidian-claude-config/commands/desc-check.md
grep -c "MISSING\|KOREAN\|LOWINFO" ~/Desktop/new/1-Projects/obsidian-claude-config/commands/desc-check.md
```

Expected: ≥40 lines, grep ≥4.

### Task 3.3: Symlink skill + command into `~/.claude/`

**Files:**
- Create: `~/.claude/skills/crystal-note-frontmatter` (symlink)
- Create: `~/.claude/commands/desc-check.md` (symlink)

- [ ] **Step 1: Create symlinks**

```bash
ln -s ~/Desktop/new/1-Projects/obsidian-claude-config/skills/crystal-note-frontmatter ~/.claude/skills/crystal-note-frontmatter
ln -s ~/Desktop/new/1-Projects/obsidian-claude-config/commands/desc-check.md ~/.claude/commands/desc-check.md
```

- [ ] **Step 2: Verify resolution**

```bash
ls -la ~/.claude/skills/crystal-note-frontmatter/SKILL.md
ls -la ~/.claude/commands/desc-check.md
```

Expected: both resolve through symlink to repo files.

- [ ] **Step 3: Re-run command-type validator (regression check)**

```bash
~/Desktop/new/1-Projects/obsidian-claude-config/scripts/validate-command-types.sh
```

Expected: All 25 (or 24+1) commands pass — `desc-check` shows `OK ... diagnostic`.

### Task 3.4: Phase 3 commit

- [ ] **Step 1: Stage and commit**

```bash
cd ~/Desktop/new/1-Projects/obsidian-claude-config
git add skills/crystal-note-frontmatter/ commands/desc-check.md
git status
```

Expected: 2 new files staged (SKILL.md and desc-check.md).

- [ ] **Step 2: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(§2+§4): note frontmatter skill + /desc-check command

Skill (description-triggered for new note creation):
- crystal-note-frontmatter: 5 required properties + English description rule
- Type-based scope (Permanent/Project/Output/Reference; skip Daily/Inbox/scratch)
- Optional audit-trail fields (createdByCommand, sourceRefs, sessionPurpose) — §4 folded in
- Migration policy: new notes only, no bulk rewrite

Command:
- /desc-check: read-only diagnostic for missing/Korean/low-info descriptions
- 3-category output (MISSING / KOREAN / LOWINFO), exempts daily/clipping/scratch
- command-type: diagnostic

Symlinks: ~/.claude/skills/crystal-note-frontmatter, ~/.claude/commands/desc-check.md
Phase 3 of design at specs/2026-04-30-cmds-inspired-claude-config-design.md.
EOF
)"
git push
```

### Task 3.5: Smoke test (FRESH SESSION REQUIRED)

- [ ] **Step 1: Hand-off note for next session**

Tell user:

> Phase 3 done. Fresh session required to load `crystal-note-frontmatter` skill.
> Next session, please test:
> - "새 Permanent Note 만들어줘 — Karpathy 강의 노트" → expect skill to auto-load and ask for English description
> - `/desc-check ~/Desktop/work` → expect diagnostic output with MISSING/KOREAN/LOWINFO categories

- [ ] **Step 2: Update spec with smoke-test results**

Same pattern as Task 2.8 Step 2.

---

## Final task: Update README status

**Files:**
- Modify: `~/Desktop/new/1-Projects/obsidian-claude-config/README.md`

- [ ] **Step 1: Update Status section**

Change checkboxes from:

```markdown
## Status

🟡 **Design phase complete, implementation pending.**

- [x] Spec written and committed
- [ ] §3 — `command-type` field added to 24 commands + CLAUDE.md rule paragraph
- [ ] §1 — 3 skills extracted; CLAUDE.md slimmed to ~80 lines
- [ ] §2 + §4 — `crystal-note-frontmatter` skill + `/desc-check` command
```

To:

```markdown
## Status

🟢 **Implementation complete (smoke tests pending fresh session).**

- [x] Spec written and committed
- [x] §3 — `command-type` field added to 24 commands + CLAUDE.md rule paragraph
- [x] §1 — 3 skills extracted; CLAUDE.md slimmed to ~120 lines
- [x] §2 + §4 — `crystal-note-frontmatter` skill + `/desc-check` command
- [ ] Phase 2 + Phase 3 fresh-session smoke tests (filled in design spec)
```

- [ ] **Step 2: Final commit**

```bash
cd ~/Desktop/new/1-Projects/obsidian-claude-config
git add README.md
git commit -m "docs: mark all 3 implementation phases complete"
git push
```

---

## Self-Review

**Spec coverage:**
- §1 (CLAUDE.md split + 3 skills): Tasks 2.1-2.8 ✓
- §2 (description standard): Tasks 3.1-3.5 ✓
- §3 (command classification): Tasks 1.1-1.6 ✓
- §4 (audit trail folded): inside Task 3.1 ✓
- Persona protection: explicit in Task 2.5 Step 4 (diff check) ✓
- Validator script (§3): Task 1.1 ✓
- Smoke tests: Tasks 2.8 + 3.5 ✓

**Placeholder scan:**
- Skill content sections show `[CLAUDE.md 원문 ...]` markers — these are NOT TBDs but explicit "copy verbatim from this section of the backup" directives. Engineer reads backup, copies content. Acceptable.
- All bash commands are exact and runnable.
- All file paths are absolute and exact.

**Type consistency:**
- `command-type` field name consistent (Phase 1 ↔ desc-check.md ↔ validator script) ✓
- Skill names consistent across spec, plan, README, plugin.json ✓
- `description` field meaning consistent (note frontmatter standard, not skill description — both contexts clear from surrounding) ✓

**Known risk:** Task 1.3 mentions `ttimes-deploy.md` which may not exist (per ls output, it does not). Step 1 of Task 1.3 verifies presence first. If absent, count adjusts to 9 mutations. This is graceful.

---

## Execution Handoff

Plan complete and saved to `~/Desktop/new/1-Projects/obsidian-claude-config/plans/2026-04-30-implementation.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
