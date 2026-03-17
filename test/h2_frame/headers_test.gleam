import gleam/option.{None, Some}
import gleeunit/should
import h2_frame

pub fn parse_headers_test() {
  // RFC 9113 Section 6.2: Basic HEADERS frame with fragment only
  let data = <<
    5:size(24), 1:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 1,
        end_stream: False,
        end_headers: False,
        priority: None,
        field_block_fragment: <<"hello":utf8>>,
      ),
    ),
  )
}

pub fn parse_headers_end_stream_test() {
  // RFC 9113 Section 6.2: END_STREAM (0x01) flag
  let data = <<
    3:size(24), 1:size(8), 1:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 1,
        end_stream: True,
        end_headers: False,
        priority: None,
        field_block_fragment: <<"abc":utf8>>,
      ),
    ),
  )
}

pub fn parse_headers_end_headers_test() {
  // RFC 9113 Section 6.2: END_HEADERS (0x04) flag
  let data = <<
    3:size(24), 1:size(8), 4:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 1,
        end_stream: False,
        end_headers: True,
        priority: None,
        field_block_fragment: <<"abc":utf8>>,
      ),
    ),
  )
}

pub fn parse_headers_end_stream_and_end_headers_test() {
  // RFC 9113 Section 6.2: Both END_STREAM (0x01) and END_HEADERS (0x04)
  let data = <<
    3:size(24), 1:size(8), 5:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 1,
        end_stream: True,
        end_headers: True,
        priority: None,
        field_block_fragment: <<"abc":utf8>>,
      ),
    ),
  )
}

pub fn parse_headers_priority_test() {
  // RFC 9113 Section 6.2: PRIORITY (0x20) flag adds 5 bytes
  // exclusive=0, stream_dependency=3, weight=15, fragment="ab"
  let data = <<
    7:size(24), 1:size(8), 0x20:size(8), 0:size(1), 1:size(31), 0:size(1),
    3:size(31), 15:size(8), "ab":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 1,
        end_stream: False,
        end_headers: False,
        priority: Some(h2_frame.StreamPriority(
          exclusive: False,
          stream_dependency: 3,
          weight: 15,
        )),
        field_block_fragment: <<"ab":utf8>>,
      ),
    ),
  )
}

pub fn parse_headers_priority_exclusive_test() {
  // RFC 9113 Section 6.2: PRIORITY with exclusive bit set
  let data = <<
    7:size(24), 1:size(8), 0x20:size(8), 0:size(1), 1:size(31), 1:size(1),
    5:size(31), 255:size(8), "ab":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 1,
        end_stream: False,
        end_headers: False,
        priority: Some(h2_frame.StreamPriority(
          exclusive: True,
          stream_dependency: 5,
          weight: 255,
        )),
        field_block_fragment: <<"ab":utf8>>,
      ),
    ),
  )
}

pub fn parse_headers_padded_test() {
  // RFC 9113 Section 6.2: PADDED (0x08) flag
  // pad_length=2, fragment="abc", padding=0x00 0x00
  let data = <<
    6:size(24), 1:size(8), 8:size(8), 0:size(1), 1:size(31), 2:size(8),
    "abc":utf8, 0, 0,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 1,
        end_stream: False,
        end_headers: False,
        priority: None,
        field_block_fragment: <<"abc":utf8>>,
      ),
    ),
  )
}

pub fn parse_headers_padded_and_priority_test() {
  // RFC 9113 Section 6.2: Both PADDED (0x08) and PRIORITY (0x20)
  // Payload: pad_length + exclusive/dep/weight + fragment + padding
  // pad_length=2, exclusive=1, dep=7, weight=100, fragment="ab", padding=0x00 0x00
  let data = <<
    10:size(24), 1:size(8), 0x28:size(8), 0:size(1), 1:size(31), 2:size(8),
    1:size(1), 7:size(31), 100:size(8), "ab":utf8, 0, 0,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 1,
        end_stream: False,
        end_headers: False,
        priority: Some(h2_frame.StreamPriority(
          exclusive: True,
          stream_dependency: 7,
          weight: 100,
        )),
        field_block_fragment: <<"ab":utf8>>,
      ),
    ),
  )
}

