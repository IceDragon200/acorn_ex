# Expiration

`Timeout` and `Attempt` solve a simple problem: when a message is considered out of window and how many times should it be attempted retransmission or should be expected to retry.

However, nodes may wish to give a message a hard cutoff.

`Expire-At` allows a message to be given a timestamp at which it should be considered "expired" and should not be acted upon.

```acorn
GET / ACORN/1.0
Expire-At: 1771283231
```

Should the receiver evaluate the header to be already passed its current time, the message SHOULD be ignored.

In the case that the message was part of a sequence, the receive can ask for the missing PDU or wait for the sender to retry later.

But I hear you, again with the unix timestamps?

`Expire-Date`, may be provided in place of `Expire-At`.

```acorn
GET / ACORN/1.0
Expire-Date: 2026-02-16T23:09:00Z
```
