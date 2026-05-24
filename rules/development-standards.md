# Development Standards

## Development Workflow

**CRITICAL INSTRUCTION**: Claude Code MUST follow this workflow when working in any repository:

1. **Analyze & Explain**: First, explain what problem you've identified
2. **Propose Solution**: Describe the solution you recommend
3. **Outline Steps**: List the specific steps/changes needed to implement it
4. **Wait for Approval**: ALWAYS ask for explicit approval before making ANY changes

## Never Do These Things

**NEVER**:

- Make changes without explaining them first
- Assume you know what the user wants
- Create new files or edit existing files without approval
- Execute commands that modify the system without permission

This ensures full transparency and control over all changes to repositories.

## Common Patterns to Avoid

- Don't work around problems - fix them
- Don't assume success without verification
- Don't add monitoring tasks to todos - do them immediately
- Don't say you're monitoring and then stop - monitor until complete
- Don't quote the same explanation twice - investigate deeper

## Shared Constants

**ALWAYS use shared constants instead of hardcoding strings**:

1. Define constants in a central place (e.g., `shared-constants.ts`)
2. Use consistent naming conventions (e.g., project prefix like `myproject-`)
3. Reference constants everywhere instead of string literals
4. When creating new resources, add their names to shared constants first

This prevents mismatched resource names between modules/stacks and makes refactoring trivial.