pub fn parse_headers_all_flags_test() {
  // RFC 9113 Section 6.2: All defined flags set (END_STREAM|END_HEADERS|PADDED|PRIORITY = 0x2D)
  // pad_length=1, exclusive=0, dep=0, weight=0, fragment="x", padding=0x00
  let data = <<
    8:size(24), 1:size(8), 0x2D:size(8), 0:size(1), 1:size(31), 1:size(8),
    0:size(1), 0:size(31), 0:size(8), "x":utf8, 0,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 1,
        end_stream: True,
        end_headers: True,
        priority: Some(h2_frame.StreamPriority(
          exclusive: False,
          stream_dependency: 0,
          weight: 0,
        )),
        field_block_fragment: <<"x":utf8>>,
      ),
    ),
  )
}

pub fn parse_headers_stream_id_zero_test() {
  // RFC 9113 Section 6.2: Stream ID 0x00 MUST be treated as connection error PROTOCOL_ERROR
  let data = <<
    3:size(24), 1:size(8), 0:size(8), 0:size(1), 0:size(31), "abc":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn parse_headers_padding_exceeds_payload_test() {
  // RFC 9113 Section 6.2: Padding length >= payload length is PROTOCOL_ERROR
  // length=3, pad_length=3 leaves no room for fragment
  let data = <<
    3:size(24), 1:size(8), 8:size(8), 0:size(1), 1:size(31), 3:size(8), 0, 0,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn parse_headers_padded_priority_padding_exceeds_test() {
  // RFC 9113 Section 6.2: With PADDED+PRIORITY, padding must account for priority fields too
  // length=7, pad_length=2, priority=5 bytes, that leaves 7-1-5-2 = -1 for fragment
  let data = <<
    7:size(24), 1:size(8), 0x28:size(8), 0:size(1), 1:size(31), 2:size(8),
    0:size(1), 0:size(31), 0:size(8), 0,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn parse_headers_priority_truncated_test() {
  // RFC 9113 Section 6.2: PRIORITY flag set but not enough bytes for priority fields (malformed frame)
  // length=3 but priority needs 5 bytes
  let data = <<
    3:size(24), 1:size(8), 0x20:size(8), 0:size(1), 1:size(31), 0, 0, 0,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_headers_empty_fragment_test() {
  // RFC 9113 Section 6.2: HEADERS frame with empty fragment is valid
  let data = <<0:size(24), 1:size(8), 0:size(8), 0:size(1), 1:size(31)>>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 1,
        end_stream: False,
        end_headers: False,
        priority: None,
        field_block_fragment: <<>>,
      ),
    ),
  )
}

pub fn parse_headers_unknown_flags_ignored_test() {
  // RFC 9113 Section 4.1: Unknown flags MUST be ignored
  // 0xD2 has undefined bits set, no defined flags active
  let data = <<
    3:size(24), 1:size(8), 0xD2:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 1,
        end_stream: False,
        end_headers: False,
        priority: None,
        field_block_fragment: <<"abc":utf8>>,
      ),
    ),
  )
}

