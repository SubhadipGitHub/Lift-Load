---
name: session-checkpoint
description: Write a checkpoint of the current Lift Load session into project memory. Use before switching domains, when a session runs long, at the end of a work session, or when the owner says "checkpoint".
---

# Session checkpoint

The owner wants context, decisions and open threads captured as work happens, not reconstructed later.

1. Read `.claude/memory/progress.md`, `.claude/memory/decisions.md` and `.claude/memory/open-questions.md`.
2. Add a new entry at the top of `progress.md`:

   ```markdown
   ## YYYY-MM-DD · <short session title>

   **Done**
   - <what changed, with file paths>

   **Decided**
   - <decision> (also logged in decisions.md)

   **Open**
   - <question or blocker, and who must answer>

   **Next**
   1. <the next concrete step>
   ```

3. Append any new decision to `decisions.md` (decision + one-line why, newest first).
4. Add new owner questions to `open-questions.md`; move answered ones to `decisions.md`.
5. Keep `progress.md` to the last five entries; fold older ones into one line each under "Earlier".
6. If `CLAUDE.md` is now wrong (a locked rule, a command, a path), fix it in the same commit.

Write facts only: what was done, decided and asked. No praise, no filler. Commit the memory files with the work
they describe.
