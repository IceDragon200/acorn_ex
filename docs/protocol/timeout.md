# Timeout

With retries, comes when and how many times a request should be retried before giving up.

Messages may include a `TS` header which SHALL contain the Unix timestamp in UTC of when the message was generated.

Nodes may enforce any time sensitive actions for messages that fall within or outside of their accepted range.

```acorn
GET /data/xb ACORN/1.0
TS: 1771283196
```

But... if TS feels too restrictive, messages CAN contain a `Date` header instead formatted in ISO8601,

```acorn
GET /data/xb ACORN/1.0
Date: 2026-02-16T23:09:00Z
```

If both headers are provided, nodes should honour TS first (its the easier one to parse) and MAY validate the Date if required.

Note a `TS` and or `Date` is allowed to change between retransmissions and should not be counted for unqiueness of a message.

## `Timeout` Header

Either party may include a `Timeout` header in its messages, this should be added to TS or Date header to determine the final timeout threshold.

Upon Timeout, the sender shall retransmit the request, receivers who have exceeded the Timeout for a reply MAY keep any changes already performed, but hold the message until it is retransmitted by the sender, if no retransmission arrives in time, the node is free to undo or leave any changes performed depending on policy.
