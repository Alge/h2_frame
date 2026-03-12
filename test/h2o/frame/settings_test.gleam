import gleeunit/should
import h2o/frame
import h2o/frame/error
import h2o/frame/header

pub fn parse_settings_empty_test() {
  // RFC 9113 Section 6.5: SETTINGS frame with no settings (valid)
  let data = <<0:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.Settings(ack: False, settings: []), <<>>)))
}

pub fn parse_settings_single_test() {
  // RFC 9113 Section 6.5: SETTINGS with HEADER_TABLE_SIZE=4096
  let data = <<
    6:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
    4096:size(32),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        frame.Settings(ack: False, settings: [frame.HeaderTableSize(4096)]),
        <<>>,
      ),
    ),
  )
}

pub fn parse_settings_multiple_test() {
  // RFC 9113 Section 6.5: SETTINGS with multiple parameters
  // HEADER_TABLE_SIZE=4096, MAX_CONCURRENT_STREAMS=100
  let data = <<
    12:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
    4096:size(32), 0x03:size(16), 100:size(32),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        frame.Settings(ack: False, settings: [
          frame.HeaderTableSize(4096),
          frame.MaxConcurrentStreams(100),
        ]),
        <<>>,
      ),
    ),
  )
}

pub fn parse_settings_all_known_test() {
  // RFC 9113 Section 6.5.2: All six defined settings
  let data = <<
    36:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
    4096:size(32), 0x02:size(16), 1:size(32), 0x03:size(16), 100:size(32),
    0x04:size(16), 65_535:size(32), 0x05:size(16), 16_384:size(32),
    0x06:size(16), 8192:size(32),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        frame.Settings(ack: False, settings: [
          frame.HeaderTableSize(4096),
          frame.EnablePush(1),
          frame.MaxConcurrentStreams(100),
          frame.InitialWindowSize(65_535),
          frame.MaxFrameSize(16_384),
          frame.MaxHeaderListSize(8192),
        ]),
        <<>>,
      ),
    ),
  )
}

pub fn parse_settings_unknown_setting_test() {
  // RFC 9113 Section 6.5.2: Unknown settings MUST be ignored (but still parsed)
  let data = <<
    6:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0xFF:size(16),
    42:size(32),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        frame.Settings(ack: False, settings: [frame.UnknownSetting(0xFF, 42)]),
        <<>>,
      ),
    ),
  )
}

pub fn parse_settings_ack_test() {
  // RFC 9113 Section 6.5: ACK (0x01) flag with empty payload
  let data = <<0:size(24), 4:size(8), 1:size(8), 0:size(1), 0:size(31)>>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.Settings(ack: True, settings: []), <<>>)))
}

pub fn parse_settings_ack_non_empty_test() {
  // RFC 9113 Section 6.5: ACK with non-empty payload MUST be FRAME_SIZE_ERROR
  let data = <<
    6:size(24), 4:size(8), 1:size(8), 0:size(1), 0:size(31), 0x01:size(16),
    4096:size(32),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.ConnectionError(error.FrameSizeError)))
}

pub fn parse_settings_stream_id_nonzero_test() {
  // RFC 9113 Section 6.5: Stream ID must be 0x00, otherwise PROTOCOL_ERROR
  let data = <<0:size(24), 4:size(8), 0:size(8), 0:size(1), 1:size(31)>>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_settings_length_not_multiple_of_six_test() {
  // RFC 9113 Section 6.5: Length not multiple of 6 MUST be FRAME_SIZE_ERROR
  let data = <<
    7:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0, 0, 0, 0, 0, 0, 0,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.ConnectionError(error.FrameSizeError)))
}

pub fn parse_settings_unknown_flags_ignored_test() {
  // RFC 9113 Section 4.1: Unknown flags MUST be ignored
  // 0xFE has all bits set except ACK
  let data = <<0:size(24), 4:size(8), 0xFE:size(8), 0:size(1), 0:size(31)>>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.Settings(ack: False, settings: []), <<>>)))
}

