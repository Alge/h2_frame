import gleeunit/should
import h2_frame

pub fn parse_unknown_frame_test() {
  // RFC 9113 Section 4.1: Unknown frame types MUST be ignored
  // Frame type 0xFF with some payload
  let data = <<
    5:size(24), 0xFF:size(8), 0:size(8), 0:size(1), 0:size(31), "hello":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Unknown(stream_id: 0, frame_type: 0xFF, flags: 0, data: <<
        "hello":utf8,
      >>),
    ),
  )
}

pub fn parse_unknown_frame_with_stream_id_test() {
  // RFC 9113 Section 4.1: Unknown frames can have any stream ID
  let data = <<
    3:size(24), 0x0A:size(8), 0:size(8), 0:size(1), 5:size(31), "abc":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Unknown(stream_id: 5, frame_type: 0x0A, flags: 0, data: <<
        "abc":utf8,
      >>),
    ),
  )
}

pub fn parse_unknown_frame_with_flags_test() {
  // RFC 9113 Section 4.1: Unknown frame flags are preserved but ignored
  let data = <<
    3:size(24), 0x0B:size(8), 0xFF:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Unknown(stream_id: 1, frame_type: 0x0B, flags: 0xFF, data: <<
        "abc":utf8,
      >>),
    ),
  )
}

pub fn parse_unknown_frame_empty_payload_test() {
  // RFC 9113 Section 4.1: Unknown frame with zero-length payload
  let data = <<0:size(24), 0x0C:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(h2_frame.Unknown(stream_id: 0, frame_type: 0x0C, flags: 0, data: <<>>)),
  )
}

pub fn parse_unknown_frame_truncated_payload_test() {
  // RFC 9113 Section 4.1: Incomplete payload - parse expects exactly one frame's worth of bytes
  let data = <<
    10:size(24), 0x0D:size(8), 0:size(8), 0:size(1), 0:size(31), "short":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_unknown_frame_with_trailing_data_test() {
  // RFC 9113 Section 4.1: Trailing data - parse no longer accepts trailing bytes
  let data = <<
    3:size(24), 0x0E:size(8), 0:size(8), 0:size(1), 0:size(31), "abc":utf8, 99,
    99,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_unknown_frame_truncated_header_test() {
  // RFC 9113 Section 4.1: Less than 9 bytes means incomplete header - parse expects exactly one frame's worth of bytes
  let data = <<5:size(24), 0xFF:size(8), 0:size(8), 0:size(1)>>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_unknown_frame_empty_input_test() {
  // RFC 9113 Section 4.1: Empty input - parse expects exactly one frame's worth of bytes
  h2_frame.decode_frame(<<>>)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_unknown_frame_reserved_bit_ignored_test() {
  // RFC 9113 Section 4.1: Reserved bit (R) MUST be ignored when receiving
  // Set the reserved bit to 1; stream_id should still be parsed correctly
  let data = <<
    3:size(24), 0x0F:size(8), 0:size(8), 1:size(1), 1:size(31), "abc":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Unknown(stream_id: 1, frame_type: 0x0F, flags: 0, data: <<
        "abc":utf8,
      >>),
    ),
  )
}

pub fn parse_unknown_frame_max_stream_id_test() {
  // RFC 9113 Section 4.1: Maximum stream ID is 2^31-1
  let data = <<
    0:size(24), 0x0F:size(8), 0:size(8), 0:size(1), 2_147_483_647:size(31),
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Unknown(
        stream_id: 2_147_483_647,
        frame_type: 0x0F,
        flags: 0,
        data: <<>>,
      ),
    ),
  )
}

// --- Encode tests ---

pub fn encode_unknown_frame_test() {
  // RFC 9113 Section 4.1: Encode an unknown frame type
  h2_frame.encode_unknown(frame_type_code: 0xFF, stream_id: 0, flags: 0, data: <<
    "hello":utf8,
  >>)
  |> should.equal(<<
    5:size(24), 0xFF:size(8), 0:size(8), 0:size(1), 0:size(31), "hello":utf8,
  >>)
}

pub fn encode_unknown_frame_with_stream_id_test() {
  // RFC 9113 Section 4.1: Unknown frames can have any stream ID
  h2_frame.encode_unknown(frame_type_code: 0x0A, stream_id: 5, flags: 0, data: <<
    "abc":utf8,
  >>)
  |> should.equal(<<
    3:size(24), 0x0A:size(8), 0:size(8), 0:size(1), 5:size(31), "abc":utf8,
  >>)
}

pub fn encode_unknown_frame_with_flags_test() {
  // RFC 9113 Section 4.1: Unknown frames can carry arbitrary flags
  h2_frame.encode_unknown(
    frame_type_code: 0x0B,
    stream_id: 1,
    flags: 0xFF,
    data: <<"abc":utf8>>,
  )
  |> should.equal(<<
    3:size(24), 0x0B:size(8), 0xFF:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>)
}

pub fn encode_unknown_frame_empty_payload_test() {
  // RFC 9113 Section 4.1: Unknown frame with zero-length payload
  h2_frame.encode_unknown(
    frame_type_code: 0x0C,
    stream_id: 0,
    flags: 0,
    data: <<>>,
  )
  |> should.equal(<<0:size(24), 0x0C:size(8), 0:size(8), 0:size(1), 0:size(31)>>)
}

pub fn encode_unknown_frame_with_stream_id_and_flags_test() {
  // RFC 9113 Section 4.1: Encode with both stream_id and flags set
  h2_frame.encode_unknown(
    frame_type_code: 0x0B,
    stream_id: 42,
    flags: 0xAB,
    data: <<"xy":utf8>>,
  )
  |> should.equal(<<
    2:size(24), 0x0B:size(8), 0xAB:size(8), 0:size(1), 42:size(31), "xy":utf8,
  >>)
}

pub fn encode_unknown_frame_reserved_bit_zero_test() {
  // RFC 9113 Section 4.1: Reserved bit MUST be 0 when sending
  let encoded =
    h2_frame.encode_unknown(
      frame_type_code: 0x0F,
      stream_id: 1,
      flags: 0,
      data: <<>>,
    )
  // Extract the reserved bit (bit 72, first bit of byte 9)
  let assert <<_:bytes-size(5), reserved:1, _:bits>> = encoded
  reserved |> should.equal(0)
}

pub fn encode_unknown_frame_roundtrip_test() {
  // Encode then parse should produce the same values
  let encoded =
    h2_frame.encode_unknown(
      frame_type_code: 0x0E,
      stream_id: 0,
      flags: 0,
      data: <<"test":utf8>>,
    )
  h2_frame.decode_frame(encoded)
  |> should.equal(
    Ok(
      h2_frame.Unknown(stream_id: 0, frame_type: 0x0E, flags: 0, data: <<
        "test":utf8,
      >>),
    ),
  )
}

pub fn encode_unknown_frame_roundtrip_with_flags_test() {
  // Roundtrip with flags set should preserve flag values
  let encoded =
    h2_frame.encode_unknown(
      frame_type_code: 0x0B,
      stream_id: 7,
      flags: 0xAB,
      data: <<"hello":utf8>>,
    )
  h2_frame.decode_frame(encoded)
  |> should.equal(
    Ok(
      h2_frame.Unknown(stream_id: 7, frame_type: 0x0B, flags: 0xAB, data: <<
        "hello":utf8,
      >>),
    ),
  )
}
