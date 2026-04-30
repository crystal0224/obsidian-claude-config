---
type: spec
aliases:
  - CMDS Inspired Claude Config
description: Design spec for adopting 4 patterns from johnfkoo951/cmds-system-files into Crystal's Claude Code setup. Splits CLAUDE.md into 3 skills, adds English description standard for AI-searchable notes, classifies 24 commands by side-effect risk, and folds audit trail into the note frontmatter skill. Reference when implementing the customization or when reviewing Crystal's PKM-AI integration philosophy.
date created: 2026-04-30
date modified: 2026-04-30
tags:
  - claude-config
  - pkm
  - obsidian
  - design-spec
status: pending-implementation
sourceRepo: https://github.com/johnfkoo951/cmds-system-files
---

# CMDS-inspired Claude Config Customization (Design)

> **Source**: `johnfkoo951/cmds-system-files` v4.2 (2026-04-15) — public PKM/Claude config of Yohan Koo (10K+ note Obsidian vault)
> **Status**: design approved 2026-04-30, pending implementation
> **Approval gate**: user reviews this doc → /writing-plans → implementation

---

## TL;DR

Adopt **4 of 14** patterns from the CMDS source repo, each adapted to Crystal's environment:

| § | Pattern | Crystal adaptation | Effort |
|---|---------|-------------------|--------|
| §1 | **D1** — split monolithic CLAUDE.md | 366 → ~80 lines + 3 auto-loading skills | 중간 |
| §2 | **D4** — English `description` for LLM searchability | 5 properties (not 7), type-based scope, new notes only | 중간 |
| §3 | **C2** — command-type classification | `diagnostic / mutation / meta` axis (not router/stage) | 낮음 |
| §4 | **C4** — frontmatter audit trail | Absorbed into §2 skill as optional fields | 0 (folded) |

**Net effect**: ~62% reduction in always-loaded CLAUDE.md tokens, AI-searchable notes get traceable English metadata, command behavior auto-aligns with 4공리 (`최소 마찰` / `Explicit Action`).

10 other CMDS patterns explicitly **not** adopted — see "Out of scope".

---

## Source repo analysis

The CMDS repo advertises "8 slash commands + 5 system files + 7 rules". Reality:

- **Slash commands are spec-only** — defined in `files/CLAUDE.md` "CMDS Process Command Suite" section, but actual `.claude/commands/*.md` files are not in the repo. Anyone wanting them must reimplement from spec.
- **5 system files** (`files/`) are personal philosophy + 9-category taxonomy specific to Yohan Koo. Inspirational, not portable.
- **7 rules** (`rules/`) are small, single-purpose, universally portable. The real value.

Crystal's choice: harvest **patterns**, not files. Direct file ports would be wrong shape for a multi-vault, code-development-heavy environment.

---

## §1 — D1: CLAUDE.md split + skill-ify

### Current state

- `~/.claude/CLAUDE.md` — **366 lines, 43 headers, 4 mixed concerns**:
  - 메타: 파일 생성 정책 + 스킬 레퍼런스 4개 + 에이전트/스킬 활용 지침
  - 학습 패턴 6개 (Diff-aware Sync, orchestrate-audit 2층, FIFO commit, APFS sparse, Vite CDN, 편집기 CSS)
  - 플러그인 개발 가이드 (구조, 메타데이터, 로컬 테스트, 함정)
  - 페르소나 (부정사전, 긍정 선호, 상호작용 리듬, 4공리)

### Target structure

```
~/.claude/
├── CLAUDE.md                                 ~80 lines (slim)
├── rules/common/                             unchanged (8 files)
└── skills/
    ├── crystal-multi-agent-orchestration/
    │   └── SKILL.md
    ├── crystal-infra-recovery/
    │   └── SKILL.md
    └── crystal-plugin-dev/
        └── SKILL.md
```

### New CLAUDE.md skeleton (~80 lines)

