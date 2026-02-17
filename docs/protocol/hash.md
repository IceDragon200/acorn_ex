# Hash

`SHA256` and other hashing methods may be used to provide an integrity hash of the message.

What if I wanted a HMAC?

Use `*-Hash-HMAC-<METHOD>`, with whatever key the receiver and sender have agreed upon.

```
Content-Hash-HMAC-SHA256: Base64Digest
```
