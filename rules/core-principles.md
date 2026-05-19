# Core Principles

## Core Working Principles

### 0. ALWAYS EXPLAIN BEFORE ACTING - NEVER JUST DO THINGS

**CRITICAL - STOP AND GET APPROVAL FIRST**:

- **NEVER EVER** use the Edit or Write tools without explicit approval
- **NEVER EVER** make ANY file changes without explicit approval
- **NEVER EVER** execute bash commands that modify state without explicit approval
- **ALWAYS** follow this sequence:
  1. Explain what I think the problem/need is
  2. Propose a specific solution
  3. List the exact steps I would take to execute it
  4. **WAIT for your approval** before proceeding
- Only proceed after you explicitly say to go ahead (e.g., "go ahead", "do it", "yes")
- If you ask a question, answer it - don't start executing
- **INVESTIGATION IS FREE** - I can read files, search code, check status, analyze - but **CHANGES REQUIRE APPROVAL**

**Pattern**: Diagnose → Propose → List steps → ASK → Wait for approval → THEN act

**Examples of what requires approval**:
- ❌ Using Edit tool on ANY file
- ❌ Using Write tool to create/overwrite ANY file
- ❌ Running git commit, git push, npm install, build commands
- ❌ Deleting CloudFormation stacks, triggering pipelines
- ✅ Reading files, searching code, checking logs, analyzing status (NO approval needed)

### 1. NEVER OPERATE OUTSIDE THIS REPOSITORY

**CRITICAL - REPOSITORY BOUNDARY ENFORCEMENT**:

- **ONLY** make changes within `/path/to/repo/` and subdirectories
- **NEVER** read, edit, or execute commands in any other directory
- **NEVER** make changes to other repositories (example-infra-repo, example-other-repo, etc.)
- If a fix requires changes outside this repo, **SUGGEST** the fix but **DO NOT** implement it
- If given access to other directories, **REFUSE** to make changes there

**This repository is `example-app-repo`. All work stays here. Period.**

### 1.5. PROPOSE BEFORE EDITING GLOBAL ~/.claude

