import gleeunit/should
import h2o/frame
import h2o/frame/error
import h2o/frame/header

pub fn parse_priority_test() {
  // RFC 9113 Section 6.3: Basic PRIORITY frame
  // exclusive=0, stream_dependency=3, weight=15
  let data = <<
    5:size(24), 2:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    3:size(31), 15:size(8),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        frame.Priority(exclusive: False, stream_dependency: 3, weight: 15),
        <<>>,
      ),
    ),
  )
}

pub fn parse_priority_exclusive_test() {
  // RFC 9113 Section 6.3: Exclusive bit set
  let data = <<
    5:size(24), 2:size(8), 0:size(8), 0:size(1), 1:size(31), 1:size(1),
    5:size(31), 255:size(8),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        frame.Priority(exclusive: True, stream_dependency: 5, weight: 255),
        <<>>,
      ),
    ),
  )
}

pub fn parse_priority_zero_weight_test() {
  // RFC 9113 Section 6.3: Weight=0 is valid (weight range is 0-255)
  let data = <<
    5:size(24), 2:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    0:size(31), 0:size(8),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(frame.Priority(exclusive: False, stream_dependency: 0, weight: 0), <<>>),
    ),
  )
}

pub fn parse_priority_stream_id_zero_test() {
  // RFC 9113 Section 6.3: Stream ID 0x00 MUST be treated as connection error PROTOCOL_ERROR
  let data = <<
    5:size(24), 2:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    3:size(31), 15:size(8),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_priority_wrong_length_test() {
  // RFC 9113 Section 6.3: Length other than 5 MUST be treated as stream error FRAME_SIZE_ERROR
  // Note: For a parser library we treat this as a connection error since we have no stream context
  let data = <<
    4:size(24), 2:size(8), 0:size(8), 0:size(1), 1:size(31), 0, 0, 0, 0,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.ConnectionError(error.FrameSizeError)))
}

pub fn parse_priority_too_long_test() {
  // RFC 9113 Section 6.3: Length greater than 5 is also FRAME_SIZE_ERROR
  let data = <<
    6:size(24), 2:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    3:size(31), 15:size(8), 0,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.ConnectionError(error.FrameSizeError)))
}

pub fn parse_priority_unknown_flags_ignored_test() {
  // RFC 9113 Section 6.3: No flags defined; all flags MUST be ignored
  let data = <<
    5:size(24), 2:size(8), 0xFF:size(8), 0:size(1), 1:size(31), 0:size(1),
    3:size(31), 15:size(8),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        frame.Priority(exclusive: False, stream_dependency: 3, weight: 15),
        <<>>,
      ),
    ),
  )
}

pub fn parse_priority_truncated_payload_test() {
  // RFC 9113 Section 6.3: Incomplete payload
  let data = <<
    5:size(24), 2:size(8), 0:size(8), 0:size(1), 1:size(31), 0, 0, 0,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_priority_with_trailing_data_test() {
  // RFC 9113 Section 6.3: Trailing data from next frame returned
  let data = <<
    5:size(24), 2:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    3:size(31), 15:size(8), 99, 99,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(frame.Priority(exclusive: False, stream_dependency: 3, weight: 15), <<
        99,
        99,
      >>),
    ),
  )
}

// --- Encode tests ---

pub fn encode_priority_test() {
  // RFC 9113 Section 6.3: Basic PRIORITY frame encoding
  frame.encode_priority(
    stream_id: 1,
    exclusive: False,
    stream_dependency: 3,
    weight: 15,
  )
  |> should.equal(
    Ok(<<
      5:size(24), 2:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
      3:size(31), 15:size(8),
    >>),
  )
}

pub fn encode_priority_exclusive_test() {
  // RFC 9113 Section 6.3: Exclusive bit set
  frame.encode_priority(
    stream_id: 1,
    exclusive: True,
    stream_dependency: 5,
    weight: 255,
  )
  |> should.equal(
    Ok(<<
      5:size(24), 2:size(8), 0:size(8), 0:size(1), 1:size(31), 1:size(1),
      5:size(31), 255:size(8),
    >>),
  )
}

pub fn encode_priority_zero_weight_test() {
  // RFC 9113 Section 6.3: Weight=0 is valid
  frame.encode_priority(
    stream_id: 1,
    exclusive: False,
    stream_dependency: 0,
    weight: 0,
  )
  |> should.equal(
    Ok(<<
      5:size(24), 2:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
      0:size(31), 0:size(8),
    >>),
  )
}

pub fn encode_priority_stream_id_zero_test() {
  // RFC 9113 Section 6.3: PRIORITY frames MUST be associated with a stream
  frame.encode_priority(
    stream_id: 0,
    exclusive: False,
    stream_dependency: 3,
    weight: 15,
  )
  |> should.be_error()
}

pub fn encode_priority_roundtrip_test() {
  // Encode then parse should produce the same values
  let assert Ok(encoded) =
    frame.encode_priority(
      stream_id: 7,
      exclusive: True,
      stream_dependency: 10,
      weight: 42,
    )
  let assert Ok(#(h, rest)) = header.parse_header(encoded)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        frame.Priority(exclusive: True, stream_dependency: 10, weight: 42),
        <<>>,
      ),
    ),
  )
}