pub fn parse_headers_truncated_payload_test() {
  // RFC 9113 Section 6.2: Incomplete payload (malformed frame)
  let data = <<
    10:size(24), 1:size(8), 0:size(8), 0:size(1), 1:size(31), "short":utf8,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_headers_with_trailing_data_test() {
  // RFC 9113 Section 6.2: Trailing data is now malformed (parse expects exactly one frame)
  let data = <<
    3:size(24), 1:size(8), 0:size(8), 0:size(1), 1:size(31), "abc":utf8, 99, 99,
  >>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_headers_padded_empty_payload_test() {
  // RFC 9113 Section 6.2: PADDED flag set but no payload bytes at all (malformed frame)
  let data = <<5:size(24), 1:size(8), 8:size(8), 0:size(1), 1:size(31)>>
  h2_frame.decode_frame(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

// --- Encode tests ---

pub fn encode_headers_test() {
  // RFC 9113 Section 6.2: Basic HEADERS frame with fragment only
  h2_frame.encode_headers(
    stream_id: 1,
    end_stream: False,
    end_headers: False,
    priority: None,
    field_block_fragment: <<"hello":utf8>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<5:size(24), 1:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8>>),
  )
}

pub fn encode_headers_end_stream_test() {
  // RFC 9113 Section 6.2: END_STREAM (0x01) flag
  h2_frame.encode_headers(
    stream_id: 1,
    end_stream: True,
    end_headers: False,
    priority: None,
    field_block_fragment: <<"abc":utf8>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<3:size(24), 1:size(8), 1:size(8), 0:size(1), 1:size(31), "abc":utf8>>),
  )
}

pub fn encode_headers_end_headers_test() {
  // RFC 9113 Section 6.2: END_HEADERS (0x04) flag
  h2_frame.encode_headers(
    stream_id: 1,
    end_stream: False,
    end_headers: True,
    priority: None,
    field_block_fragment: <<"abc":utf8>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<3:size(24), 1:size(8), 4:size(8), 0:size(1), 1:size(31), "abc":utf8>>),
  )
}

pub fn encode_headers_end_stream_and_end_headers_test() {
  // RFC 9113 Section 6.2: Both END_STREAM (0x01) and END_HEADERS (0x04)
  h2_frame.encode_headers(
    stream_id: 1,
    end_stream: True,
    end_headers: True,
    priority: None,
    field_block_fragment: <<"abc":utf8>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<3:size(24), 1:size(8), 5:size(8), 0:size(1), 1:size(31), "abc":utf8>>),
  )
}

pub fn encode_headers_priority_test() {
  // RFC 9113 Section 6.2: PRIORITY (0x20) flag adds 5 bytes
  h2_frame.encode_headers(
    stream_id: 1,
    end_stream: False,
    end_headers: False,
    priority: Some(h2_frame.StreamPriority(
      exclusive: False,
      stream_dependency: 3,
      weight: 15,
    )),
    field_block_fragment: <<"ab":utf8>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<
      7:size(24), 1:size(8), 0x20:size(8), 0:size(1), 1:size(31), 0:size(1),
      3:size(31), 15:size(8), "ab":utf8,
    >>),
  )
}

pub fn encode_headers_priority_exclusive_test() {
  // RFC 9113 Section 6.2: PRIORITY with exclusive bit set
  h2_frame.encode_headers(
    stream_id: 1,
    end_stream: False,
    end_headers: False,
    priority: Some(h2_frame.StreamPriority(
      exclusive: True,
      stream_dependency: 5,
      weight: 255,
    )),
    field_block_fragment: <<"ab":utf8>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<
      7:size(24), 1:size(8), 0x20:size(8), 0:size(1), 1:size(31), 1:size(1),
      5:size(31), 255:size(8), "ab":utf8,
    >>),
  )
}

pub fn encode_headers_padded_test() {
  // RFC 9113 Section 6.2: PADDED (0x08) flag
  h2_frame.encode_headers(
    stream_id: 1,
    end_stream: False,
    end_headers: False,
    priority: None,
    field_block_fragment: <<"abc":utf8>>,
    padding: Some(2),
  )
  |> should.equal(
    Ok(<<
      6:size(24), 1:size(8), 8:size(8), 0:size(1), 1:size(31), 2:size(8),
      "abc":utf8, 0, 0,
    >>),
  )
}

pub fn encode_headers_padded_and_priority_test() {
  // RFC 9113 Section 6.2: Both PADDED (0x08) and PRIORITY (0x20)
  h2_frame.encode_headers(
    stream_id: 1,
    end_stream: False,
    end_headers: False,
    priority: Some(h2_frame.StreamPriority(
      exclusive: True,
      stream_dependency: 7,
      weight: 100,
    )),
    field_block_fragment: <<"ab":utf8>>,
    padding: Some(2),
  )
  |> should.equal(
    Ok(<<
      10:size(24), 1:size(8), 0x28:size(8), 0:size(1), 1:size(31), 2:size(8),
      1:size(1), 7:size(31), 100:size(8), "ab":utf8, 0, 0,
    >>),
  )
}

