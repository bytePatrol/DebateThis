# CLAUDE.md

## gstack

Use the `/browse` skill from gstack for all web browsing.

### Available gstack skills

- `/gstack:autoplan` — Auto-review pipeline (CEO, design, eng, DX reviews)
- `/gstack:benchmark` — Performance regression detection using the browse daemon
- `/gstack:browse` — Fast headless browser for QA testing and site dogfooding
- `/gstack:canary` — Post-deploy canary monitoring
- `/gstack:careful` — Safety guardrails for destructive commands
- `/gstack:checkpoint` — Save and resume working state checkpoints
- `/gstack:codex` — OpenAI Codex CLI wrapper (code review, pair, autonomous modes)
- `/gstack:connect-chrome` — Launch GStack Browser (AI-controlled Chromium)
- `/gstack:cso` — Chief Security Officer mode (infrastructure security audit)
- `/gstack:design-consultation` — Design consultation and landscape research
- `/gstack:design-html` — Generate production-quality HTML/CSS designs
- `/gstack:design-review` — Visual QA (spacing, hierarchy, consistency)
- `/gstack:design-shotgun` — Generate multiple AI design variants for comparison
- `/gstack:devex-review` — Live developer experience audit
- `/gstack:document-release` — Post-ship documentation update
- `/gstack:freeze` — Restrict file edits to a specific directory
- `/gstack:gstack-upgrade` — Upgrade gstack to the latest version
- `/gstack:guard` — Full safety mode (destructive warnings + directory-scoped edits)
- `/gstack:health` — Code quality dashboard
- `/gstack:investigate` — Systematic debugging with root cause investigation
- `/gstack:land-and-deploy` — Land and deploy workflow (merge, CI, deploy, canary)
- `/gstack:learn` — Manage project learnings
- `/gstack:office-hours` — YC Office Hours (startup or technical mode)
- `/gstack:pair-agent` — Pair a remote AI agent with your browser
- `/gstack:plan-ceo-review` — CEO/founder-mode plan review
- `/gstack:plan-design-review` — Designer's eye plan review
- `/gstack:plan-devex-review` — Developer experience plan review
- `/gstack:plan-eng-review` — Eng manager-mode plan review
- `/gstack:qa` — QA test a web app and fix bugs found
- `/gstack:qa-only` — Report-only QA testing
- `/gstack:retro` — Weekly engineering retrospective
- `/gstack:review` — Pre-landing PR review
- `/gstack:setup-browser-cookies` — Import cookies from your real browser
- `/gstack:setup-deploy` — Configure deployment settings
- `/gstack:ship` — Ship workflow (merge, test, review, bump version, push)
- `/gstack:unfreeze` — Clear the freeze boundary set by /freeze

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
