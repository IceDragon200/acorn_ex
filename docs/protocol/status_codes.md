# Status Codes

Acorn only reserves status codes 000 (ACK) and 001 (NACK), and status codes may range from 002..999 as needed.

However, implementations are encouraged to follow general standards for wire protocols:

* `0XX` for protocol replies (only ACK and NACK at this time)
* `1XX` for informational replies
* `2XX` for affirmative replies
* `3XX` for intermediate replies
* `4XX` for client error replies
* `5XX` for server error replies
