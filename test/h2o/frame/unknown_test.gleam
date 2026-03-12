import gleeunit/should
import h2o/frame
import h2o/frame/header

pub fn parse_unknown_frame_test() {
  // RFC 9113 Section 4.1: Unknown frame types MUST be ignored
  // Frame type 0xFF with some payload
  let data = <<
    5:size(24), 0xFF:size(8), 0:size(8), 0:size(1), 0:size(31), "hello":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.Unknown(data: <<"hello":utf8>>), <<>>)))
}

pub fn parse_unknown_frame_with_stream_id_test() {
  // RFC 9113 Section 4.1: Unknown frames can have any stream ID
  let data = <<
    3:size(24), 0x0A:size(8), 0:size(8), 0:size(1), 5:size(31), "abc":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.Unknown(data: <<"abc":utf8>>), <<>>)))
}

pub fn parse_unknown_frame_with_flags_test() {
  // RFC 9113 Section 4.1: Unknown frame flags are preserved but ignored
  let data = <<
    3:size(24), 0x0B:size(8), 0xFF:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.Unknown(data: <<"abc":utf8>>), <<>>)))
}

pub fn parse_unknown_frame_empty_payload_test() {
  // RFC 9113 Section 4.1: Unknown frame with zero-length payload
  let data = <<0:size(24), 0x0C:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.Unknown(data: <<>>), <<>>)))
}

pub fn parse_unknown_frame_truncated_payload_test() {
  // RFC 9113 Section 4.1: Incomplete payload
  let data = <<
    10:size(24), 0x0D:size(8), 0:size(8), 0:size(1), 0:size(31), "short":utf8,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_unknown_frame_with_trailing_data_test() {
  // RFC 9113 Section 4.1: Trailing data from next frame returned
  let data = <<
    3:size(24), 0x0E:size(8), 0:size(8), 0:size(1), 0:size(31), "abc":utf8, 99,
    99,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.Unknown(data: <<"abc":utf8>>), <<99, 99>>)))
}

// --- Encode tests ---

pub fn encode_unknown_frame_test() {
  // RFC 9113 Section 4.1: Encode an unknown frame type
  frame.encode_unknown(frame_type_code: 0xFF, stream_id: 0, flags: 0, data: <<
    "hello":utf8,
  >>)
  |> should.equal(
    Ok(<<
      5:size(24), 0xFF:size(8), 0:size(8), 0:size(1), 0:size(31), "hello":utf8,
    >>),
  )
}

pub fn encode_unknown_frame_with_stream_id_test() {
  // RFC 9113 Section 4.1: Unknown frames can have any stream ID
  frame.encode_unknown(frame_type_code: 0x0A, stream_id: 5, flags: 0, data: <<
    "abc":utf8,
  >>)
  |> should.equal(
    Ok(<<
      3:size(24), 0x0A:size(8), 0:size(8), 0:size(1), 5:size(31), "abc":utf8,
    >>),
  )
}

pub fn encode_unknown_frame_with_flags_test() {
  // RFC 9113 Section 4.1: Unknown frames can carry arbitrary flags
  frame.encode_unknown(frame_type_code: 0x0B, stream_id: 1, flags: 0xFF, data: <<
    "abc":utf8,
  >>)
  |> should.equal(
    Ok(<<
      3:size(24), 0x0B:size(8), 0xFF:size(8), 0:size(1), 1:size(31), "abc":utf8,
    >>),
  )
}

pub fn encode_unknown_frame_empty_payload_test() {
  // RFC 9113 Section 4.1: Unknown frame with zero-length payload
  frame.encode_unknown(
    frame_type_code: 0x0C,
    stream_id: 0,
    flags: 0,
    data: <<>>,
  )
  |> should.equal(
    Ok(<<0:size(24), 0x0C:size(8), 0:size(8), 0:size(1), 0:size(31)>>),
  )
}

pub fn encode_unknown_frame_roundtrip_test() {
  // Encode then parse should produce the same values
  let assert Ok(encoded) =
    frame.encode_unknown(frame_type_code: 0x0E, stream_id: 0, flags: 0, data: <<
      "test":utf8,
    >>)
  let assert Ok(#(h, rest)) = header.parse_header(encoded)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.Unknown(data: <<"test":utf8>>), <<>>)))
}
