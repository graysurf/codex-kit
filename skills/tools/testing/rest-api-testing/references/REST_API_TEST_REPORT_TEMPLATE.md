# API Test Report (<YYYY-MM-DD>)

## Test Case: <TEST_CASE_NAME>

## Command

```bash
api-rest call \
  --env <ENV_NAME> \
  setup/rest/requests/<REQUEST_NAME>.request.json \
| jq .
```

Generated at: <YYYY-MM-DDTHH:MM:SS±ZZZZ>

Endpoint: --env <ENV_NAME>

Result: <PASS|FAIL|NOT_EXECUTED>

### Assertions

- expect.status: <HTTP_STATUS> (<PASS|FAIL|NOT_EVALUATED>)
- expect.jq: <JQ_EXPRESSION> (<PASS|FAIL|NOT_EVALUATED>)

### Request

```json
{
  "method": "<GET|POST|PUT|PATCH|DELETE>",
  "path": "/<PATH>",
  "query": {
    "<QUERY_KEY>": "<QUERY_VALUE>"
  },
  "headers": {
    "<HEADER_KEY>": "<HEADER_VALUE>"
  },
  "body": {
    "<BODY_KEY>": "<BODY_VALUE>"
  },
  "expect": {
    "status": 200,
    "jq": "<JQ_EXPRESSION>"
  }
}
```

### Response

```json
{
  "<RESPONSE_KEY>": "<RESPONSE_VALUE>"
}
```

### stderr

```text
<STDERR_OUTPUT>
```
