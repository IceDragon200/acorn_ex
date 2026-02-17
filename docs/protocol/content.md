# Content

Messages would be nothing without their actual body, outside of a glorified key-value blob.

Not to annoy anyone, but:

```
Content-Type: application/octet-stream
Content-Length: 512
Content-Encoding: gzip
```

`Content-Type`, `Content-Length`, `Content-Encoding` SHALL be accepted as valid headers.

`Content-Hash-<METHOD>` may also be provided to provide integrity information of a message's body.

Note that `Content-Hash-*` applies to the message, and not the complete payload for [segmentation](./segmentation.md), use `Payload-Hash-*` instead.
