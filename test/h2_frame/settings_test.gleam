import gleeunit/should
import h2_frame

pub fn parse_settings_empty_test() {
  // RFC 9113 Section 6.5: SETTINGS frame with no settings (valid)
  let data = <<0:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  h2_frame.parse(data)
  |> should.equal(Ok(h2_frame.Settings(ack: False, settings: [])))
}

pub fn parse_settings_single_test() {
  // RFC 9113 Section 6.5: SETTINGS with HEADER_TABLE_SIZE=4096
  let data = <<
    6:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
    4096:size(32),
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(
      h2_frame.Settings(ack: False, settings: [h2_frame.HeaderTableSize(4096)]),
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
  h2_frame.parse(data)
  |> should.equal(
    Ok(
      h2_frame.Settings(ack: False, settings: [
        h2_frame.HeaderTableSize(4096),
        h2_frame.MaxConcurrentStreams(100),
      ]),
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
  h2_frame.parse(data)
  |> should.equal(
    Ok(
      h2_frame.Settings(ack: False, settings: [
        h2_frame.HeaderTableSize(4096),
        h2_frame.EnablePush(1),
        h2_frame.MaxConcurrentStreams(100),
        h2_frame.InitialWindowSize(65_535),
        h2_frame.MaxFrameSize(16_384),
        h2_frame.MaxHeaderListSize(8192),
      ]),
    ),
  )
}

pub fn parse_settings_unknown_setting_test() {
  // RFC 9113 Section 6.5.2: Unknown settings MUST be ignored (but still parsed)
  let data = <<
    6:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0xFF:size(16),
    42:size(32),
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(
      h2_frame.Settings(ack: False, settings: [
        h2_frame.UnknownSetting(0xFF, 42),
      ]),
    ),
  )
}

pub fn parse_settings_ack_test() {
  // RFC 9113 Section 6.5: ACK (0x01) flag with empty payload
  let data = <<0:size(24), 4:size(8), 1:size(8), 0:size(1), 0:size(31)>>
  h2_frame.parse(data)
  |> should.equal(Ok(h2_frame.Settings(ack: True, settings: [])))
}

pub fn parse_settings_ack_non_empty_test() {
  // RFC 9113 Section 6.5: ACK with non-empty payload MUST be FRAME_SIZE_ERROR
  let data = <<
    6:size(24), 4:size(8), 1:size(8), 0:size(1), 0:size(31), 0x01:size(16),
    4096:size(32),
  >>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.FrameSizeError)))
}

pub fn parse_settings_stream_id_nonzero_test() {
  // RFC 9113 Section 6.5: Stream ID must be 0x00, otherwise PROTOCOL_ERROR
  let data = <<0:size(24), 4:size(8), 0:size(8), 0:size(1), 1:size(31)>>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn parse_settings_length_not_multiple_of_six_test() {
  // RFC 9113 Section 6.5: Length not multiple of 6 MUST be FRAME_SIZE_ERROR
  let data = <<
    7:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0, 0, 0, 0, 0, 0, 0,
  >>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.FrameSizeError)))
}

pub fn parse_settings_unknown_flags_ignored_test() {
  // RFC 9113 Section 4.1: Unknown flags MUST be ignored
  // 0xFE has all bits set except ACK
  let data = <<0:size(24), 4:size(8), 0xFE:size(8), 0:size(1), 0:size(31)>>
  h2_frame.parse(data)
  |> should.equal(Ok(h2_frame.Settings(ack: False, settings: [])))
}

pub fn parse_settings_truncated_payload_test() {
  // RFC 9113 Section 6.5: Incomplete payload - parse expects exactly one frame
  let data = <<
    6:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
  >>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

pub fn parse_settings_with_trailing_data_test() {
  // RFC 9113 Section 6.5: Trailing data not allowed - parse expects exactly one frame
  let data = <<
    6:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
    4096:size(32), 99, 99,
  >>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.MalformedFrame))
}

// --- Encode tests ---

pub fn encode_settings_empty_test() {
  h2_frame.encode_settings(ack: False, settings: [])
  |> should.equal(
    Ok(<<0:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31)>>),
  )
}

pub fn encode_settings_ack_test() {
  h2_frame.encode_settings(ack: True, settings: [])
  |> should.equal(
    Ok(<<0:size(24), 4:size(8), 1:size(8), 0:size(1), 0:size(31)>>),
  )
}

pub fn encode_settings_single_test() {
  h2_frame.encode_settings(ack: False, settings: [
    h2_frame.HeaderTableSize(4096),
  ])
  |> should.equal(
    Ok(<<
      6:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
      4096:size(32),
    >>),
  )
}

pub fn encode_settings_multiple_test() {
  h2_frame.encode_settings(ack: False, settings: [
    h2_frame.HeaderTableSize(4096),
    h2_frame.MaxConcurrentStreams(100),
  ])
  |> should.equal(
    Ok(<<
      12:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0x01:size(16),
      4096:size(32), 0x03:size(16), 100:size(32),
    >>),
  )
}

pub fn encode_settings_all_known_test() {
  h2_frame.encode_settings(ack: False, settings: [
    h2_frame.HeaderTableSize(4096),
    h2_frame.EnablePush(1),
    h2_frame.MaxConcurrentStreams(100),
    h2_frame.InitialWindowSize(65_535),
    h2_frame.MaxFrameSize(16_384),
    h2_frame.MaxHeaderListSize(8192),
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
  h2_frame.encode_settings(ack: False, settings: [
    h2_frame.UnknownSetting(0xFF, 42),
  ])
  |> should.equal(
    Ok(<<
      6:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31), 0xFF:size(16),
      42:size(32),
    >>),
  )
}

pub fn encode_settings_ack_with_settings_test() {
  // RFC 9113 Section 6.5: ACK with non-zero length MUST be FRAME_SIZE_ERROR
  h2_frame.encode_settings(ack: True, settings: [
    h2_frame.HeaderTableSize(4096),
  ])
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.FrameSizeError)))
}

pub fn encode_settings_roundtrip_test() {
  let assert Ok(encoded) =
    h2_frame.encode_settings(ack: False, settings: [
      h2_frame.HeaderTableSize(4096),
      h2_frame.MaxConcurrentStreams(100),
    ])
  h2_frame.parse(encoded)
  |> should.equal(
    Ok(
      h2_frame.Settings(ack: False, settings: [
        h2_frame.HeaderTableSize(4096),
        h2_frame.MaxConcurrentStreams(100),
      ]),
    ),
  )
}

pub fn encode_settings_ack_roundtrip_test() {
  let assert Ok(encoded) = h2_frame.encode_settings(ack: True, settings: [])
  h2_frame.parse(encoded)
  |> should.equal(Ok(h2_frame.Settings(ack: True, settings: [])))
}
