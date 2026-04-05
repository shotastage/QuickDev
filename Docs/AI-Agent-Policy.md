# QuickDev AI and Agent Utilization Policy

## 1. Purpose

This document defines how AI assistants and software agents should be used in the QuickDev project. The goal is to improve development speed and quality while preserving safety, correctness, and maintainability.

## 2. Scope

This policy applies to:

- Source code changes
- Documentation updates
- Test generation and maintenance
- Build, release, and automation scripts
- Review support and investigation tasks

This policy applies to all contributors using AI tools locally, in CI support workflows, or during pull-request preparation.

## 3. Core Principles

### 3.1 Human Accountability

- Humans remain fully responsible for all final outputs.
- AI-generated results must be reviewed before merge.
- Do not merge code solely because "the agent says it is correct."

### 3.2 Safe by Default

- Prefer read-only analysis first.
- Avoid destructive operations unless explicitly requested and reviewed.
- Follow project safety expectations for shell execution and external commands.

### 3.3 Minimal and Focused Changes

- Keep edits scoped to the task.
- Avoid unrelated refactors in AI-generated patches.
- Preserve existing public APIs unless the task explicitly requires breaking changes.

### 3.4 Verifiable Output

- Ensure behavior is testable and deterministic when practical.
- Run relevant validation commands after changes.
- Treat missing verification as incomplete work.

## 4. Allowed and Recommended Usage

Use AI/agents for:

- Code exploration and architecture understanding
- Drafting implementation options
- Focused refactoring and bug fixing
- Test case generation and edge-case discovery
- CLI help text and documentation maintenance
- Review assistance (risk identification, regression spotting)

## 5. Restricted Usage

Do not use AI/agents to:

- Auto-merge unreviewed patches
- Bypass code review or required checks
- Perform secrets handling beyond approved workflows
- Introduce dependencies without explicit team agreement
- Execute high-impact destructive commands without explicit human approval

## 6. Data, Privacy, and Secrets

- Never paste secrets, private keys, tokens, or credentials into prompts.
- Avoid sharing private customer or sensitive internal data unless explicitly approved.
- Prefer sanitized examples when discussing logs or configuration.
- If sensitive data exposure is suspected, stop and report immediately.

## 7. Code Generation and Review Standards

When AI contributes code:

- Follow existing repository conventions and style.
- Keep command execution safe and explicit.
- Add or update tests when behavior changes.
- Ensure failure paths return actionable errors.
- Avoid placeholder comments or speculative TODO-only implementations.

Review checklist for AI-generated changes:

- Correctness: Does it solve the intended problem?
- Safety: Any destructive or unsafe behavior introduced?
- Compatibility: Any platform guard or CLI behavior regressions?
- Maintainability: Is the change readable and appropriately scoped?
- Verification: Were relevant tests and commands executed?

## 8. Validation Expectations

For changes affecting CLI behavior or command wiring, run at minimum:

- `swift test`
- `swift run CLI --help`

When a specific command is modified, also run its expected success path and at least one meaningful failure path when applicable.

## 9. Documentation and Traceability

- Clearly label AI-assisted pull requests in the PR description.
- Summarize what was AI-generated versus manually authored.
- Record key verification steps and results.
- Mention notable limitations or residual risks.

## 10. Incident Handling

If AI/agent output causes or could cause a security, privacy, or production-impact issue:

1. Stop further automation.
2. Contain and revert unsafe changes.
3. Notify maintainers with impact and timeline details.
4. Add preventive guidance to this policy or related project docs.

## 11. Policy Maintenance

- This document is a living policy and should evolve with project practices.
- Maintainers should review it periodically and after major workflow changes.
- If this policy conflicts with stricter repository instructions, the stricter rule takes precedence.