```markdown
# Crystal Personal Operating System

## Essential (Post-Compact)            ← borrowed D3 pattern (5-line TL;DR)
## 1. Persona & Interaction Rules      ← promoted from bottom; full content preserved
   부정사전 / 긍정 선호 / 상호작용 리듬 / 4공리 / 페르소나 프로필
## 2. Skill·Agent 활용 원칙
   포함: 명령어 실행 규칙 (command-type 기반)        ← §3 추가
## 3. 파일 생성 + 스킬 레지스트리 시점 (간략)
## 4. 프로젝트별 스킬 레퍼런스                       ← presentation-harness 등 그대로
## 5. Note Frontmatter Standard                    ← §2 요약 + skill 호출
```

### Skill A — `crystal-multi-agent-orchestration`

Absorbs: Diff-aware Sync · orchestrate-audit 2층 · FIFO commit · 옴니버스 Worker 패턴 · Worker Bash 권한 fallback · Stale 산출물 함정 · Council 3-perspective · Post-audit Amendments

Frontmatter:
```yaml
---
name: crystal-multi-agent-orchestration
description: Use when designing or executing multi-stage build pipelines (TTS/video/PDF/deploy), dispatching parallel agents requiring verification, or staging batch git commits. Covers Diff-aware Sync caching pattern, orchestrate-audit 2-tier verification (Worker→Auditor→Reviewer), Spec-Validator pre-pass, Council 3-perspective for integration work, Post-audit Amendments pattern, FIFO commit gate, omnibus Worker rule for same-file changes, Worker Bash failure → Main fallback.
---
```

Auto-activation triggers: "병렬", "Worker 디스패치", "파이프라인", "audit", "council", "fifo-commit" 등

### Skill B — `crystal-infra-recovery`

Absorbs: APFS sparse 복구 · Vite CDN dynamic import · 편집기 자동저장 px 삽입

Frontmatter:
```yaml
---
name: crystal-infra-recovery
description: Use when investigating macOS APFS sparse files (logical N bytes but du shows 0B), Vite builds hanging at transform stage with no output, or Obsidian browser-based slide editor injecting fixed-px CSS that breaks cqw responsive layouts. Covers root causes, diagnostic gates, and recovery procedures including the natural-recovery wait pattern for APFS.
---
```

Auto-activation triggers: "0B", "build 멈춤", "vite hang", "고정 px width", "스파스" 등

### Skill C — `crystal-plugin-dev`

Absorbs: 플러그인 구조 / plugin.json / 로컬 테스트 / GitHub 배포 / 스킬 작성 시 함정 (CLAUDECODE env, 도구 미사용 명시, 플레이스홀더 정확 일치, vite build TS 검증, AskUserQuestion options, custom 에이전트 frontmatter 제한, 레지스트리 로드 시점)

Frontmatter:
```yaml
---
name: crystal-plugin-dev
description: Use when working with Crystal-specific Claude Code plugin/skill/agent gotchas. Covers CLAUDECODE env nesting (cannot call claude inside a session), tool-use-omission explicit declaration, exact-match vs substring placeholder detection, vite build for quick TS sanity check, AskUserQuestion with options instead of free text, custom agent YAML frontmatter restrictions (single-line description only, no tools/model fields), and the skill/agent registry session-lifecycle trap (changes don't take effect in the same session). Complements (does not replace) plugin-dev:plugin-structure / skill-creator skills.
---
```

Scope note: General plugin scaffolding is covered by existing `plugin-dev:*` and `skill-creator` skills. This skill covers ONLY Crystal-experienced footguns not found in those.

Auto-activation triggers: "플러그인 만들", "skill 작성", "agent 추가", "plugin.json", "PreToolUse hook" 등

### Why skills (not just split .md files)

- Claude Code natively auto-loads skills based on description matching. No `@include` mechanism needed.
- `livekit-agents-checklist` skill is Crystal's existing precedent for "knowledge gates that auto-fire on context match".
- Splitting to `rules/learned/*.md` would require manual `Read` invocation each time → defeats the purpose.

### Risks

