import gleeunit/should
import h2o/frame
import h2o/frame/error
import h2o/frame/header

pub fn parse_continuation_test() {
  // RFC 9113 Section 6.10: Basic CONTINUATION frame with fragment
  let data = <<
    5:size(24), 9:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(#(frame.Continuation(end_headers: False, data: <<"hello":utf8>>), <<>>)),
  )
}

pub fn parse_continuation_end_headers_test() {
  // RFC 9113 Section 6.10: END_HEADERS (0x04) flag signals last continuation
  let data = <<
    3:size(24), 9:size(8), 4:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(#(frame.Continuation(end_headers: True, data: <<"abc":utf8>>), <<>>)),
  )
}

pub fn parse_continuation_empty_fragment_test() {
  // RFC 9113 Section 6.10: Empty fragment is valid
  let data = <<0:size(24), 9:size(8), 0:size(8), 0:size(1), 1:size(31)>>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(#(frame.Continuation(end_headers: False, data: <<>>), <<>>)),
  )
}

pub fn parse_continuation_stream_id_zero_test() {
  // RFC 9113 Section 6.10: Stream ID 0x00 MUST be treated as connection error PROTOCOL_ERROR
  let data = <<
    3:size(24), 9:size(8), 0:size(8), 0:size(1), 0:size(31), "abc":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_continuation_unknown_flags_ignored_test() {
  // RFC 9113 Section 4.1: Unknown flags MUST be ignored
  // 0xFB has all bits set except END_HEADERS
  let data = <<
    3:size(24), 9:size(8), 0xFB:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(#(frame.Continuation(end_headers: False, data: <<"abc":utf8>>), <<>>)),
  )
}

pub fn parse_continuation_truncated_payload_test() {
  // RFC 9113 Section 6.10: Incomplete payload
  let data = <<
    10:size(24), 9:size(8), 0:size(8), 0:size(1), 1:size(31), "short":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_continuation_with_trailing_data_test() {
  // RFC 9113 Section 6.10: Trailing data from next frame returned
  let data = <<
    3:size(24), 9:size(8), 0:size(8), 0:size(1), 1:size(31), "abc":utf8, 99, 99,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(frame.Continuation(end_headers: False, data: <<"abc":utf8>>), <<99, 99>>),
    ),
  )
}

// --- Encode tests ---

pub fn encode_continuation_test() {
  // RFC 9113 Section 6.10: Basic CONTINUATION frame with fragment
  frame.encode_continuation(stream_id: 1, end_headers: False, data: <<
    "hello":utf8,
  >>)
  |> should.equal(
    Ok(<<5:size(24), 9:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8>>),
  )
}

pub fn encode_continuation_end_headers_test() {
  // RFC 9113 Section 6.10: END_HEADERS (0x04) flag signals last continuation
  frame.encode_continuation(stream_id: 1, end_headers: True, data: <<
    "abc":utf8,
  >>)
  |> should.equal(
    Ok(<<3:size(24), 9:size(8), 4:size(8), 0:size(1), 1:size(31), "abc":utf8>>),
  )
}

pub fn encode_continuation_empty_fragment_test() {
  // RFC 9113 Section 6.10: Empty fragment is valid
  frame.encode_continuation(stream_id: 1, end_headers: False, data: <<>>)
  |> should.equal(
    Ok(<<0:size(24), 9:size(8), 0:size(8), 0:size(1), 1:size(31)>>),
  )
}

pub fn encode_continuation_stream_id_zero_test() {
  // RFC 9113 Section 6.10: CONTINUATION MUST be associated with a stream
  frame.encode_continuation(stream_id: 0, end_headers: False, data: <<
    "abc":utf8,
  >>)
  |> should.be_error()
}

pub fn encode_continuation_roundtrip_test() {
  // Encode then parse should produce the same values
  let assert Ok(encoded) =
    frame.encode_continuation(stream_id: 3, end_headers: True, data: <<
      "hpack":utf8,
    >>)
  let assert Ok(#(h, rest)) = header.parse_header(encoded)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(#(frame.Continuation(end_headers: True, data: <<"hpack":utf8>>), <<>>)),
  )
}