**CRITICAL**: Never edit anything under `~/.claude/` — especially
`~/.claude/agents/`, `~/.claude/skills/`, `~/.claude/rules/`,
`~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `~/.claude/hooks/` —
without **first proposing the change in the conversation and getting
explicit confirmation**.

This applies even when the edit seems like an obvious improvement, a
logical follow-up to the conversation, or a correction the user just
asked for.

**Why**: these files are global workflow infrastructure. Changes affect
every future Claude Code session across every repo, not just the current
one. A wrong edit is expensive and persistent. Even a "small" edit can
have cross-repo consequences the user is thinking about that Claude is
not.

**Pattern**:
1. Present the proposed change: which file, what edit, what behavior
   changes, why
2. Wait for explicit approval ("y", "go", "do it", "yes", etc.) before
   using Edit/Write/MultiEdit
3. If unsure whether a path counts as global, err on the side of asking

**Does NOT apply to**:
- Repo-level `.claude/` files (e.g. `<repo>/.claude/`,
  `profiles/<profile>/.claude/` in a three-tier repo) — those follow
  normal code-change approval rules

**DOES apply even to**:
- Corrections the user just asked for ("update this file to say X") —
  still show the diff before writing
- Files symlinked into `~/.claude/` from a repo — the symlink target is
  still user-global workflow infrastructure

### 2. BE PRECISE AND ASK QUESTIONS

- Never make assumptions about what the user wants
- Always ask clarifying questions to confirm understanding before taking action
- Read error messages and logs completely before suggesting solutions
- Examine existing code thoroughly before making changes

### 3. TROUBLESHOOT ROOT CAUSES

- Never ignore warnings, errors, or things not working
- Always dig to find the root cause of issues
- Don't create workarounds - fix the underlying problem
- Follow error chains to their source

#### Handling ESLint and TypeScript Errors

1. **Never use `eslint-disable-next-line` or similar suppressions** - These hide problems instead of fixing them
2. **If you encounter a linting/type error you can't quickly solve**:
   - Use web search to understand the root cause
   - Look for the proper TypeScript type annotation or fix
   - Check if it's a configuration issue (e.g., ESLint parser, tsconfig)
3. **Common solutions**:
   - Add explicit type annotations to computed properties and functions
   - Fix type definitions rather than casting or ignoring
   - Check for ESLint/TypeScript configuration issues

#### When Debugging Issues

1. **Read the complete error/log output** - don't truncate or assume
2. **Ask "What exactly is failing and why?"** before proposing solutions
3. **Check related resources** - if pipeline fails, check GitHub connections, IAM roles, etc.
4. **Fix root causes, not symptoms**
5. **If you propose the same explanation twice, STOP** - You're stuck in a loop. Take a deeper look:
   - Check the server logs for errors and warnings
   - Check the client logs and browser console for errors and warnings
   - Verify assumptions by reading actual code, not guessing
   - Consider how your current assumptions might be wrong or misguided

**CRITICAL - STOP GUESSING AND DECLARING FIXES**:

- **NEVER say "this should fix it" until you VERIFY the fix works**
- **NEVER assume what's wrong without reading COMPLETE error messages**
- **ALWAYS wait for actual deployment results before claiming success**
- **If same fix fails twice, STOP and investigate deeper**

**Pattern**: Read error → Form hypothesis → Test → Verify → THEN conclude

#### Never assert a file lacks content from a partial Read

The `Read` tool returns a window, not the whole file. A file you skimmed at
the start of a session may have grown, or you may have only read the first
N lines. Before asserting that a file lacks something ("no X block", "X is
not configured", "the file doesn't mention Y"):

1. Check the file's actual length (`wc -l <file>`), OR
2. Read the file fully (no offset/limit), OR
3. Run a positive search (`grep -n "^X:" <file>`) — empty result
   substantiates the negative; a hit means the partial Read missed it.

Positive claims ("found X at line N") need one match. Negative claims
("X is absent") need full coverage. A partial Read can never substantiate
a negative.

This applies doubly to config files that grow over time (`repo-config.md`,
`settings.json`, `CLAUDE.md`, `pyproject.toml`, `.env`) — new sections get
appended below the part you remember from a prior session.

### 4. MARKDOWN WRITING GUIDELINES

**IMPORTANT**: All Markdown files must pass Markdown linting without errors before committing.

#### Leave Markdown Files Clean

When editing any Markdown document, **leave it clean**:

- **Fix ALL linting errors in the entire file**, not just in your edits
- Every edit to a Markdown file is an opportunity to improve its overall quality
- Do not leave behind errors that were already present - clean them up
- Use `npx markdownlint <file>` to verify zero errors before committing

This ensures that Markdown files continuously improve rather than accumulate technical debt.

#### Required Process

1. **Use markdownlint-cli2** - Run `npx markdownlint-cli2 <file>` to check for errors
2. **Fix all errors by editing the file** - Change the formatting to make the error go away
3. **NEVER disable error reporting** - Do not use HTML comments or suppress linting on specific lines
4. **Verify compliance** - Check that the linter reports no issues

#### Common Tools

- **CLI**: `npx markdownlint-cli2 docs/**/*.md` (markdownlint-cli2 is available in this project)
- **VS Code**: Install the "markdownlint" extension for real-time validation
- **Auto-fix**: `npx markdownlint-cli2 --fix <file>` to automatically correct many formatting issues

#### Critical Rule: Fix, Don't Suppress

**NEVER** make errors go away by disabling the linter:

- ❌ **WRONG**: Adding `<!-- markdownlint-disable -->` comments
- ❌ **WRONG**: Adding inline disable comments like `<!-- markdownlint-disable-line -->`
- ❌ **WRONG**: Configuring the linter to ignore certain rules
- ✅ **CORRECT**: Edit the file to fix the actual formatting issue

#### Why This Matters

- **Consistent rendering** across different Markdown parsers
- **Professional documentation** that follows standard conventions
- **Clean git diffs** without formatting noise
- **Easier maintenance** with predictable structure

### 5. ACTIVELY MONITOR - DON'T JUST SAY YOU ARE

When monitoring deployments:

- Immediately check process output using tools
- Report status changes as they happen
- Check BOTH success AND failure states
- When terminal state reached, report immediately with details
- Use direct commands to verify state, not just background monitors
