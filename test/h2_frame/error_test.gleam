import gleam/list
import gleeunit/should
import h2_frame

// RFC 9113 Section 7: Error codes are 32-bit fields used in RST_STREAM and GOAWAY frames

pub fn parse_no_error_test() {
  h2_frame.parse_error_code(0x00)
  |> should.equal(h2_frame.NoError)
}

pub fn parse_protocol_error_test() {
  h2_frame.parse_error_code(0x01)
  |> should.equal(h2_frame.ProtocolError)
}

pub fn parse_internal_error_test() {
  h2_frame.parse_error_code(0x02)
  |> should.equal(h2_frame.InternalError)
}

pub fn parse_flow_control_error_test() {
  h2_frame.parse_error_code(0x03)
  |> should.equal(h2_frame.FlowControlError)
}

pub fn parse_settings_timeout_test() {
  h2_frame.parse_error_code(0x04)
  |> should.equal(h2_frame.SettingsTimeout)
}

pub fn parse_stream_closed_test() {
  h2_frame.parse_error_code(0x05)
  |> should.equal(h2_frame.StreamClosed)
}

pub fn parse_frame_size_error_test() {
  h2_frame.parse_error_code(0x06)
  |> should.equal(h2_frame.FrameSizeError)
}

pub fn parse_refused_stream_test() {
  h2_frame.parse_error_code(0x07)
  |> should.equal(h2_frame.RefusedStream)
}

pub fn parse_cancel_test() {
  h2_frame.parse_error_code(0x08)
  |> should.equal(h2_frame.Cancel)
}

pub fn parse_compression_error_test() {
  h2_frame.parse_error_code(0x09)
  |> should.equal(h2_frame.CompressionError)
}

pub fn parse_connect_error_test() {
  h2_frame.parse_error_code(0x0a)
  |> should.equal(h2_frame.ConnectError)
}

pub fn parse_enhance_your_calm_test() {
  h2_frame.parse_error_code(0x0b)
  |> should.equal(h2_frame.EnhanceYourCalm)
}

pub fn parse_inadequate_security_test() {
  h2_frame.parse_error_code(0x0c)
  |> should.equal(h2_frame.InadequateSecurity)
}

pub fn parse_http_1_1_required_test() {
  h2_frame.parse_error_code(0x0d)
  |> should.equal(h2_frame.Http11Required)
}

pub fn parse_unknown_error_code_test() {
  // RFC 9113 Section 7: Unknown error codes MUST NOT trigger special behavior
  h2_frame.parse_error_code(0xff)
  |> should.equal(h2_frame.UnknownErrorCode(0xff))
}

pub fn encode_no_error_test() {
  h2_frame.encode_error_code(h2_frame.NoError)
  |> should.equal(0x00)
}

pub fn encode_protocol_error_test() {
  h2_frame.encode_error_code(h2_frame.ProtocolError)
  |> should.equal(0x01)
}

pub fn encode_frame_size_error_test() {
  h2_frame.encode_error_code(h2_frame.FrameSizeError)
  |> should.equal(0x06)
}

pub fn encode_unknown_error_code_test() {
  h2_frame.encode_error_code(h2_frame.UnknownErrorCode(0xff))
  |> should.equal(0xff)
}

pub fn roundtrip_all_error_codes_test() {
  // Verify all known codes roundtrip correctly
  let codes = [
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c,
    0x0d, 0xff,
  ]
  list.each(codes, fn(code) {
    h2_frame.parse_error_code(code)
    |> h2_frame.encode_error_code()
    |> should.equal(code)
  })
}
