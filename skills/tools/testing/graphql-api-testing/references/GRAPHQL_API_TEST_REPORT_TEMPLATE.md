# API Test Report (<YYYY-MM-DD>)

## Test Case: <TEST_CASE_NAME>

## Command

```bash
"$CODEX_HOME/skills/tools/testing/graphql-api-testing/scripts/gql.sh" \
  --env <ENV_NAME> \
  --jwt <JWT_NAME> \
  setup/graphql/operations/<OPERATION_NAME>.graphql \
  setup/graphql/operations/<VARIABLES_NAME>.json \
| jq .
```

Generated at: <YYYY-MM-DDTHH:MM:SS±ZZZZ>

Endpoint: --env <ENV_NAME>

Result: <PASS|FAIL|NOT_EXECUTED>

### GraphQL Operation

```graphql
query <OPERATION_NAME>($input: <INPUT_TYPE>!) {
  <field>(input: $input) {
    <selectionSet>
  }
}
```

### GraphQL Operation (Variables)

```json
{
  "input": {
    "limit": 5,
    "<INPUT_KEY>": "<INPUT_VALUE>"
  }
}
```

### Response

```json
{
  "data": {
    "<DATA_KEY>": "<DATA_VALUE>"
  }
}
```
