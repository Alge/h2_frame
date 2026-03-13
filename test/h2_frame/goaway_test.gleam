import gleeunit/should
import h2_frame

pub fn parse_goaway_test() {
  // RFC 9113 Section 6.8: Basic GOAWAY frame with no debug data
  // last_stream_id=1, error_code=NO_ERROR
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0x00:size(32),
  >>
  let assert Ok(#(h, rest)) = h2_frame.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.GoAway(
          last_stream_id: 1,
          error_code: h2_frame.NoError,
          debug_data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_with_error_test() {
  // RFC 9113 Section 6.8: GOAWAY with PROTOCOL_ERROR
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    5:size(31), 0x01:size(32),
  >>
  let assert Ok(#(h, rest)) = h2_frame.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.GoAway(
          last_stream_id: 5,
          error_code: h2_frame.ProtocolError,
          debug_data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_with_debug_data_test() {
  // RFC 9113 Section 6.8: GOAWAY with additional debug data
  let data = <<
    13:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0x00:size(32), "hello":utf8,
  >>
  let assert Ok(#(h, rest)) = h2_frame.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.GoAway(
          last_stream_id: 1,
          error_code: h2_frame.NoError,
          debug_data: <<
            "hello":utf8,
          >>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_zero_last_stream_id_test() {
  // RFC 9113 Section 6.8: last_stream_id=0 means no streams were processed
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    0:size(31), 0x00:size(32),
  >>
  let assert Ok(#(h, rest)) = h2_frame.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.GoAway(
          last_stream_id: 0,
          error_code: h2_frame.NoError,
          debug_data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_unknown_error_code_test() {
  // RFC 9113 Section 7: Unknown error codes MUST NOT trigger special behavior
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0xFF:size(32),
  >>
  let assert Ok(#(h, rest)) = h2_frame.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.GoAway(
          last_stream_id: 1,
          error_code: h2_frame.UnknownErrorCode(0xFF),
          debug_data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_stream_id_nonzero_test() {
  // RFC 9113 Section 6.8: Stream ID must be 0x00, otherwise PROTOCOL_ERROR
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    1:size(31), 0x00:size(32),
  >>
  let assert Ok(#(h, rest)) = h2_frame.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn parse_goaway_unknown_flags_ignored_test() {
  // RFC 9113 Section 6.8: No flags defined; all flags MUST be ignored
  let data = <<
    8:size(24), 7:size(8), 0xFF:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0x00:size(32),
  >>
  let assert Ok(#(h, rest)) = h2_frame.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.GoAway(
          last_stream_id: 1,
          error_code: h2_frame.NoError,
          debug_data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_too_short_length_test() {
  // RFC 9113 Section 6.8: GOAWAY minimum payload is 8 bytes (last_stream_id + error_code)
  // A header declaring length < 8 MUST be treated as FRAME_SIZE_ERROR
  let data = <<
    4:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31),
  >>
  let assert Ok(#(h, rest)) = h2_frame.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.FrameSizeError)))
}

pub fn parse_goaway_truncated_payload_test() {
  // RFC 9113 Section 6.8: Header says 8 bytes but not enough data available
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31),
  >>
  let assert Ok(#(h, rest)) = h2_frame.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(Error(h2_frame.IncompletePayload))
}

pub fn parse_goaway_with_trailing_data_test() {
  // RFC 9113 Section 6.8: Trailing data from next frame returned
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0x00:size(32), 99, 99,
  >>
  let assert Ok(#(h, rest)) = h2_frame.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.GoAway(
          last_stream_id: 1,
          error_code: h2_frame.NoError,
          debug_data: <<>>,
        ),
        <<99, 99>>,
      ),
    ),
  )
}

pub fn parse_goaway_debug_data_with_trailing_test() {
  // RFC 9113 Section 6.8: Debug data AND trailing data from next frame
  let data = <<
    11:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0x02:size(32), "err":utf8, 99, 99,
  >>
  let assert Ok(#(h, rest)) = h2_frame.parse_header(data)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.GoAway(
          last_stream_id: 1,
          error_code: h2_frame.InternalError,
          debug_data: <<"err":utf8>>,
        ),
        <<99, 99>>,
      ),
    ),
  )
}

// --- Encode tests ---

pub fn encode_goaway_test() {
  // RFC 9113 Section 6.8: Basic GOAWAY with no debug data
  h2_frame.encode_goaway(
    last_stream_id: 1,
    error_code: h2_frame.NoError,
    debug_data: <<>>,
  )
  |> should.equal(<<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0x00:size(32),
  >>)
}

pub fn encode_goaway_with_error_test() {
  // RFC 9113 Section 6.8: GOAWAY with PROTOCOL_ERROR
  h2_frame.encode_goaway(
    last_stream_id: 5,
    error_code: h2_frame.ProtocolError,
    debug_data: <<>>,
  )
  |> should.equal(<<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    5:size(31), 0x01:size(32),
  >>)
}

pub fn encode_goaway_with_debug_data_test() {
  // RFC 9113 Section 6.8: GOAWAY with additional debug data
  h2_frame.encode_goaway(
    last_stream_id: 1,
    error_code: h2_frame.NoError,
    debug_data: <<
      "hello":utf8,
    >>,
  )
  |> should.equal(<<
    13:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0x00:size(32), "hello":utf8,
  >>)
}

pub fn encode_goaway_zero_last_stream_id_test() {
  // RFC 9113 Section 6.8: last_stream_id=0 means no streams were processed
  h2_frame.encode_goaway(
    last_stream_id: 0,
    error_code: h2_frame.NoError,
    debug_data: <<>>,
  )
  |> should.equal(<<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    0:size(31), 0x00:size(32),
  >>)
}

pub fn encode_goaway_unknown_error_code_test() {
  // RFC 9113 Section 7: Unknown error codes are valid
  h2_frame.encode_goaway(
    last_stream_id: 1,
    error_code: h2_frame.UnknownErrorCode(0xFF),
    debug_data: <<>>,
  )
  |> should.equal(<<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0xFF:size(32),
  >>)
}

pub fn encode_goaway_roundtrip_test() {
  // Encode then parse should produce the same values
  let encoded =
    h2_frame.encode_goaway(
      last_stream_id: 3,
      error_code: h2_frame.InternalError,
      debug_data: <<"err":utf8>>,
    )
  let assert Ok(#(h, rest)) = h2_frame.parse_header(encoded)
  h2_frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        h2_frame.GoAway(
          last_stream_id: 3,
          error_code: h2_frame.InternalError,
          debug_data: <<"err":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}
