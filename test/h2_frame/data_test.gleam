import gleam/option.{None, Some}
import gleeunit/should
import h2_frame

pub fn parse_data_test() {
  // RFC 9113 Section 6.1: DATA frame with simple payload
  let data = <<
    5:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8,
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(h2_frame.Data(stream_id: 1, end_stream: False, data: <<"hello":utf8>>)),
  )
}

pub fn parse_data_end_stream_test() {
  // RFC 9113 Section 6.1: END_STREAM (0x01) signals last frame for the stream
  let data = <<
    3:size(24), 0:size(8), 1:size(8), 0:size(1), 1:size(31), "bye":utf8,
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(h2_frame.Data(stream_id: 1, end_stream: True, data: <<"bye":utf8>>)),
  )
}

pub fn parse_data_padded_test() {
  // RFC 9113 Section 6.1: PADDED (0x08) flag indicates padding
  // Payload: pad_length(1 byte) + data + padding
  // pad_length=3, data="hi", padding=0x00 0x00 0x00
  let data = <<
    6:size(24), 0:size(8), 8:size(8), 0:size(1), 1:size(31), 3:size(8),
    "hi":utf8, 0, 0, 0,
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(h2_frame.Data(stream_id: 1, end_stream: False, data: <<"hi":utf8>>)),
  )
}

pub fn parse_data_padded_end_stream_test() {
  // RFC 9113 Section 6.1: Both PADDED (0x08) and END_STREAM (0x01) can be set
  let data = <<
    6:size(24), 0:size(8), 9:size(8), 0:size(1), 1:size(31), 3:size(8),
    "hi":utf8, 0, 0, 0,
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(h2_frame.Data(stream_id: 1, end_stream: True, data: <<"hi":utf8>>)),
  )
}

pub fn parse_data_padded_zero_padding_test() {
  // RFC 9113 Section 6.1: PADDED flag with pad_length=0 is valid
  let data = <<
    4:size(24), 0:size(8), 8:size(8), 0:size(1), 1:size(31), 0:size(8),
    "abc":utf8,
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(h2_frame.Data(stream_id: 1, end_stream: False, data: <<"abc":utf8>>)),
  )
}

pub fn parse_data_stream_id_zero_test() {
  // RFC 9113 Section 6.1: DATA frames MUST be associated with a stream
  // Stream ID 0x00 MUST be treated as connection error PROTOCOL_ERROR
  let data = <<
    5:size(24), 0:size(8), 0:size(8), 0:size(1), 0:size(31), "hello":utf8,
  >>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn parse_data_padded_max_padding_test() {
  // RFC 9113 Section 6.1: pad_length == length - 1 leaves exactly 0 bytes for data
  // length=5, pad_length=4: data_length = 5 - 1 - 4 = 0 (valid)
  let data = <<
    5:size(24), 0:size(8), 8:size(8), 0:size(1), 1:size(31), 4:size(8), 0, 0, 0,
    0,
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(h2_frame.Data(stream_id: 1, end_stream: False, data: <<>>)),
  )
}

pub fn parse_data_padding_exceeds_payload_test() {
  // RFC 9113 Section 6.1: If padding length >= frame payload length,
  // MUST be treated as connection error PROTOCOL_ERROR
  // length=5, pad_length=5 means padding takes all remaining space (no room for data)
  let data = <<
    5:size(24), 0:size(8), 8:size(8), 0:size(1), 1:size(31), 5:size(8), 0, 0, 0,
    0,
  >>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn parse_data_padding_exceeds_payload_larger_test() {
  // RFC 9113 Section 6.1: pad_length greater than remaining payload
  // length=3, pad_length=10 overflows
  let data = <<
    3:size(24), 0:size(8), 8:size(8), 0:size(1), 1:size(31), 10:size(8), 0, 0,
  >>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn parse_data_empty_payload_test() {
  // RFC 9113 Section 6.1: DATA frame with zero-length payload is valid
  let data = <<0:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31)>>
  h2_frame.parse(data)
  |> should.equal(
    Ok(h2_frame.Data(stream_id: 1, end_stream: False, data: <<>>)),
  )
}

pub fn parse_data_unknown_flags_ignored_test() {
  // RFC 9113 Section 4.1: Flags not defined for a frame type MUST be ignored
  // 0xFF has all bits set; only END_STREAM (0x01) and PADDED (0x08) are defined
  // With PADDED set, first byte is pad_length
  let data = <<
    6:size(24), 0:size(8), 0xFF:size(8), 0:size(1), 1:size(31), 3:size(8),
    "hi":utf8, 0, 0, 0,
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(h2_frame.Data(stream_id: 1, end_stream: True, data: <<"hi":utf8>>)),
  )
}

