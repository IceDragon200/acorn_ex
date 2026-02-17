# Session

Acorn allows nodes to send messages back and forth in any order they like, there is no enforcement of order or sequence under an open exchange.

This document however aims to provide a Session and Sequence system to put some much needed order into the protocol.

For a sequential session, either or both the client and server should provide a `Seq` header, with an integer value typically starting at 0 unless otherwise negotiated (not covered here):

`Request-Session-Mode` SHALL accompany a session that requires a specific mode of operation with values: `ordered`, or `unordered` respectively.

Receivers may respond with a `Set-Session-Mode` header with the agreed upon session mode.

Should the receiver return a mode NOT agreed upon, sender should immediately NACK the reply and restate its original `Request-Session-Mode` for reference:

```acorn
ACORN/1.0 200 OK
Set-Session-Mode: unordered
```

```acorn
ACORN/1.0 001 NACK
Request-Session-Mode: ordered
```

Sender CAN issue a new `REG` request to attempt again.

## `Need-Seq` Header

__Applies To__ ordered mode

__Note__ `Need-Seq` header may be issued by either party at any time to notify the other party retransmit transactions.

`Need-Seq` has the form:

```
Need-Seq: NUM, X..Y
```

That is, it is a list of Numbers and or ranges.

Multiple `Need-Seq` headers may be provided and should be treated as a concatenated list.

Receivers SHOULD retransmit from the smallest transaction to the largest, ordered by `Seq`.

__Note__ `Need-Seq` should ONLY be used in a Reply, but PREFERRED in a ACK (000) or NACK (001).

## Examples

### Example - Simple Session Init

Client initiates a request with the Server:

```acorn
REG /path ACORN/1.0
TX-ID: 11
Seq: 0
Request-Session-Mode: ordered
```

The server should ACK the attempt with its own `Seq` header:

```acorn
ACORN/1.0 000 ACK
TX-ID: 11
Seq: 0
```

The server can then reply later with its final response for the initial request:
```acorn
ACORN/1.0 200 OK
TX-ID: 11
Seq: 1222
Set-Session-Mode: ordered
```

### Example - Missing Transactions

Clients and servers SHOULD process PDUs by the order of the server or client respectively.

If either node receives a message that is ahead of its last known sequence, it should immediately issue a NACK:

```acorn
ACORN/1.0 001 NACK
Seq: 1222
Need-Seq: 12..17,19
```

`Need-Seq` should inform the receiver of what sequence item(s) are missing and needs to be retransmitted.

The receiver SHOULD halt sending any new PDUs until the Need-Seq has been satisfied, or may choose to terminate the session if it believes it cannot comply, or may no longer have those messages.

If the receiver cannot comply, it can offer to "bow out" or terminate the current session:
```acorn
BYE / ACORN/1.0
Ignore-Seq: *
```

`Ignore-Seq` alerts the receiver that all "missing" Seq requests should be ignored and this one be treated as authorative if it complies with the session identity.

The receiver can then respond with an ACK with no further reply needed.

```acorn
ACORN/1.0 000 ACK
```

The original client party may re-register to restart the sequences from 0 once more.
