import gleeunit/should
import h2_frame

pub fn parse_rst_stream_test() {
  // RFC 9113 Section 6.4: RST_STREAM with PROTOCOL_ERROR
  let data = <<
    4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0x01:size(32),
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(h2_frame.RstStream(stream_id: 1, error_code: h2_frame.ProtocolError)),
  )
}

pub fn parse_rst_stream_no_error_test() {
  // RFC 9113 Section 6.4: RST_STREAM with NO_ERROR
  let data = <<
    4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0x00:size(32),
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(h2_frame.RstStream(stream_id: 1, error_code: h2_frame.NoError)),
  )
}

pub fn parse_rst_stream_cancel_test() {
  // RFC 9113 Section 6.4: RST_STREAM with CANCEL
  let data = <<
    4:size(24), 3:size(8), 0:size(8), 0:size(1), 5:size(31), 0x08:size(32),
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(h2_frame.RstStream(stream_id: 5, error_code: h2_frame.Cancel)),
  )
}

pub fn parse_rst_stream_unknown_error_code_test() {
  // RFC 9113 Section 7: Unknown error codes MUST NOT trigger special behavior
  let data = <<
    4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0xFF:size(32),
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(h2_frame.RstStream(
      stream_id: 1,
      error_code: h2_frame.UnknownErrorCode(0xFF),
    )),
  )
}

pub fn parse_rst_stream_stream_id_zero_test() {
  // RFC 9113 Section 6.4: Stream ID 0x00 MUST be treated as connection error PROTOCOL_ERROR
  let data = <<
    4:size(24), 3:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(32),
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn parse_rst_stream_wrong_length_short_test() {
  // RFC 9113 Section 6.4: Length other than 4 MUST be treated as connection error FRAME_SIZE_ERROR
  let data = <<
    3:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0, 0, 0,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.FrameSizeError)))
}

pub fn parse_rst_stream_wrong_length_long_test() {
  // RFC 9113 Section 6.4: Length greater than 4 is also FRAME_SIZE_ERROR
  let data = <<
    5:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0x01:size(32), 0,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.FrameSizeError)))
}

pub fn parse_rst_stream_unknown_flags_ignored_test() {
  // RFC 9113 Section 6.4: No flags defined; all flags MUST be ignored
  let data = <<
    4:size(24), 3:size(8), 0xFF:size(8), 0:size(1), 1:size(31), 0x01:size(32),
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(h2_frame.RstStream(stream_id: 1, error_code: h2_frame.ProtocolError)),
  )
}

pub fn parse_rst_stream_truncated_payload_test() {
  // RFC 9113 Section 6.4: Incomplete payload (parse expects exact frame bytes)
  let data = <<4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0, 0>>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_rst_stream_with_trailing_data_test() {
  // RFC 9113 Section 6.4: Trailing data causes MalformedFrame error (parse expects exact frame bytes)
  let data = <<
    4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0x01:size(32), 99,
    99,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

// --- Encode tests ---

pub fn encode_rst_stream_test() {
  h2_frame.encode_rst_stream(stream_id: 1, error_code: h2_frame.ProtocolError)
  |> should.equal(
    Ok(<<
      4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0x01:size(32),
    >>),
  )
}

pub fn encode_rst_stream_no_error_test() {
  h2_frame.encode_rst_stream(stream_id: 1, error_code: h2_frame.NoError)
  |> should.equal(
    Ok(<<
      4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0x00:size(32),
    >>),
  )
}

pub fn encode_rst_stream_cancel_test() {
  h2_frame.encode_rst_stream(stream_id: 5, error_code: h2_frame.Cancel)
  |> should.equal(
    Ok(<<
      4:size(24), 3:size(8), 0:size(8), 0:size(1), 5:size(31), 0x08:size(32),
    >>),
  )
}

pub fn encode_rst_stream_unknown_error_code_test() {
  h2_frame.encode_rst_stream(
    stream_id: 1,
    error_code: h2_frame.UnknownErrorCode(0xFF),
  )
  |> should.equal(
    Ok(<<
      4:size(24), 3:size(8), 0:size(8), 0:size(1), 1:size(31), 0xFF:size(32),
    >>),
  )
}

pub fn encode_rst_stream_stream_id_zero_test() {
  h2_frame.encode_rst_stream(stream_id: 0, error_code: h2_frame.ProtocolError)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn encode_rst_stream_roundtrip_test() {
  let assert Ok(encoded) =
    h2_frame.encode_rst_stream(stream_id: 3, error_code: h2_frame.Cancel)
  h2_frame.decode_frame(encoded)
  |> should.equal(
    Ok(h2_frame.RstStream(stream_id: 3, error_code: h2_frame.Cancel)),
  )
}
