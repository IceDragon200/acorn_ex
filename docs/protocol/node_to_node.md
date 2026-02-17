# Node To Node

This document covers the node-to-node addressing for messages.

Senders MAY provide a `From` header containing their [identity](./identity.md), receivers are allowed to accept or reject requests with or without a `From` header.

When `From` is not present, `Reply-To` and `Ack-To` SHALL be used for Replies and ACKs.

If the request contains a `Reply-To` header however, it should be treated as the return destination for any `ACK` or replies.
If the request contains a `Ack-To` header, only `ACK` requests should be forwarded to the specified destination, replies should be sent to `Reply-To` or `From` in that order whichever is present.

Requests MAY contain a `To` header, receivers can determine if they wish to honour the request without a `To` header.

Note. `Reply-To` and `Ack-To` should NOT be treated as an authoritative replacement for `From` as they only affect the reply vectors for a request's potential response.

When return addressing becomes impossible, where `From`, `Reply-To`, and `Ack-To` are unavailable, the receiver may perform a `recvfrom` to return any `ACK` or replies, but can choose not to reply at all if the headers are considered **required**.

## Reply Precedence

When a receiver is replying to a message it SHOULD utilize the following in this order:

* `Reply-To` - should be considered the highest authority for replies
* `From` - when no `Reply-To` is provided, messages should be returned to the originator

## Ack Precedence

When a receive is acknowledging a message it SHOULD utilize the following in this order:

* `Ack-To` - should be considered the highest authority for ACKs
* `Reply-To` - in the event that `Ack-To` was not provided, the `Reply-To` can be used instead
* `From` - in case neither `Ack-To` nor `Reply-To` was provided, the originator can be used instead
