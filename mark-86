---
name: git-review-pr
description: Review a GitHub pull request for quality, security, and best practices.
---

# Review GitHub Pull Request

Have the `pr-reviewer` agent review Pull Request $ARGUMENTS for cod se quality, security, and best practices.

## Process

1. **Fetch PR Details**
   - Use `gh pr view $ARGUMENTS --json title,body,commits,files,reviews`
   - Get the full diff with `gh pr diff $ARGUMENTS`

2. **Analysis Focus Areas**
   - **Security**: Authentication, authorization, input validation, SQL injection, XSS, secrets in code
   - **Architecture**: Design patterns, separation of concerns, coupling, blast radius
   - **Performance**: N+1 queries, inefficient algorithms, resource leaks, unnecessary API calls
   - **Error Handling**: Proper try/catch, error propagation, logging with context
   - **Testing**: Test coverage for new code, edge cases, integration tests
   - **Code Quality**: Naming, duplication, complexity, dead code, comments

3. **Serverless-Specific Checks** (if applicable)
   - Lambda handler patterns (async/await, proper context usage)
   - Cold start optimization
   - EventBridge event schema validation
   - DynamoDB query patterns (avoid scans, proper GSI usage)
   - IAM least privilege
   - Cost implications (Lambda duration, DynamoDB capacity)

4. **Output Format**
   Provide findings as:
   - **Critical**: Security vulnerabilities, data loss risks, production blockers
   - **High**: Performance issues, architectural problems, missing error handling
   - **Medium**: Code quality issues, maintainability concerns
   - **Low**: Style suggestions, minor improvements

5. **Generate Summary**
   - Overall assessment (Approve/Request Changes/Comment)
   - Key concerns ranked by severity
   - Specific line-by-line feedback where relevant
   - Actionable recommendations

## Optional: Post Review
Ask if the user wants you to post the review: if requested, use `gh pr review $ARGUMENTS` to post
