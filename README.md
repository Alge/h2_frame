# h2_frame

[![Package Version](https://img.shields.io/hexpm/v/h2_frame)](https://hex.pm/packages/h2_frame)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/h2_frame/)

An HTTP/2 frame encoder and decoder for Gleam.

Handles all standard HTTP/2 frame types as defined in [RFC 9113](https://httpwg.org/specs/rfc9113.html): DATA, HEADERS, PRIORITY, RST_STREAM, SETTINGS, PUSH_PROMISE, PING, GOAWAY, WINDOW_UPDATE, and CONTINUATION. Unknown frame types are preserved rather than rejected.

## Installation

```sh
gleam add h2_frame
```

## Usage

### Parsing

```gleam
import h2_frame

let assert Ok(#(frame, rest)) = h2_frame.parse(data)
```

### Encoding

```gleam
// Encode a settings frame
let assert Ok(frame) =
  h2_frame.encode_settings(ack: False, settings: [
    h2_frame.MaxConcurrentStreams(100),
    h2_frame.InitialWindowSize(65535),
  ])

// Encode a ping frame
let assert Ok(frame) =
  h2_frame.encode_ping(ack: False, data: <<1, 2, 3, 4, 5, 6, 7, 8>>)
```

## Documentation

Full API documentation is available at <https://hexdocs.pm/h2_frame>.
