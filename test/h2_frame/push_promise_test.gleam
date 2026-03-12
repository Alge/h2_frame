import gleam/option.{None, Some}
import gleeunit/should
import h2_frame
import h2_frame/error
import h2_frame/header

pub fn parse_push_promise_test() {
  // RFC 9113 Section 6.6: Basic PUSH_PROMISE frame
  // reserved=0, promised_stream_id=2, fragment="abc"
  let data = <<
    7:size(24), 5:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    2:size(31), "abc":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.PushPromise(end_headers: False, promised_stream_id: 2, data: <<
          "abc":utf8,
        >>),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_end_headers_test() {
  // RFC 9113 Section 6.6: END_HEADERS (0x04) flag
  let data = <<
    7:size(24), 5:size(8), 4:size(8), 0:size(1), 1:size(31), 0:size(1),
    2:size(31), "abc":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.PushPromise(end_headers: True, promised_stream_id: 2, data: <<
          "abc":utf8,
        >>),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_padded_test() {
  // RFC 9113 Section 6.6: PADDED (0x08) flag
  // pad_length=2, reserved=0, promised_stream_id=2, fragment="ab", padding=0x00 0x00
  let data = <<
    9:size(24), 5:size(8), 8:size(8), 0:size(1), 1:size(31), 2:size(8),
    0:size(1), 2:size(31), "ab":utf8, 0, 0,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.PushPromise(end_headers: False, promised_stream_id: 2, data: <<
          "ab":utf8,
        >>),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_padded_end_headers_test() {
  // RFC 9113 Section 6.6: Both PADDED (0x08) and END_HEADERS (0x04)
  let data = <<
    9:size(24), 5:size(8), 0x0C:size(8), 0:size(1), 1:size(31), 2:size(8),
    0:size(1), 2:size(31), "ab":utf8, 0, 0,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.PushPromise(end_headers: True, promised_stream_id: 2, data: <<
          "ab":utf8,
        >>),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_stream_id_zero_test() {
  // RFC 9113 Section 6.6: Stream ID 0x00 MUST be treated as connection error PROTOCOL_ERROR
  let data = <<
    7:size(24), 5:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    2:size(31), "abc":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(Error(h2_frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_push_promise_padding_exceeds_payload_test() {
  // RFC 9113 Section 6.6: Padding length >= payload length is PROTOCOL_ERROR
  // length=6, pad_length=6 leaves no room
  let data = <<
    6:size(24), 5:size(8), 8:size(8), 0:size(1), 1:size(31), 6:size(8),
    0:size(1), 2:size(31), 0,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(Error(h2_frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_push_promise_empty_fragment_test() {
  // RFC 9113 Section 6.6: PUSH_PROMISE with empty fragment is valid
  let data = <<
    4:size(24), 5:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    2:size(31),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.PushPromise(end_headers: False, promised_stream_id: 2, data: <<>>),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_unknown_flags_ignored_test() {
  // RFC 9113 Section 4.1: Unknown flags MUST be ignored
  // 0xF3 has undefined bits set, no PADDED or END_HEADERS active
  let data = <<
    7:size(24), 5:size(8), 0xF3:size(8), 0:size(1), 1:size(31), 0:size(1),
    2:size(31), "abc":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.PushPromise(end_headers: False, promised_stream_id: 2, data: <<
          "abc":utf8,
        >>),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_truncated_payload_test() {
  // RFC 9113 Section 6.6: Incomplete payload (can't even read promised stream ID)
  let data = <<7:size(24), 5:size(8), 0:size(8), 0:size(1), 1:size(31), 0, 0>>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(Error(h2_frame.IncompletePayload))
}

pub fn parse_push_promise_padded_empty_payload_test() {
  // RFC 9113 Section 6.6: PADDED flag set but no payload bytes at all
  let data = <<7:size(24), 5:size(8), 8:size(8), 0:size(1), 1:size(31)>>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(Error(h2_frame.IncompletePayload))
}

pub fn parse_push_promise_with_trailing_data_test() {
  // RFC 9113 Section 6.6: Trailing data from next frame returned
  let data = <<
    7:size(24), 5:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    2:size(31), "abc":utf8, 99, 99,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.PushPromise(end_headers: False, promised_stream_id: 2, data: <<
          "abc":utf8,
        >>),
        <<99, 99>>,
      ),
    ),
  )
}

pub fn parse_push_promise_padded_zero_padding_test() {
  // RFC 9113 Section 6.6: PADDED flag with pad_length=0 is valid
  let data = <<
    8:size(24), 5:size(8), 8:size(8), 0:size(1), 1:size(31), 0:size(8),
    0:size(1), 2:size(31), "abc":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.PushPromise(end_headers: False, promised_stream_id: 2, data: <<
          "abc":utf8,
        >>),
        <<>>,
      ),
    ),
  )
}

// --- Encode tests ---

pub fn encode_push_promise_test() {
  // RFC 9113 Section 6.6: Basic PUSH_PROMISE frame
  h2_frame.encode_push_promise(
    stream_id: 1,
    end_headers: False,
    promised_stream_id: 2,
    data: <<"abc":utf8>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<
      7:size(24), 5:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
      2:size(31), "abc":utf8,
    >>),
  )
}

pub fn encode_push_promise_end_headers_test() {
  // RFC 9113 Section 6.6: END_HEADERS (0x04) flag
  h2_frame.encode_push_promise(
    stream_id: 1,
    end_headers: True,
    promised_stream_id: 2,
    data: <<"abc":utf8>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<
      7:size(24), 5:size(8), 4:size(8), 0:size(1), 1:size(31), 0:size(1),
      2:size(31), "abc":utf8,
    >>),
  )
}

pub fn encode_push_promise_padded_test() {
  // RFC 9113 Section 6.6: PADDED (0x08) flag with 2 bytes of padding
  h2_frame.encode_push_promise(
    stream_id: 1,
    end_headers: False,
    promised_stream_id: 2,
    data: <<"ab":utf8>>,
    padding: Some(2),
  )
  |> should.equal(
    Ok(<<
      9:size(24), 5:size(8), 8:size(8), 0:size(1), 1:size(31), 2:size(8),
      0:size(1), 2:size(31), "ab":utf8, 0, 0,
    >>),
  )
}

pub fn encode_push_promise_padded_end_headers_test() {
  // RFC 9113 Section 6.6: Both PADDED (0x08) and END_HEADERS (0x04)
  h2_frame.encode_push_promise(
    stream_id: 1,
    end_headers: True,
    promised_stream_id: 2,
    data: <<"ab":utf8>>,
    padding: Some(2),
  )
  |> should.equal(
    Ok(<<
      9:size(24), 5:size(8), 0x0C:size(8), 0:size(1), 1:size(31), 2:size(8),
      0:size(1), 2:size(31), "ab":utf8, 0, 0,
    >>),
  )
}

pub fn encode_push_promise_padded_zero_test() {
  // RFC 9113 Section 6.6: PADDED flag with pad_length=0 is valid
  h2_frame.encode_push_promise(
    stream_id: 1,
    end_headers: False,
    promised_stream_id: 2,
    data: <<"abc":utf8>>,
    padding: Some(0),
  )
  |> should.equal(
    Ok(<<
      8:size(24), 5:size(8), 8:size(8), 0:size(1), 1:size(31), 0:size(8),
      0:size(1), 2:size(31), "abc":utf8,
    >>),
  )
}

pub fn encode_push_promise_empty_fragment_test() {
  // RFC 9113 Section 6.6: PUSH_PROMISE with empty fragment is valid
  h2_frame.encode_push_promise(
    stream_id: 1,
    end_headers: False,
    promised_stream_id: 2,
    data: <<>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<
      4:size(24), 5:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
      2:size(31),
    >>),
  )
}

pub fn encode_push_promise_stream_id_zero_test() {
  // RFC 9113 Section 6.6: PUSH_PROMISE MUST be associated with a stream
  h2_frame.encode_push_promise(
    stream_id: 0,
    end_headers: False,
    promised_stream_id: 2,
    data: <<"abc":utf8>>,
    padding: None,
  )
  |> should.be_error()
}

pub fn encode_push_promise_padding_negative_test() {
  // Padding must be non-negative
  h2_frame.encode_push_promise(
    stream_id: 1,
    end_headers: False,
    promised_stream_id: 2,
    data: <<"abc":utf8>>,
    padding: Some(-1),
  )
  |> should.equal(Error(h2_frame.InvalidPadding))
}

pub fn encode_push_promise_padding_exceeds_byte_test() {
  // RFC 9113 Section 6.6: Pad Length is a single 8-bit field; max value is 255
  h2_frame.encode_push_promise(
    stream_id: 1,
    end_headers: False,
    promised_stream_id: 2,
    data: <<"abc":utf8>>,
    padding: Some(256),
  )
  |> should.equal(Error(h2_frame.InvalidPadding))
}

pub fn encode_push_promise_roundtrip_test() {
  // Encode then parse should produce the same values
  let assert Ok(encoded) =
    h2_frame.encode_push_promise(
      stream_id: 5,
      end_headers: True,
      promised_stream_id: 4,
      data: <<"test":utf8>>,
      padding: None,
    )
  let assert Ok(#(h, rest)) = header.parse_header(encoded)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.PushPromise(end_headers: True, promised_stream_id: 4, data: <<
          "test":utf8,
        >>),
        <<>>,
      ),
    ),
  )
}

pub fn encode_push_promise_padded_roundtrip_test() {
  // Padded encode then parse should strip padding and recover data
  let assert Ok(encoded) =
    h2_frame.encode_push_promise(
      stream_id: 3,
      end_headers: False,
      promised_stream_id: 6,
      data: <<"hpack":utf8>>,
      padding: Some(3),
    )
  let assert Ok(#(h, rest)) = header.parse_header(encoded)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.PushPromise(end_headers: False, promised_stream_id: 6, data: <<
          "hpack":utf8,
        >>),
        <<>>,
      ),
    ),
  )
}
