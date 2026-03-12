import gleeunit/should
import h2o/frame
import h2o/frame/error
import h2o/frame/header

pub fn parse_rst_stream_test() {
  // RFC 9113 Section 6.4: RST_STREAM with PROTOCOL_ERROR
  let data = <<
    4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0x01:size(32),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.RstStream(error_code: error.ProtocolError), <<>>)))
}

pub fn parse_rst_stream_no_error_test() {
  // RFC 9113 Section 6.4: RST_STREAM with NO_ERROR
  let data = <<
    4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0x00:size(32),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.RstStream(error_code: error.NoError), <<>>)))
}

pub fn parse_rst_stream_cancel_test() {
  // RFC 9113 Section 6.4: RST_STREAM with CANCEL
  let data = <<
    4:size(24), 3:size(8), 0:size(8), 0:size(1), 5:size(31), 0x08:size(32),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.RstStream(error_code: error.Cancel), <<>>)))
}

pub fn parse_rst_stream_unknown_error_code_test() {
  // RFC 9113 Section 7: Unknown error codes MUST NOT trigger special behavior
  let data = <<
    4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0xFF:size(32),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(#(frame.RstStream(error_code: error.UnknownErrorCode(0xFF)), <<>>)),
  )
}

pub fn parse_rst_stream_stream_id_zero_test() {
  // RFC 9113 Section 6.4: Stream ID 0x00 MUST be treated as connection error PROTOCOL_ERROR
  let data = <<
    4:size(24), 3:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(32),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_rst_stream_wrong_length_short_test() {
  // RFC 9113 Section 6.4: Length other than 4 MUST be treated as connection error FRAME_SIZE_ERROR
  let data = <<
    3:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0, 0, 0,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.ConnectionError(error.FrameSizeError)))
}

pub fn parse_rst_stream_wrong_length_long_test() {
  // RFC 9113 Section 6.4: Length greater than 4 is also FRAME_SIZE_ERROR
  let data = <<
    5:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0x01:size(32), 0,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.ConnectionError(error.FrameSizeError)))
}

pub fn parse_rst_stream_unknown_flags_ignored_test() {
  // RFC 9113 Section 6.4: No flags defined; all flags MUST be ignored
  let data = <<
    4:size(24), 3:size(8), 0xFF:size(8), 0:size(1), 1:size(31), 0x01:size(32),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.RstStream(error_code: error.ProtocolError), <<>>)))
}

pub fn parse_rst_stream_truncated_payload_test() {
  // RFC 9113 Section 6.4: Incomplete payload
  let data = <<4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0, 0>>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_rst_stream_with_trailing_data_test() {
  // RFC 9113 Section 6.4: Trailing data from next frame returned
  let data = <<
    4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0x01:size(32), 99,
    99,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(#(frame.RstStream(error_code: error.ProtocolError), <<99, 99>>)),
  )
}

// --- Encode tests ---

pub fn encode_rst_stream_test() {
  // RFC 9113 Section 6.4: RST_STREAM with PROTOCOL_ERROR
  frame.encode_rst_stream(stream_id: 1, error_code: error.ProtocolError)
  |> should.equal(
    Ok(<<
      4:size(24),
      3:size(8),
      0:size(8),
      0:size(1),
      1:size(31),
      0x01:size(32),
    >>),
  )
}

pub fn encode_rst_stream_no_error_test() {
  // RFC 9113 Section 6.4: RST_STREAM with NO_ERROR
  frame.encode_rst_stream(stream_id: 1, error_code: error.NoError)
  |> should.equal(
    Ok(<<
      4:size(24),
      3:size(8),
      0:size(8),
      0:size(1),
      1:size(31),
      0x00:size(32),
    >>),
  )
}

pub fn encode_rst_stream_cancel_test() {
  // RFC 9113 Section 6.4: RST_STREAM with CANCEL
  frame.encode_rst_stream(stream_id: 5, error_code: error.Cancel)
  |> should.equal(
    Ok(<<
      4:size(24),
      3:size(8),
      0:size(8),
      0:size(1),
      5:size(31),
      0x08:size(32),
    >>),
  )
}

pub fn encode_rst_stream_unknown_error_code_test() {
  // RFC 9113 Section 7: Unknown error codes are valid
  frame.encode_rst_stream(
    stream_id: 1,
    error_code: error.UnknownErrorCode(0xFF),
  )
  |> should.equal(
    Ok(<<
      4:size(24),
      3:size(8),
      0:size(8),
      0:size(1),
      1:size(31),
      0xFF:size(32),
    >>),
  )
}

pub fn encode_rst_stream_stream_id_zero_test() {
  // RFC 9113 Section 6.4: RST_STREAM MUST be associated with a stream
  frame.encode_rst_stream(stream_id: 0, error_code: error.ProtocolError)
  |> should.be_error()
}

pub fn encode_rst_stream_roundtrip_test() {
  // Encode then parse should produce the same values
  let assert Ok(encoded) =
    frame.encode_rst_stream(stream_id: 3, error_code: error.Cancel)
  let assert Ok(#(h, rest)) = header.parse_header(encoded)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.RstStream(error_code: error.Cancel), <<>>)))
}
