# AWS Development

## Security Standards

- Never commit AWS credentials to the repository
- Use IAM roles with least privilege
- Rotate credentials regularly
- Enable CloudTrail in all accounts
- Use AWS Config for compliance monitoring
- Implement SCPs for organization-wide guardrails

### 1. NEVER DEPLOY TO AWS FROM LOCAL

We deploy through a centralized pipeline architecture. ALL changes deploy through the pipeline, NEVER from local.

- **NEVER run `npm deploy` from local** - ONLY commit and push to trigger pipeline
- **NEVER run `pnpm deploy` from local** - ONLY commit and push to trigger pipeline
- **NEVER run `cdk deploy` from local** - ONLY commit and push to trigger pipeline
- **NEVER run `npx cdk deploy` from local**  ONLY commit and push to trigger pipeline
- **After any infrastructure change**: Local Build → Commit → Push → Monitor pipeline

**Correct workflow**:

1. Make changes to code
2. Build locally and fix until compiles clean
3. Commit changes with clear message
4. Push to trigger pipeline
5. Monitor pipeline execution
6. Pipeline deploys changes automatically

If you want to trigger the pipeline:

1. ideally use a commit, but empty commits won't work as we use GitHub V2 Source with path/file filters
2. use aws codepipeline start-pipeline-execution with the right SSO profile

## Critical Architecture Patterns

### CloudFormation Custom Resources

**✅ CORRECT**: Always use `cr.Provider` to wrap Lambda:

When creating CloudFormation custom resources with Lambda functions:

- **NEVER** use bare Lambda functions with `cdk.CustomResource` - they must manually send HTTP PUT to `event.ResponseURL`
- **ALWAYS** use `cr.Provider` from `aws-cdk-lib/custom-resources` - it handles the CloudFormation response protocol automatically
- The Provider framework ensures CloudFormation receives responses for Create, Update, and Delete events
- Without Provider, Delete operations will hang indefinitely waiting for a response that never arrives

```typescript
const provider = new cr.Provider(this, 'Provider', {
  onEventHandler: myLambda,
  // Only include totalTimeout with isCompleteHandler for async operations
});

new cdk.CustomResource(this, 'Resource', {
  serviceToken: provider.serviceToken,
  properties: { ... }
});
```

**Benefits**: Automatic SUCCESS/FAILED responses, fast failure, no manual HTTP
handling

**IMPORTANT**: `totalTimeout` requires `isCompleteHandler` - only use for async
operations. Synchronous operations complete within `onEventHandler`.

### AWS CodePipeline Roles

- **Pipeline role**: Minimal orchestration (S3, CodeBuild start, CodeStar)
- **Build roles**: Comprehensive (attached to CodeBuild projects)
- **No explicit action roles**: Let CodePipeline auto-create

### Cross-Account Resources

Use Lambda custom resources with AssumeRole:

1. Lambda in management account
2. Assume `OrganizationAccountAccessRole` in target
3. Create resources in target account
4. Return details as custom resource attributes

## Critical Learnings

### IAM Identity Center Async API

- `createAccountAssignment` returns immediately with IN_PROGRESS
- MUST poll `describeAccountAssignmentCreationStatus` until SUCCEEDED
- Process assignments sequentially (one at a time per account)
- Use 5-second delays between assignments

### Route53 TXT Records

- Provide UNquoted values in CDK (API adds quotes)
- Values >255 chars: Split into chunks, quote each separately
- UPSERT doesn't update existing TXT values - use DELETE then CREATE
- DNS names: Always use FQDN (not @ or unqualified)

### CloudFormation UPDATE Triggers

- Custom resources only UPDATE when properties change
- Lambda code fixes don't trigger UPDATE
- Use `forceUpdate` timestamp property when needed
- Disable force flag after successful deployment

### AWS Chatbot Guardrails

- Guardrail policies are MORE restrictive than IAM role policies
- Effective permissions = Intersection of IAM role + guardrail policies
- Both must grant permissions for chat commands to work
- Read-only channels need CodePipeline guardrail for "Get Info" button

### Deployment Window Checker

- Should fail immediately when outside window, not poll
- Continuation tokens appropriate for async operations only (not blocking checks)
- Clear error messages with next available window (timezone-aware)

### Lambda Structure Pattern

- Normalize to subdirectory/index.ts pattern
- package.json and tsconfig.json in Lambda dirs are redundant
- CDK's NodejsFunction uses parent package.json for bundling
- Keep only index.ts in Lambda subdirectories

### Cross-Account CodePipeline Lambda Pattern (Phase 6e)

- Control plane Lambdas must use cross-account clients for job status reporting
- Extract account ID from CodePipeline job event (`event['CodePipeline.job'].accountId`)
- Use shared helper module for consistent cross-account logic
- Cache credentials for warm Lambda container reuse (15-minute duration)
- Create cross-account role (ExampleCrossAccountRole) in target account
- Trust Management account principal, grant PutJobSuccessResult/PutJobFailureResult

## AWS CLI Credentials

AWS CLI profiles are configured for IAM Identity Center SSO access with the format `<RoleName>-<AccountID>`.

**Available profiles**:

- `ExampleManagementAdmin-ACCOUNT` - Management account
- `ExampleInfrastructureAdmin-ACCOUNT` - Shared Services account
- `ExampleDevOpsAdmin-ACCOUNT` - DevOps account
- `ExampleSandboxAdmin-ACCOUNT]` - Sandbox accounts
- `ExampleIntegAdmin-ACCOUNT` - Integration account
- `ExampleQaAdmin-ACCOUNT` - QA account
- `ExampleProdAdmin-ACCOUNT` - Prod account

**Refreshing expired credentials**:

When AWS SSO credentials expire (`Token has expired and refresh failed` or similar), report the failure and stop. The user will run `aws sso login --profile <name>` on their own and tell you to retry. See `credential-surfaces.md` for the full rule. Do NOT run `aws sso login` yourself.

## Credentials to the `kubectl` command

To get access to kubectl in a specific workload account, run the following:

aws eks update-kubeconfig --region us-west-2 --name example-cluster --profile <PROFILE>

Where PROFILE is one of the Workload admin accounts, e.g. ExampleIntegAdmin-ACCOUNT
