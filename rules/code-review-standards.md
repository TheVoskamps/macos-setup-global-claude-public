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

## Cost Optimization

- Lambda memory sized appropriately (test with PowerTuning)
- DynamoDB uses reserved capacity for predictable workloads
- Implement caching for read-heavy patterns (DAX/ElastiCache)

## Security

- No hardcoded credentials (use Secrets Manager/Parameter Store)
- All cross-service calls use IAM roles (no API keys)
- Input validation on all external inputs
- CORS properly configured (no wildcard origins in production)