- New vault first session: pattern terms ("Diff-aware Sync") may need 1 round-trip for skill auto-load. Small friction.
- Future pattern additions: must decide which skill to extend. Boundary may blur.
- Persona must NEVER be split out — it's loaded every session, every project.

### Files inventory (§1)

- **Modify**: `~/.claude/CLAUDE.md` (366 → ~80 lines)
- **Create**: 3 new skills under `~/.claude/skills/crystal-*/SKILL.md`

---

## §2 — D4: English `description` standard

### Differences from CMDS

| | CMDS | Crystal |
|---|------|---------|
| Vault count | 1 (10K+ notes) | 4 (`sk_old`, `work`, `new`, `leadership/기타`) |
| Required fields | 7 | **5** (drop `author` for solo, drop `CMDS:` taxonomy field) |
| Scope | All notes | **Type-based** (Permanent / Project / Output / Reference only) |
| Migration | Phased (v1.0 → v4.2) | **None** — new notes only |

### Required 5 properties

```yaml
---
type:           # note, meeting, people, terminology, project, output, reference 등
aliases: []
description:    # English 1-2 sentences, action-oriented (REQUIRED)
date created:   # ISO 8601
tags: []
---
```

### `description` rule (verbatim from CMDS, kept)

> Machine-readable hint for AI agents to decide relevance. Skill/tool description style.

- ❌ "회의록", "리서치 노트", "강의 자료" — no signal
- ✅ "Meeting minutes from 2026-04-19 SK People Intelligence kick-off. Contains stakeholder map and Phase 1 deliverable agreement. Reference when scoping Phase 2 work."

### Scope: type-based (vault-agnostic)

| Apply | Exempt |
|-------|--------|
| Permanent Notes | Daily Notes |
| Project Notes (~/Desktop sync) | Inbox / Clippings (pre-processing) |
| Output Notes (강의/컨설팅 산출물) | Scratch / Quick capture |
| Reference Notes (자료/링크) | |

Decision rule: "AI가 이 노트를 검색해서 읽을 가능성이 있는가?" → 있으면 적용.

### Optional fields (audit trail — §4 absorbed)

When the note is created during a slash command flow:

```yaml
createdByCommand: /draft-linkedin   # which command produced this
createdInSession: 2026-04-30        # session date (optional)
sourceRefs: ["[[원본 1]]", "..."]    # input wikilinks (N→1 traceability)
sessionPurpose: ""                  # one-line why
```

Non-required. Stub when applicable; omit when not.

### Tooling — 2 artifacts

**(1) `crystal-note-frontmatter` skill** ✨

```yaml
---
name: crystal-note-frontmatter
description: Use when creating a new note in any of Crystal's 4 Obsidian vaults if the note will be referenced by AI assistants (Permanent Notes, Project Notes, Output Notes, Reference Notes). Defines the 5 required frontmatter properties with English description rule for LLM searchability. Auto-stubs description and optional command-audit fields when invoked at note creation. Skip for Daily Notes, Inbox clippings, or scratch capture.
---
```

Skill body covers:
- 5 required + audit-trail optional fields
- description English rule + bad/good examples
- Type→scope decision matrix
- Self-stub instructions (when Claude is the one creating the note)

**(2) `/desc-check` command** ✨

```
/desc-check                 → current vault scan
/desc-check <folder>        → folder only
/desc-check --type=output   → filter by type
```

Read-only diagnostic. Reports:
- Missing description
- Korean description (heuristic: contains 가-힣 majority)
- Low-information description (≤ 5 words, contains "노트", "this is", etc.)

No auto-fix. Same look-and-feel as existing `crystal-negatives-check`.

### Files inventory (§2)

- **Create**: `~/.claude/skills/crystal-note-frontmatter/SKILL.md`
- **Create**: `~/.claude/commands/desc-check.md`
- **Migration**: NONE (existing notes untouched)

### Risks

