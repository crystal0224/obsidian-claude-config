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
