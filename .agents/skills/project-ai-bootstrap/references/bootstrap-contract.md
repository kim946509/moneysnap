# Bootstrap Contract

## Required surfaces

| Surface | Canonical location | Responsibility |
|---|---|---|
| Agent rules | `AGENTS.md` | Project invariants, source documents, real verification commands |
| Shared language | `CONTEXT.md` | Concise domain terms used by humans and agents |
| Harness entrypoint | `.ai/README.md` | Read order, state model, immutable principles |
| Machine-readable policy | `.ai/harness.yaml` | Anchors, approvals, state names, evidence requirements |
| Work graph | `.ai/GRAPHS.md` | Planning-to-release nodes and dependencies |
| Improvement graph | `.ai/GRAPHS.md` | Metric, counter-metric, audit, governance, rollback edges |
| Loop catalog | `.ai/LOOPS.md` | Trigger, goal, inputs, actions, verification, stop, memory |
| Work state | `.ai/work/` | Small work items with blocking edges and evidence |
| Templates | `.ai/templates/` | Work item, handoff, held-out evaluation |
| Skill root | `.agents/skills/` | Project-local reusable procedures |
| Skill lock | `.ai/skills.lock.json` | Source and local integrity hashes |
| Human guide | `docs/AI_ENVIRONMENT.md` | Architecture, usage, migration, extension guidance |

## Required loops

Start with these generic loops:

1. planning and domain clarification;
2. specification and task graph creation;
3. test-first feature delivery;
4. bug diagnosis and regression coverage;
5. code review and impact analysis;
6. documentation synchronization;
7. release readiness and human approval;
8. harness improvement with held-out evaluation and rollback.

Each loop must declare:

- trigger;
- goal;
- inputs and frozen anchors;
- actions or mapped skills;
- deterministic verification;
- named terminal states;
- durable memory location;
- owner and cadence when it can affect other loops.

## Graph engineering requirements

- Pair every optimization metric with a counter-metric.
- Assign target ownership to a slower or human-governed loop.
- Separate fast implementation cadence from architecture, security, and release cadence.
- Keep user decisions, product scope, security policy, acceptance criteria, and held-out evaluations frozen.
- Give audit or governance nodes authority to veto and roll back changes.
- Maintain separate work and improvement graphs.

## Migration rules

1. List old harness files and verify their contents.
2. Preserve product documents and unrelated user changes.
3. Remove unsafe or redundant executors, hooks, and duplicated instructions only after their replacements are defined.
4. Keep runtime-generated graph databases and logs untracked.
5. Document every deliberate omission and the condition that will activate it later.

## Validation checklist

- [ ] All required surfaces exist or have an explicit reason for omission.
- [ ] `AGENTS.md` points to the AI environment entrypoint.
- [ ] No verification command is invented or stale.
- [ ] Every installed skill is used by at least one loop.
- [ ] Skill provenance and hashes are recorded.
- [ ] Work items cannot reach `done` without evidence.
- [ ] Fast loops cannot modify frozen anchors.
- [ ] External side effects and deployment require human approval.
- [ ] Harness changes use one-variable experiments and rollback.
- [ ] Platform-specific profiles remain separate from the generic core.