- Type ambiguity ("Project vs Output?") — skill must include disambiguation guidance.
- 30-second-per-note friction for description writing. Mitigated by `crystal-note-frontmatter` skill auto-stubbing a draft for user to refine.

---

## §3 — C2: Command-type classification

### Axis change from CMDS

| | CMDS | Crystal |
|---|------|---------|
| Classification axis | PKM intent (Router / Stage / Orchestrator / Cross-cutting) | **Side-effect risk** (`diagnostic` / `mutation` / `meta`) |
| Friction principle | Proportional to information loss | **Proportional to side-effect risk** (aligns with 4공리) |

### Crystal's 24 commands classified

| Type | Behavior | Commands (count) |
|------|----------|------------------|
| `diagnostic` | Read-only, immediate execute, no confirm | find-text, sparse-check, xlsx-spot-check, xlsx-schema-dump, project-status, agent-format-check, lint-exceptions-check, crystal-negatives-check, openapi-check, pypi-verify, railway-status (**11**) |
| `mutation` | Side effects (file/git/deploy/network), 1-line confirm before | sk-deploy, ttimes-deploy, netlify-prep, fifo-commit, git-sync-recover, railway-env-push, railway-safe-deploy, ss, tsc-quick, rehearsal (**10**) |
| `meta` | Skill/agent/command self-management; session-lifecycle warning | skill-add-branch, skill-trace-path, agent-smoke-test (**3**) |

### Implementation

**(1)** Each `~/.claude/commands/*.md` gets one frontmatter line:
```yaml
---
name: sparse-check
description: ...
command-type: diagnostic   ← new
---
```

24 manual edits (per Q3 decision: option a). Estimated 30 min.

**(2)** New paragraph in CLAUDE.md Section 2 ("Skill·Agent 활용 원칙"):

```markdown
### 명령어 실행 규칙 (command-type 기반)

- `diagnostic`: 호출 즉시 실행, 결과만 보고. 확인 X.
  → 4공리 #1 ("최소 마찰") 자동 적용
- `mutation`: 실행 전 1줄 확인 ("X에 Y합니다, 진행할까요?"). deploy/railway/git 계열은 영향 범위 명시.
  → 4공리 #2 ("Explicit Action") 자동 적용
- `meta`: 스킬/에이전트 정의 변경은 같은 세션 효력 없음 — 사용자에게 명시.
  (이전 CLAUDE.md "스킬 레지스트리 로드 시점" 함정 참조)
```

### Files inventory (§3)

- **Modify**: 24 files in `~/.claude/commands/*.md` (1 line each)
- **Modify**: `~/.claude/CLAUDE.md` (1 paragraph in §2)

### Risks

- Misclassification (e.g., a `mutation` mistakenly labeled `diagnostic`) flips behavior. First-week monitoring required.
- New commands must remember to add the field. Mitigated by template + `/agent-format-check`-style validator (future).

---

## §4 — C4: Audit trail (folded into §2)

### Decision

Per Q4 (option b): **fold into §2 skill, no standalone implementation.**

The `crystal-note-frontmatter` skill (§2) describes optional `createdByCommand`, `createdInSession`, `sourceRefs`, `sessionPurpose` fields. Auto-stubbed by the skill when Claude generates a note inside a command flow.

Primary applicable command: `/draft-linkedin`. Other commands rarely produce notes.

### Why not standalone

- presentation-harness already uses `.harness/last-run.json` ledger — stronger than YAML for build provenance.
- Crystal's command landscape has few note-producers — separate audit-trail infrastructure has poor ROI.
- Folding keeps the "4 patterns adopted" claim intact without new files.

### Files inventory (§4)

- **None** — fully folded into §2.

---

## Out of scope (deliberately NOT adopted)

