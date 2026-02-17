# Ack(nowledgement)

Nodes can transmit messages between themselves, the behaviour or semantics of the recipient and sender nodes is up to the implementor, Acorn does not enforce any particular command set.

However, Acorn will SUGGEST, the implementation of at least an `ACK` response that SHOULD BE treated as reserved in implementations for the sole purpose of alerting senders that their message has been successfully received:

```acorn
ACORN/1.0 000 ACK
Message-ID: ack-unique-id
TX-ID: same-as-the-request-tx-id
From: node2@127.0.0.1:7078
To: node1@127.0.0.1:7077
```

The Status Code 000 SHALL be treated as the `ACK` status code, even in the absence of its Status Text.

## Addressing

ACKs follow the same rules as general replies, From/To should be flipped for replies, as the reply originates from the original receiver and is destined for the original sender.

## TX-ID

ACK's SHALL use the TX-ID of the PDU that they are acknowledging or responding to, Message-ID should be unique to the ACK itself.

Note some additional features may have additional headers used as part of their "uniqueness" calculations.

## Reply as ACK

__Note__ Nodes CAN send a reply response in addition to the `ACK`, should the response be received before the ACK, the request should consider the response to be an `ACK` of its own IF:
* `TX-ID` matches the original request
* `Ack-Message-ID` is present to alert the receiver that the reply is an `explicit` replacement for the `ACK` and matches the original request's `Message-ID`

Note. a body is NOT required for an ACK, but can be sent to facilitate rich responses.

## Example

Client Sends:

```acorn
REG /path/to/whatever ACORN/1.0
Message-ID: my-totally-unqiue-id
TX-ID: tx-1
From: node1@127.0.0.1:7077
To: node2@127.0.0.1:7078
Content-Type: application/json

{}
```

Server Senders:

```acorn
ACORN/1.0 000 ACK
Message-ID: ack-for-my-totally-unqiue-id
TX-ID: tx-1
From: node2@127.0.0.1:7078
To: node1@127.0.0.1:7077
Content-Type: application/json

{"message": "Got it"}
```

Server Later Sends:

```acorn
ACORN/1.0 202 Registered
Message-ID: server-issued-unique-id
TX-ID: tx-1
Content-Type: application/json

{"token": "whatever-auth-token-the-server-felt-like-providing"}
```

Client finally responds with:

```acorn
ACORN/1.0 000 ACK
Message-ID: id-for-this-ack
TX-ID: tx-1
Content-Type: application/json

{"message": "Thanks... I guess?"}
```

Thus concluding the request/response exchange, should the client send its ACK BEFORE receiving a response, the receiver should not attempt to send or resend a reply.

Note there are no "sequence" requirements at this stage, as this exchange is treated as outside of a [session](./session.md).

Note that ACK can break the request-response rule, as the ACK from the client side is acknowledging the Response of the server, for clarity, the message CAN include a `Ack-Message-ID` header should the TX-ID feel insufficient:
```acorn
ACORN/1.0 000 ACK
Ack-Message-ID: server-issued-unique-id
```

Nodes SHOULD validate the acknowledgement against the known message id, no action is required should it be seen as incorrect and the ACK can be ignored, retransmission actions may proceed as if it had never happened.
