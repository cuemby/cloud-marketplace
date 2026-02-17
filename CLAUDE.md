# CLAUDE.md

AI-assisted development instructions. Opinionated guardrails for writing quality software.

> **AGENTS.md Compatible**: This file follows the [AGENTS.md](https://agents.md) standard.
> A copy exists as `AGENTS.md` for cross-tool compatibility (Cursor, Codex, Copilot, etc.)

---

## Operations

> **Purpose**: Immediate, executable instructions for AI agents. Commands first, context second.

### Setup Commands

```bash
# Clone
git clone https://github.com/cuemby/cloud-marketplace.git && cd cloud-marketplace

# Prerequisites (macOS)
brew install shellcheck bats-core helm yq jq

# Prerequisites (Ubuntu)
sudo apt-get install -y shellcheck bats
# Helm: https://helm.sh/docs/intro/install/
# yq: https://github.com/mikefarah/yq
```

### Testing Commands

```bash
make test              # Run unit tests (bats)
make test-unit         # Same as above
make test-integration  # Integration tests (Docker required)
bats tests/unit/       # Direct bats invocation
```

### Build & Deploy Commands

```bash
make lint              # ShellCheck all scripts
make lint-charts       # Helm lint all charts
make validate          # Validate all app.yaml files
make catalog           # Generate catalog/catalog.json
make new-app NAME=foo  # Scaffold a new application
```

### Environment Variables

```bash
# These are set on the target VM via cloud-init, not locally:
APP_NAME=wordpress           # Application to deploy
APP_VERSION=24.1.7           # App version (optional)
PARAM_WORDPRESS_USERNAME=... # App-specific parameters
```

---

## Boundaries (Do Not Touch)

> **Critical**: AI agents must NOT modify these without explicit permission.

### Protected Files
- `package-lock.json`, `yarn.lock`, `Cargo.lock`, `go.sum` (dependency locks)
- `.env`, `.env.local`, `.env.production` (environment configs)
- Database migration files (once applied to production)
- `tsconfig.json`, `Cargo.toml`, `go.mod` (without testing build)
- `.github/workflows/`, CI/CD configurations

### Never Commit
- Secrets, API keys, credentials, tokens
- `.env` files (commit `.env.example` instead)
- `node_modules/`, `venv/`, `target/`, build artifacts
- Personal IDE configs (`.vscode/settings.json`, `.idea/`)
- Large binaries, datasets (use Git LFS)

### Ask Before Modifying
- Authentication/authorization logic
- Database schemas (after production deployment)
- Public API contracts (breaks consumers)
- Build/deploy processes
- Major dependency versions

---

## Quick Reference

**Task Classification:**
- **ATOMIC** (<5 files, clear scope) → Implement directly
- **FEATURE** (5-10 files) → Break into subtasks
- **COMPLEX** (>10 files, new subsystem) → Use PRD workflow | .claude/skills/create-prd/SKILL.md

**Common Guardrails** (validate first):
- Function ≤50 lines | File ≤300 lines | Input validation | Parameterized queries
- Tests >80% (critical) | Conventional commits | No secrets in code

**Autonomous Mode (Ralph Wiggum methodology):**
- Initialize: `samuel auto init --prd .claude/tasks/NNNN-prd-feature.md`
- Start loop: `samuel auto start`
- Check status: `samuel auto status`
- Manage tasks: `samuel auto task list|complete|skip|reset|add`
- Methodology: .claude/skills/auto/SKILL.md

**Emergency Quick Links:**
- Security issue? → .claude/skills/security-audit/SKILL.md
- Tests failing? → .claude/skills/troubleshooting/SKILL.md
- Stuck >30 min? → .claude/skills/troubleshooting/SKILL.md
- Complex feature? → .claude/skills/create-prd/SKILL.md
- Code review? → .claude/skills/code-review/SKILL.md
- Language-specific? → .claude/skills/{lang}-guide/SKILL.md

**Skills** (capability modules - [Agent Skills](https://agentskills.io) standard):
- Create: `samuel skill create <name>` or `.claude/skills/create-skill/SKILL.md`
- Validate: `samuel skill validate`
- List: `samuel skill list`
- Load: `.claude/skills/<skill-name>/SKILL.md` when task matches description

<!-- SKILLS_START -->
## Available Skills

Skills extend AI capabilities. Load a skill when task matches its description.

| Skill | Description |
|-------|-------------|
| auto | Autonomous AI coding loop (Ralph Wiggum methodology). Use when running AI age... |
| cleanup-project | Project cleanup and pruning workflow. Use when removing unused guides, cleani... |
| code-review | Pre-commit code quality review workflow. Use before committing changes to ver... |
| create-prd | Product Requirements Document (PRD) creation workflow. Use when defining impl... |
| create-rfd | Request for Discussion (RFD) creation workflow. Use when exploring technical ... |
| create-skill | Agent Skill creation workflow. Use when creating new reusable AI agent skills... |
| dependency-update | Safe dependency update workflow. Use when upgrading packages, resolving vulne... |
| document-work | Work documentation and pattern capture workflow. Use after completing signifi... |
| generate-agents-md | Cross-tool compatibility workflow. Use when generating AGENTS.md files for co... |
| generate-tasks | Task generation and breakdown workflow. Use when decomposing a PRD or complex... |
| initialize-project | Project initialization and setup workflow. Use when starting a new project, s... |
| refactoring | Technical debt remediation and code restructuring workflow. Use when improvin... |
| security-audit | Security assessment workflow. Use when reviewing code for vulnerabilities, pe... |
| testing-strategy | Test planning and coverage strategy workflow. Use when designing test suites,... |
| troubleshooting | Debugging and problem-solving workflow. Use when stuck on an issue for more t... |
| update-framework | Samuel version update workflow. Use when upgrading to a new Samuel version, m... |

**To use a skill**: Read `.claude/skills/<skill-name>/SKILL.md`
<!-- SKILLS_END -->

**Load Language Guide** (automatic based on file extensions):
- TypeScript/JavaScript → .claude/skills/typescript-guide/SKILL.md
- Python → .claude/skills/python-guide/SKILL.md
- Go → .claude/skills/go-guide/SKILL.md
- Rust → .claude/skills/rust-guide/SKILL.md
- Kotlin → .claude/skills/kotlin-guide/SKILL.md
- Java → .claude/skills/java-guide/SKILL.md
- C# → .claude/skills/csharp-guide/SKILL.md
- PHP → .claude/skills/php-guide/SKILL.md
- Swift → .claude/skills/swift-guide/SKILL.md
- C/C++ → .claude/skills/cpp-guide/SKILL.md
- Ruby → .claude/skills/ruby-guide/SKILL.md
- SQL → .claude/skills/sql-guide/SKILL.md
- Shell/Bash → .claude/skills/shell-guide/SKILL.md
- R → .claude/skills/r-guide/SKILL.md
- Dart/Flutter → .claude/skills/dart-guide/SKILL.md
- HTML/CSS → .claude/skills/html-css-guide/SKILL.md
- Lua → .claude/skills/lua-guide/SKILL.md
- Assembly → .claude/skills/assembly-guide/SKILL.md
- CUDA → .claude/skills/cuda-guide/SKILL.md
- Solidity → .claude/skills/solidity-guide/SKILL.md
- Zig → .claude/skills/zig-guide/SKILL.md

**Load Framework Skill** (when using specific framework):
- TypeScript/JavaScript: react, nextjs, express
- Python: django, fastapi, flask
- Go: gin, echo, fiber
- Rust: axum, actix-web, rocket
- Kotlin: spring-boot-kotlin, ktor, android-compose
- Java: spring-boot-java, quarkus, micronaut
- C#: aspnet-core, blazor, unity
- PHP: laravel, symfony, wordpress
- Swift: swiftui, uikit, vapor
- Ruby: rails, sinatra, hanami
- Dart: flutter, shelf, dart-frog

All at `.claude/skills/<name>/SKILL.md`

---

## Core Guardrails (ALWAYS ENFORCE)

### Code Quality
- No function exceeds 50 lines (split with helper functions)
- No file exceeds 300 lines (components: 200, tests: 300, utils: 150)
- Cyclomatic complexity ≤ 10 per function
- All exported functions have type signatures and documentation
- No magic numbers (use named constants)
- No commented-out code in commits (use git history)
- No `TODO` without issue/ticket reference
- No dead code (unused imports, variables, functions)

### Security (CRITICAL)
- All user inputs validated before processing
- All API boundaries have input validation (prefer schema validators: Zod, Pydantic, etc.)
- All database queries use parameterized statements (no string concatenation)
- All environment variables have secure defaults (never hardcode secrets)
- All file operations validate paths (prevent directory traversal)
- All async operations have timeout/cancellation mechanisms
- Dependencies checked for known vulnerabilities before adding
- Dependencies checked for license compatibility before adding
- All database migrations include rollback (down) function

### Testing (CRITICAL)
- Coverage targets: >80% for business logic, >60% overall
- All public APIs have unit tests
- All bug fixes include regression tests
- All edge cases explicitly tested (null, empty, boundary values)
- Test names describe behavior: `test_user_login_fails_with_invalid_password`
- No test interdependencies (tests run in any order)
- Integration tests for external service interactions
- All deployments include smoke test validation

### Git & Commits
- Commit messages: `type(scope): description` (conventional commits)
- Types: feat, fix, docs, refactor, test, chore, perf, ci
- One logical change per commit (atomic commits)
- All commits must pass tests before pushing
- Branch naming: `type/short-description` (e.g., `feat/user-auth`)
- No commits directly to main/master (use PRs)
- Breaking API changes require major version bump (Semantic Versioning)

### Performance
- No N+1 queries (batch database operations)
- Large datasets use pagination/streaming (not full loads)
- Expensive computations memoized/cached when appropriate
- Frontend bundles < 200KB initial load (code-split when needed)
- API responses < 200ms for simple queries, < 1s for complex

---

## 4D Methodology

Apply appropriate mode based on task complexity:

### ATOMIC Mode (Default)
For single-file changes, bug fixes, small features:

1. **Deconstruct**: What's the minimal change needed?
2. **Diagnose**: Will this break anything? Check dependencies.
3. **Develop**: Make the change with tests.
4. **Deliver**: Validate (run tests, check guardrails) → Commit.

### FEATURE Mode
For multi-file features, new components, API endpoints:

1. **Deconstruct**: Break into 3-5 subtasks (each atomic).
2. **Diagnose**: Identify integration points and dependencies.
3. **Develop**: Implement subtasks sequentially with tests.
4. **Deliver**: Integration test → Documentation → Review → Commit.

### COMPLEX Mode
For architecture changes, major refactors, new systems:

1. **Deconstruct**: Full decomposition into phases/milestones.
2. **Diagnose**: Analyze risks, dependencies, migration paths.
3. **Develop**: Plan implementation → Execute incrementally.
4. **Deliver**: Staged rollout → Documentation → Retrospective.

**Workflow for COMPLEX tasks:**
1. Use `.claude/skills/create-prd/SKILL.md` to define requirements
2. Use `.claude/skills/generate-tasks/SKILL.md` to break down implementation
3. Implement tasks step-by-step with verification checkpoints

**Autonomous Execution (Optional):**
After task generation, convert to autonomous format for unattended execution:

1. `samuel auto init --prd .claude/tasks/NNNN-prd-feature.md`
2. Review generated `prd.json` and `prompt.md`
3. `samuel auto start`

See `.claude/skills/auto/SKILL.md` for the full methodology.

**Escalation Triggers:**
- Task affects >5 files → FEATURE mode
- Task affects >10 files → COMPLEX mode (consider PRD workflow)
- Task affects >15 files OR new subsystem → COMPLEX mode (PRD workflow MANDATORY)
- Task unclear/ambiguous → Ask user for clarification first

---

## Software Development Lifecycle

### Stage 1: Planning
**Atomic**: Read existing code → Identify change location
**Feature**: Review related code → Sketch interfaces/contracts
**Complex**: Use PRD workflow

### Stage 2: Implementation
- Write tests first (TDD) or alongside code
- Load language-specific guide: .claude/skills/{language}-guide/SKILL.md
- Follow language/framework idioms
- Validate against guardrails continuously

### Stage 3: Validation
- Run full test suite
- Check coverage thresholds
- Run linter/formatter
- Verify build succeeds

### Stage 4: Documentation
- Function/class docstrings (what, why, params, returns)
- Inline comments for complex logic (why, not what)
- API documentation updated

### Stage 5: Commit
```bash
git add <files>
git commit -m "type(scope): description

- Detail 1
- Detail 2

Refs: #issue-number"
```

---

## Per-Folder CLAUDE.md

This project uses **hierarchical CLAUDE.md files**. Each folder can have its own `CLAUDE.md` with folder-specific instructions that AI agents load on demand.

**When creating new directories**, create a `CLAUDE.md` with:
- Purpose of the folder
- Conventions specific to that folder
- Key patterns or constraints

AI agents automatically discover and load these files when working in subdirectories.

---

## Project Context

> **Instructions**: Fill in this section when the tech stack and architecture are decided.
> This replaces the need for a separate project.md file.

### Tech Stack
- **Language**: Bash 5.x, YAML
- **Runtime**: K3s (lightweight Kubernetes), Helm 3
- **Infrastructure**: Provider-agnostic VMs (AWS, GCP, Azure, etc.) via cloud-init
- **Testing**: bats-core (Bash), ShellCheck (linting)
- **YAML Processing**: yq

### Architecture
- **Type**: Single-node K3s cluster per VM, one app per VM
- **Key Patterns**: Cloud-init bootstrap, wrapper Helm charts (upstream dependencies), state machine (JSON state file), PARAM_* env var mapping to Helm --set flags
- **Entry Point**: `bootstrap/entrypoint.sh` — orchestrates validation, K3s, Helm, app deployment, health check
- **App Catalog**: `apps/*/app.yaml` — metadata, parameters, helmMappings per application

### Key Design Decisions
- **Decision**: Disable Traefik in K3s | **Date**: 2026-02-17 | **Rationale**: Saves resources; single-app VMs use NodePort directly
- **Decision**: Use `local-path` StorageClass | **Date**: 2026-02-17 | **Rationale**: K3s default, appropriate for single-node
- **Decision**: `--atomic` on Helm install | **Date**: 2026-02-17 | **Rationale**: Auto-rollback on failure, clean state
- **Decision**: `PARAM_*` prefix for env vars | **Date**: 2026-02-17 | **Rationale**: Prevents collision with system env vars
- **Decision**: State file (not callback API) | **Date**: 2026-02-17 | **Rationale**: Simpler, no outbound endpoint dependency
- **Decision**: Wrapper charts (not forks) | **Date**: 2026-02-17 | **Rationale**: Get upstream security patches by bumping version

---

## Anti-Patterns (Avoid These)

### Code
- Premature optimization (measure first, optimize after)
- Over-engineering (YAGNI: You Aren't Gonna Need It)
- Copy-paste code (extract to shared function/component)
- Ignoring errors (every error needs handling)

### Testing
- Testing implementation details (test behavior, not internals)
- Flaky tests (non-deterministic results indicate bad design)
- Test interdependencies (each test should be isolated)

### Process
- Committing directly to main (use feature branches + PRs)
- Batch commits (commit after each logical change)
- Skipping tests because "it's a small change"

---

## When Stuck

**See:** `.claude/skills/troubleshooting/SKILL.md`

**Quick recovery:**
1. STOP trying random solutions (>30 min = stuck)
2. Document what you've tried
3. Simplify & isolate (minimal reproduction)
4. Check fundamentals (dependencies, config, versions)
5. Ask user with clear problem statement

---

## Version & Changelog

**Current Version**: 2.0.0
**Last Updated**: 2026-02-11

### Changelog

**v2.0.0 (2026-02-11) - Native Claude Code Integration**
- Migrated from `.agent/` to `.claude/` (native Claude Code directory)
- Merged AI_INSTRUCTIONS.md + CLAUDE.md + project.md into single CLAUDE.md
- Skills now live in `.claude/skills/` (native skill discovery)
- Added AGENTS.md as real copy for cross-tool compatibility
- Added per-folder CLAUDE.md support (hierarchical instructions)
- Dropped `.agent/memory/`, `.agent/tasks/`, `.agent/rfd/`, `.agent/state.md`
- Uses Claude Code's built-in memory system instead

**v1.8.0 (2025-02-04) - Agent Skills Integration**
- Added Agent Skills support (open standard for AI agent capabilities)
- New CLI commands: `samuel skill create`, `samuel skill validate`, `samuel skill list`, `samuel skill info`
- Skills compatible with 25+ agent products

---

**Remember**: This file is your guardrails. Small atomic changes. Validate continuously.

**Cross-Tool Compatibility**: AGENTS.md is a copy of this file for tools that read AGENTS.md.
