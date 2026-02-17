# Retries

Messages have a deadline in the form of `Timeout`, however parties involved may include a `Attempt` header:

```acorn
GET / ACORN/1.0
Attempt: 1/5
```

`Attempt` should take the form of `Current/Maximum`, where `Current` and `Maximum` MUST be 1 or greater.

If no `Attempt` is provided, nodes are free to assume their defaults.
