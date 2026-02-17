# Segmentation

As the primarily protocol is UDP, messages will and often time exceed the MTU, Acorn has a proposed multi-segment handling.

A `Segment` header can be supplied in the message to alert the receive that it is part of a larger payload.

```acorn
PUT / ACORN/1.0
Segment: 1/5
Payload-Length: 8099
```

The optional `Payload-Length` communicates what the total length of the body should be by the end, if not present, the receiver should assume it has the complete message once all segments are received.

Note that segments are treated as seperate messages for the purpose of the protocol, but should be treated as a single blob when disgesting the message body, individual parts MUST be replied and ACK-ed like normal.

`Payload-Hash-*` headers may be used to provide a hash of the full payload for integrity checks, they may be ignored if the receiver believes the content has not been tampered with or cannot verify due to a lack of resources, receivers CAN reply with an error of its choosing should the header be unacceptable, or the content does not match.
