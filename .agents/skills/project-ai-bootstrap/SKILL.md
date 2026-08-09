---
name: project-ai-bootstrap
description: Initialize, migrate, audit, or document a portable project-local AI development environment. Use when starting AI-assisted development in a repository, replacing an ad-hoc harness, installing project-local skills, defining planning/development/test/review/release loops, designing work and improvement graphs, or preparing the setup for reuse in another software project.
---

# Project AI Bootstrap

Build the smallest reliable project-local AI environment. Keep product truth, agent instructions, skills, work state, verification, and improvement governance separate.

## Workflow

1. Inventory the repository before changing files.
   - Read `AGENTS.md`, product documents, architecture records, test/build commands, local skills, hooks, CI, and git status.
   - Treat existing uncommitted changes as user-owned.
   - Identify the old harness precisely; do not classify product documents as harness files.

2. Select one mode.
   - `initialize`: no structured AI environment exists.
   - `migrate`: replace an existing harness while preserving product truth and user changes.
   - `audit`: report gaps without modifying files.
   - `extend`: add a platform profile after the generic core is stable.

3. Read `references/bootstrap-contract.md` and create or repair the required surfaces.
   - Keep reusable skills under `.agents/skills/`.
   - Keep agent-independent control files under `.ai/`.
   - Keep human-facing environment documentation under `docs/`.
   - Keep product-specific facts in the project's existing source-of-truth documents.

4. Install skills locally and record provenance.
   - Use an installer with `--dest <repo>/.agents/skills` when available.
   - Install only skills mapped to an active loop.
   - Write source repository, ref/path, and local SHA-256 values to `.ai/skills.lock.json`.
   - Do not install globally unless the user explicitly requests it.

5. Adapt verification to the project.
   - Discover real build, test, lint, format, and deployment commands.
   - Put authoritative commands in `AGENTS.md`; do not invent commands.
   - Require deterministic evidence before a work item reaches `done`.
   - Keep destructive operations, external side effects, credentials, and production deployment behind human approval.

6. Validate the environment.
   - Check required files and internal links.
   - Validate every installed skill folder and metadata.
   - Confirm product anchors cannot be rewritten by fast implementation loops.
   - Confirm the harness improvement loop changes one element at a time and can roll back.
   - Report anything deferred because the application code or platform profile does not exist yet.

## Boundaries

- Do not create a custom agent runtime when the host agent already provides tools, approvals, sandboxing, sessions, and subagents.
- Do not add hooks until the equivalent manual verification loop is proven useful and deterministic.
- Do not let an executor mark its own work complete without external evidence.
- Do not combine generic setup and platform-specific setup in the same migration. Stabilize the generic core first.
- Do not overwrite product documents with generic templates.

## Output

Summarize:

- files added, removed, and preserved;
- installed local skills and their loop mapping;
- work and improvement graphs;
- fixed anchors and human approval boundaries;
- verification performed;
- deferred platform-specific extensions.