pub fn parse_settings_truncated_payload_test() {
  // RFC 9113 Section 6.5: Incomplete payload
  let data = <<
    6:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_settings_with_trailing_data_test() {
  // RFC 9113 Section 6.5: Trailing data from next frame returned
  let data = <<
    6:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
    4096:size(32), 99, 99,
  >>
  let assert Ok(#(h, rest)) = header.parse_header(data)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(frame.Settings(ack: False, settings: [frame.HeaderTableSize(4096)]), <<
        99,
        99,
      >>),
    ),
  )
}

// --- Encode tests ---

pub fn encode_settings_empty_test() {
  // RFC 9113 Section 6.5: SETTINGS frame with no settings
  frame.encode_settings(ack: False, settings: [])
  |> should.equal(
    Ok(<<0:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31)>>),
  )
}

pub fn encode_settings_ack_test() {
  // RFC 9113 Section 6.5: ACK (0x01) flag with empty payload
  frame.encode_settings(ack: True, settings: [])
  |> should.equal(
    Ok(<<0:size(24), 4:size(8), 1:size(8), 0:size(1), 0:size(31)>>),
  )
}

pub fn encode_settings_single_test() {
  // RFC 9113 Section 6.5: Single setting HEADER_TABLE_SIZE=4096
  frame.encode_settings(ack: False, settings: [frame.HeaderTableSize(4096)])
  |> should.equal(
    Ok(<<
      6:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
      4096:size(32),
    >>),
  )
}

pub fn encode_settings_multiple_test() {
  // RFC 9113 Section 6.5: Multiple settings
  frame.encode_settings(ack: False, settings: [
    frame.HeaderTableSize(4096),
    frame.MaxConcurrentStreams(100),
  ])
  |> should.equal(
    Ok(<<
      12:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
      4096:size(32), 0x03:size(16), 100:size(32),
    >>),
  )
}

pub fn encode_settings_all_known_test() {
  // RFC 9113 Section 6.5.2: All six defined settings
  frame.encode_settings(ack: False, settings: [
    frame.HeaderTableSize(4096),
    frame.EnablePush(1),
    frame.MaxConcurrentStreams(100),
    frame.InitialWindowSize(65_535),
    frame.MaxFrameSize(16_384),
    frame.MaxHeaderListSize(8192),
  ])
  |> should.equal(
    Ok(<<
      36:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
      4096:size(32), 0x02:size(16), 1:size(32), 0x03:size(16), 100:size(32),
      0x04:size(16), 65_535:size(32), 0x05:size(16), 16_384:size(32),
      0x06:size(16), 8192:size(32),
    >>),
  )
}

pub fn encode_settings_unknown_setting_test() {
  // RFC 9113 Section 6.5.2: Unknown settings are valid
  frame.encode_settings(ack: False, settings: [frame.UnknownSetting(0xFF, 42)])
  |> should.equal(
    Ok(<<
      6:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0xFF:size(16),
      42:size(32),
    >>),
  )
}

pub fn encode_settings_ack_with_settings_test() {
  // RFC 9113 Section 6.5: ACK with non-empty settings MUST be an error
  frame.encode_settings(ack: True, settings: [frame.HeaderTableSize(4096)])
  |> should.be_error()
}

pub fn encode_settings_roundtrip_test() {
  // Encode then parse should produce the same values
  let assert Ok(encoded) =
    frame.encode_settings(ack: False, settings: [
      frame.HeaderTableSize(4096),
      frame.MaxConcurrentStreams(100),
    ])
  let assert Ok(#(h, rest)) = header.parse_header(encoded)
  frame.parse_payload(h, rest)
  |> should.equal(
    Ok(
      #(
        frame.Settings(ack: False, settings: [
          frame.HeaderTableSize(4096),
          frame.MaxConcurrentStreams(100),
        ]),
        <<>>,
      ),
    ),
  )
}

pub fn encode_settings_ack_roundtrip_test() {
  // ACK roundtrip
  let assert Ok(encoded) = frame.encode_settings(ack: True, settings: [])
  let assert Ok(#(h, rest)) = header.parse_header(encoded)
  frame.parse_payload(h, rest)
  |> should.equal(Ok(#(frame.Settings(ack: True, settings: []), <<>>)))
}
