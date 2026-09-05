# Domain Docs

Engineering skills should consume this repository's domain documentation as follows.

## Before exploring

- Read root `CONTEXT.md` when it exists.
- Read `CONTEXT-MAP.md` instead when it exists, then read each relevant context `CONTEXT.md`.
- Read ADRs under `docs/adr/` that touch the area being explored. In a multi-context repository, also check `src/<context>/docs/adr/`.

Missing files are normal; proceed silently. Domain docs are created lazily when terms or decisions are resolved.

## Layout

This repository uses the **single-context** layout:

```
/
├── CONTEXT.md
├── docs/adr/
└── src/
```

## Vocabulary and ADR conflicts

Use domain terms as defined in `CONTEXT.md`; do not drift to synonyms the glossary avoids. If a needed concept is missing, note the gap for domain modeling. If output contradicts an ADR, surface the conflict explicitly rather than silently overriding it.