| CMDS pattern | Why skip |
|--------------|----------|
| **CMDS.md philosophy doc** | Personal — would replace Crystal's own persona section. Defeats the purpose of customization. |
| **CMDS-Head-Quarter.md** (91-link nav hub) | Crystal has no comparable single-vault taxonomy. Multi-vault architecture differs. |
| **CMDS-Guide.md** (operational standards doc) | John's note types and naming. Crystal has different conventions. |
| **9-category taxonomy** (100 Themes ~ 900 Divisions) | Imposing a fixed taxonomy on existing 4 vaults = high churn, low value. |
| **AGENTS.md split** (other AI agents tech doc) | Crystal is Claude-Code-centric. No Gemini CLI / Codex / Cursor active. |
| **C1 Lifecycle vocabulary** (Connect/Merge/Develop/Share) | Crystal's workflows already named (`/wrap`, presentation-harness 9 stages). Conflict not benefit. |
| **C5 No separate `/queries` folder** rule | Conceptually nice but Crystal lacks `/query` command. N/A. |
| **C6 Wiki-worthiness gate** | Same — no `/query` command to gate. |
| **C7 Decision tree in spec** | Crystal CLAUDE.md will absorb command rules in §3. Tree-form not needed. |
| **D2 AI-meta frontmatter** (precedence/memory-type/token-estimate) | Over-engineering for 3-skill setup. Revisit if skill count grows past ~10. |
| **D5 Quick decision tree at top of system docs** | Slim CLAUDE.md (~80 lines) doesn't need internal navigation. |
| **D6 Symlink `.claude/` ↔ Vault** | Crystal has 4 vaults — no clear "source of truth" vault. Plus Obsidian Sync not currently in use. Defer. |
| **D7 Frontmatter changelog** | Git history is sufficient. YAML changelog adds noise. |

---

## Implementation order (preview, full plan in writing-plans)

1. §3 — Add `command-type` to 24 commands + CLAUDE.md paragraph (low risk, fast win)
2. §1 — Extract 3 skills + slim CLAUDE.md to ~80 lines (medium risk; persona must stay intact)
3. §2 + §4 — Create `crystal-note-frontmatter` skill + `/desc-check` command (depends on no prior steps)

Ordering rationale: §3 first because lowest risk and validates the manual-edit pattern. §1 second because it touches the always-loaded CLAUDE.md (high blast radius, sequence after §3 to learn from it). §2 last because it's net-new (no existing migration burden).

---

## Open questions

None at design time. All scoping decisions resolved Q1–Q4.

(`/desc-check` heuristic for "low-information description" may need tuning after first run — out-of-scope for this design.)

---

## Success criteria (post-implementation)

- New session start: CLAUDE.md token load reduced ≥50%.
- A "Diff-aware Sync 패턴 어땠더라" type query: skill auto-loads on first message containing "Diff-aware".
- Creating a new Permanent Note: `crystal-note-frontmatter` skill stubs description in English.
- `/desc-check` reports cleanly on a fresh-state vault folder.
- `/sk-deploy` on a known project: Claude asks 1-line confirm, runs, reports. No "왜 자꾸 묻지" fric.
- A new pattern learning (next month): clear destination skill (or new skill creation rule).

---

## Approval

- §1 design — approved 2026-04-30
- §2 design — approved 2026-04-30
- §3 design — approved 2026-04-30
- §4 design — approved 2026-04-30 (folded into §2)
- This consolidated spec — pending user review

## Phase 2 smoke test results (filled after fresh session)

- [ ] crystal-multi-agent-orchestration auto-loaded: yes/no
- [ ] crystal-infra-recovery auto-loaded: yes/no
- [ ] crystal-plugin-dev auto-loaded: yes/no
- [ ] CLAUDE.md persona keywords still in default context: yes/no
- [ ] CLAUDE.md token load reduced from baseline: yes/no (estimate)

## Phase 3 smoke test results (filled after fresh session)

- [ ] crystal-note-frontmatter auto-loaded on "새 Permanent Note 만들어줘": yes/no
- [ ] crystal-note-frontmatter prompts for English description: yes/no
- [ ] /desc-check runs and produces MISSING/KOREAN/LOWINFO output: yes/no
- [ ] /desc-check correctly exempts daily/clipping/scratch types: yes/no
