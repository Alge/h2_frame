import gleeunit/should
import h2_frame

pub fn parse_ping_test() {
  // RFC 9113 Section 6.7: PING frame contains 8 octets of opaque data
  let data = <<
    8:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4, 5, 6, 7,
    8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(h2_frame.Ping(ack: False, data: <<1, 2, 3, 4, 5, 6, 7, 8>>)),
  )
}

pub fn parse_ping_ack_test() {
  // RFC 9113 Section 6.7: ACK (0x01) flag indicates a PING response
  let data = <<
    8:size(24), 6:size(8), 1:size(8), 0:size(1), 0:size(31), 0, 0, 0, 0, 0, 0, 0,
    0,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(h2_frame.Ping(ack: True, data: <<0, 0, 0, 0, 0, 0, 0, 0>>)),
  )
}

pub fn parse_ping_wrong_length_test() {
  // RFC 9113 Section 6.7: Length other than 8 MUST be treated as FRAME_SIZE_ERROR
  let data = <<
    4:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.FrameSizeError)))
}

pub fn parse_ping_nonzero_stream_id_test() {
  // RFC 9113 Section 6.7: Stream ID other than 0x00 MUST be treated as PROTOCOL_ERROR
  let data = <<
    8:size(24), 6:size(8), 0:size(8), 0:size(1), 1:size(31), 0, 0, 0, 0, 0, 0, 0,
    0,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn parse_ping_unknown_flags_ignored_test() {
  // RFC 9113 Section 4.1: Flags not defined for a frame type MUST be ignored
  let data = <<
    8:size(24), 6:size(8), 3:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4, 5, 6, 7,
    8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(h2_frame.Ping(ack: True, data: <<1, 2, 3, 4, 5, 6, 7, 8>>)),
  )
}

pub fn parse_ping_unknown_flags_no_ack_test() {
  // RFC 9113 Section 4.1: Unknown flags ignored; ACK bit not set means ack=False
  let data = <<
    8:size(24), 6:size(8), 2:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4, 5, 6, 7,
    8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(h2_frame.Ping(ack: False, data: <<1, 2, 3, 4, 5, 6, 7, 8>>)),
  )
}

pub fn parse_ping_truncated_payload_test() {
  // RFC 9113 Section 6.7: Truncated payload treated as malformed frame
  let data = <<
    8:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_ping_with_trailing_data_test() {
  // RFC 9113 Section 6.7: Trailing data treated as malformed frame
  let data = <<
    8:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4, 5, 6, 7,
    8, 99, 99,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

// --- Encode tests ---

pub fn encode_ping_test() {
  h2_frame.encode_ping(ack: False, data: <<1, 2, 3, 4, 5, 6, 7, 8>>)
  |> should.equal(
    Ok(<<
      8:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4, 5, 6,
      7, 8,
    >>),
  )
}

pub fn encode_ping_ack_test() {
  h2_frame.encode_ping(ack: True, data: <<1, 2, 3, 4, 5, 6, 7, 8>>)
  |> should.equal(
    Ok(<<
      8:size(24), 6:size(8), 1:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4, 5, 6,
      7, 8,
    >>),
  )
}

pub fn encode_ping_zero_data_test() {
  h2_frame.encode_ping(ack: False, data: <<0, 0, 0, 0, 0, 0, 0, 0>>)
  |> should.equal(
    Ok(<<
      8:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31), 0, 0, 0, 0, 0, 0,
      0, 0,
    >>),
  )
}

pub fn encode_ping_wrong_data_length_short_test() {
  // RFC 9113 Section 6.7: Length other than 8 MUST be treated as FRAME_SIZE_ERROR
  h2_frame.encode_ping(ack: False, data: <<1, 2, 3, 4>>)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.FrameSizeError)))
}

pub fn encode_ping_wrong_data_length_long_test() {
  // RFC 9113 Section 6.7: Length other than 8 MUST be treated as FRAME_SIZE_ERROR
  h2_frame.encode_ping(ack: False, data: <<1, 2, 3, 4, 5, 6, 7, 8, 9>>)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.FrameSizeError)))
}

pub fn encode_ping_roundtrip_test() {
  let assert Ok(encoded) =
    h2_frame.encode_ping(ack: False, data: <<10, 20, 30, 40, 50, 60, 70, 80>>)
  h2_frame.decode_frame(encoded)
  |> should.equal(
    Ok(h2_frame.Ping(ack: False, data: <<10, 20, 30, 40, 50, 60, 70, 80>>)),
  )
}
