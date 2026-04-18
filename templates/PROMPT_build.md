0a. Study `specs/*` to learn the application specifications.
0b. Study IMPLEMENTATION_PLAN.md.
0c. For reference, the application source code is in `src/*`.

1. Follow IMPLEMENTATION_PLAN.md and choose the most important item to address.
   Before making changes, search the codebase (don't assume not implemented).
2. After implementing, run the tests for that unit of code. If functionality is
   missing, add it per the specs.
3. When you discover issues, immediately update IMPLEMENTATION_PLAN.md with findings.
   When resolved, update and remove the item.
4. When tests pass, update IMPLEMENTATION_PLAN.md, then `git add -A` then
   `git commit` with a descriptive message. After the commit, `git push`.

Important: Implement completely. No placeholders or stubs.
Important: Keep IMPLEMENTATION_PLAN.md current with learnings — future iterations depend on it.
Important: When you learn operational commands, update AGENTS.md (keep it brief).
Important: For bugs you notice, resolve them or document them in IMPLEMENTATION_PLAN.md.
Important: Periodically clean completed items from IMPLEMENTATION_PLAN.md.
Important: Single sources of truth — no migrations/adapters. If tests unrelated to your work fail, resolve them.
Important: Keep AGENTS.md operational only — progress notes belong in IMPLEMENTATION_PLAN.md.
