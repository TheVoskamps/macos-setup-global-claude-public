# Code Review Standards

## Architecture Patterns

- Lambda-per-endpoint for blast radius control
- EventBridge for service-to-service communication
- No synchronous Lambda chaining
- DynamoDB single-table design with GSIs

## Required Checks

- All Lambda handlers must have structured logging with X-Ray trace IDs
- All DynamoDB writes must include TTL attributes where applicable
- All API Gateway endpoints must validate request schemas
- Error responses must not leak internal details

## Repo-Specific: No CodeQL / Code-Quality Scanning (this repo)

This repo (`global-claude-config`) intentionally does NOT have
CodeQL or code-quality scanning enabled. The content is markdown
rules, agent definitions, and skills — there is no compiled or
interpreted source code for CodeQL to meaningfully analyze, and the
repo is private and not GHAS-entitled.

The `protect-main` ruleset (id `16051262`) previously included
`code_scanning` and `code_quality` rule types that required CodeQL /
code-quality analyses to be uploaded before a PR could merge. No
such analyses ever arrived, so PRs hung indefinitely on
"Waiting for Code scanning results" in the GitHub UI (see #91). The
ruleset was edited to remove those two rule types. The remaining
rules are still enforced:

```text
deletion
non_fast_forward
pull_request
required_status_checks
```

If you want to re-enable scanning later, removing it from the
ruleset alone is not enough — the right path is to first enable
GHAS / Code Security on the repo (which costs money on private
repos) AND add a CodeQL workflow file that actually uploads
analyses. Adding the ruleset rule without a workflow that produces
results re-creates the phantom-check problem.

To inspect the live ruleset state, run:

```text
gh api repos/TheVoskamps/global-claude-config/rulesets/16051262
```

## Cost Optimization

- Lambda memory sized appropriately (test with PowerTuning)
- DynamoDB uses reserved capacity for predictable workloads
- Implement caching for read-heavy patterns (DAX/ElastiCache)

## Security

- No hardcoded credentials (use Secrets Manager/Parameter Store)
- All cross-service calls use IAM roles (no API keys)
- Input validation on all external inputs
- CORS properly configured (no wildcard origins in production)