pub fn encode_headers_all_flags_test() {
  // RFC 9113 Section 6.2: All defined flags (END_STREAM|END_HEADERS|PADDED|PRIORITY = 0x2D)
  h2_frame.encode_headers(
    stream_id: 1,
    end_stream: True,
    end_headers: True,
    priority: Some(h2_frame.StreamPriority(
      exclusive: False,
      stream_dependency: 0,
      weight: 0,
    )),
    field_block_fragment: <<"x":utf8>>,
    padding: Some(1),
  )
  |> should.equal(
    Ok(<<
      8:size(24), 1:size(8), 0x2D:size(8), 0:size(1), 1:size(31), 1:size(8),
      0:size(1), 0:size(31), 0:size(8), "x":utf8, 0,
    >>),
  )
}

pub fn encode_headers_empty_fragment_test() {
  // RFC 9113 Section 6.2: HEADERS frame with empty fragment is valid
  h2_frame.encode_headers(
    stream_id: 1,
    end_stream: False,
    end_headers: False,
    priority: None,
    field_block_fragment: <<>>,
    padding: None,
  )
  |> should.equal(
    Ok(<<0:size(24), 1:size(8), 0:size(8), 0:size(1), 1:size(31)>>),
  )
}

pub fn encode_headers_stream_id_zero_test() {
  // RFC 9113 Section 6.2: Stream ID 0x00 MUST be treated as connection error PROTOCOL_ERROR
  h2_frame.encode_headers(
    stream_id: 0,
    end_stream: False,
    end_headers: False,
    priority: None,
    field_block_fragment: <<"abc":utf8>>,
    padding: None,
  )
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn encode_headers_padding_negative_test() {
  // Padding must be non-negative
  h2_frame.encode_headers(
    stream_id: 1,
    end_stream: False,
    end_headers: False,
    priority: None,
    field_block_fragment: <<"abc":utf8>>,
    padding: Some(-1),
  )
  |> should.equal(Error(h2_frame.InvalidPadding))
}

pub fn encode_headers_padding_exceeds_byte_test() {
  // RFC 9113 Section 6.2: Pad Length is a single 8-bit field; max value is 255
  h2_frame.encode_headers(
    stream_id: 1,
    end_stream: False,
    end_headers: False,
    priority: None,
    field_block_fragment: <<"abc":utf8>>,
    padding: Some(256),
  )
  |> should.equal(Error(h2_frame.InvalidPadding))
}

pub fn encode_headers_roundtrip_test() {
  // Encode then parse should produce the same values
  let assert Ok(encoded) =
    h2_frame.encode_headers(
      stream_id: 5,
      end_stream: True,
      end_headers: True,
      priority: None,
      field_block_fragment: <<"test":utf8>>,
      padding: None,
    )
  h2_frame.decode_frame(encoded)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 5,
        end_stream: True,
        end_headers: True,
        priority: None,
        field_block_fragment: <<"test":utf8>>,
      ),
    ),
  )
}

pub fn encode_headers_padded_priority_roundtrip_test() {
  // Padded + priority encode then parse should recover all fields
  let assert Ok(encoded) =
    h2_frame.encode_headers(
      stream_id: 3,
      end_stream: False,
      end_headers: True,
      priority: Some(h2_frame.StreamPriority(
        exclusive: True,
        stream_dependency: 10,
        weight: 42,
      )),
      field_block_fragment: <<"hpack":utf8>>,
      padding: Some(4),
    )
  h2_frame.decode_frame(encoded)
  |> should.equal(
    Ok(
      h2_frame.Headers(
        stream_id: 3,
        end_stream: False,
        end_headers: True,
        priority: Some(h2_frame.StreamPriority(
          exclusive: True,
          stream_dependency: 10,
          weight: 42,
        )),
        field_block_fragment: <<"hpack":utf8>>,
      ),
    ),
  )
}