pub fn parse_data_truncated_payload_test() {
  // RFC 9113 Section 6.1: Incomplete payload when frame length doesn't match actual bytes
  // Parser expects exactly one frame worth of bytes; truncated input is MalformedFrame
  let data = <<
    10:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31), "short":utf8,
  >>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_data_with_trailing_data_test() {
  // RFC 9113 Section 6.1: Parser expects exactly one frame worth of bytes
  // Trailing bytes after a complete frame are now considered MalformedFrame
  let data = <<
    5:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8, 99,
    99,
  >>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_data_padded_empty_payload_test() {
  // RFC 9113 Section 6.1: PADDED flag set but no payload bytes at all
  // Parser expects exactly one frame worth of bytes; missing bytes are MalformedFrame
  let data = <<5:size(24), 0:size(8), 8:size(8), 0:size(1), 1:size(31)>>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_data_padded_truncated_payload_test() {
  // RFC 9113 Section 6.1: PADDED frame with insufficient bytes for padding
  // Parser expects exactly one frame worth of bytes; truncated input is MalformedFrame
  // length=10, pad_length=5, but only 3 bytes of data+padding available
  let data = <<
    10:size(24), 0:size(8), 8:size(8), 0:size(1), 1:size(31), 5:size(8), 1, 2, 3,
  >>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

// --- Encode tests ---

pub fn encode_data_test() {
  // RFC 9113 Section 6.1: Basic DATA frame encoding
  h2_frame.encode_data(
    stream_id: 1,
    end_stream: False,
    data: <<"hello":utf8>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<5:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8>>),
  )
}

pub fn encode_data_end_stream_test() {
  // RFC 9113 Section 6.1: END_STREAM (0x01) flag set
  h2_frame.encode_data(
    stream_id: 1,
    end_stream: True,
    data: <<"bye":utf8>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<3:size(24), 0:size(8), 1:size(8), 0:size(1), 1:size(31), "bye":utf8>>),
  )
}

pub fn encode_data_padded_test() {
  // RFC 9113 Section 6.1: PADDED (0x08) flag with 3 bytes of padding
  h2_frame.encode_data(
    stream_id: 1,
    end_stream: False,
    data: <<"hi":utf8>>,
    padding: Some(3),
  )
  |> should.equal(
    Ok(<<
      6:size(24), 0:size(8), 8:size(8), 0:size(1), 1:size(31), 3:size(8),
      "hi":utf8, 0, 0, 0,
    >>),
  )
}

pub fn encode_data_padded_end_stream_test() {
  // RFC 9113 Section 6.1: Both PADDED (0x08) and END_STREAM (0x01)
  h2_frame.encode_data(
    stream_id: 1,
    end_stream: True,
    data: <<"hi":utf8>>,
    padding: Some(3),
  )
  |> should.equal(
    Ok(<<
      6:size(24), 0:size(8), 9:size(8), 0:size(1), 1:size(31), 3:size(8),
      "hi":utf8, 0, 0, 0,
    >>),
  )
}

pub fn encode_data_padded_zero_test() {
  // RFC 9113 Section 6.1: PADDED flag with pad_length=0 is valid
  // Still sets PADDED flag and includes pad_length byte
  h2_frame.encode_data(
    stream_id: 1,
    end_stream: False,
    data: <<"abc":utf8>>,
    padding: Some(0),
  )
  |> should.equal(
    Ok(<<
      4:size(24), 0:size(8), 8:size(8), 0:size(1), 1:size(31), 0:size(8),
      "abc":utf8,
    >>),
  )
}

pub fn encode_data_empty_payload_test() {
  // RFC 9113 Section 6.1: DATA frame with zero-length data is valid
  h2_frame.encode_data(
    stream_id: 1,
    end_stream: False,
    data: <<>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<0:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31)>>),
  )
}

pub fn encode_data_stream_id_zero_test() {
  // RFC 9113 Section 6.1: DATA frames MUST be associated with a stream
  h2_frame.encode_data(
    stream_id: 0,
    end_stream: False,
    data: <<"hello":utf8>>,
    padding: None,
  )
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn encode_data_padding_negative_test() {
  // Padding must be non-negative
  h2_frame.encode_data(
    stream_id: 1,
    end_stream: False,
    data: <<"hello":utf8>>,
    padding: Some(-1),
  )
  |> should.equal(Error(h2_frame.InvalidPadding))
}

pub fn encode_data_padding_exceeds_byte_test() {
  // RFC 9113 Section 6.1: Pad Length is a single 8-bit field; max value is 255
  h2_frame.encode_data(
    stream_id: 1,
    end_stream: False,
    data: <<"hello":utf8>>,
    padding: Some(256),
  )
  |> should.equal(Error(h2_frame.InvalidPadding))
}

pub fn encode_data_roundtrip_test() {
  // Encode then parse should produce the same values
  let assert Ok(encoded) =
    h2_frame.encode_data(
      stream_id: 5,
      end_stream: True,
      data: <<"test":utf8>>,
      padding: None,
    )
  h2_frame.parse(encoded)
  |> should.equal(
    Ok(h2_frame.Data(stream_id: 5, end_stream: True, data: <<"test":utf8>>)),
  )
}

pub fn encode_data_padded_roundtrip_test() {
  // Padded encode then parse should strip padding and recover data
  let assert Ok(encoded) =
    h2_frame.encode_data(
      stream_id: 3,
      end_stream: False,
      data: <<"abc":utf8>>,
      padding: Some(5),
    )
  h2_frame.parse(encoded)
  |> should.equal(
    Ok(h2_frame.Data(stream_id: 3, end_stream: False, data: <<"abc":utf8>>)),
  )
}
