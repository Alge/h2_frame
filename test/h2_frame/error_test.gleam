import gleam/list
import gleeunit/should
import h2_frame/error

// RFC 9113 Section 7: Error codes are 32-bit fields used in RST_STREAM and GOAWAY frames

pub fn parse_no_error_test() {
  error.parse_error_code(0x00)
  |> should.equal(error.NoError)
}

pub fn parse_protocol_error_test() {
  error.parse_error_code(0x01)
  |> should.equal(error.ProtocolError)
}

pub fn parse_internal_error_test() {
  error.parse_error_code(0x02)
  |> should.equal(error.InternalError)
}

pub fn parse_flow_control_error_test() {
  error.parse_error_code(0x03)
  |> should.equal(error.FlowControlError)
}

pub fn parse_settings_timeout_test() {
  error.parse_error_code(0x04)
  |> should.equal(error.SettingsTimeout)
}

pub fn parse_stream_closed_test() {
  error.parse_error_code(0x05)
  |> should.equal(error.StreamClosed)
}

pub fn parse_frame_size_error_test() {
  error.parse_error_code(0x06)
  |> should.equal(error.FrameSizeError)
}

pub fn parse_refused_stream_test() {
  error.parse_error_code(0x07)
  |> should.equal(error.RefusedStream)
}

pub fn parse_cancel_test() {
  error.parse_error_code(0x08)
  |> should.equal(error.Cancel)
}

pub fn parse_compression_error_test() {
  error.parse_error_code(0x09)
  |> should.equal(error.CompressionError)
}

pub fn parse_connect_error_test() {
  error.parse_error_code(0x0a)
  |> should.equal(error.ConnectError)
}

pub fn parse_enhance_your_calm_test() {
  error.parse_error_code(0x0b)
  |> should.equal(error.EnhanceYourCalm)
}

pub fn parse_inadequate_security_test() {
  error.parse_error_code(0x0c)
  |> should.equal(error.InadequateSecurity)
}

pub fn parse_http_1_1_required_test() {
  error.parse_error_code(0x0d)
  |> should.equal(error.Http11Required)
}

pub fn parse_unknown_error_code_test() {
  // RFC 9113 Section 7: Unknown error codes MUST NOT trigger special behavior
  error.parse_error_code(0xff)
  |> should.equal(error.UnknownErrorCode(0xff))
}

pub fn encode_no_error_test() {
  error.encode_error_code(error.NoError)
  |> should.equal(0x00)
}

pub fn encode_protocol_error_test() {
  error.encode_error_code(error.ProtocolError)
  |> should.equal(0x01)
}

pub fn encode_frame_size_error_test() {
  error.encode_error_code(error.FrameSizeError)
  |> should.equal(0x06)
}

pub fn encode_unknown_error_code_test() {
  error.encode_error_code(error.UnknownErrorCode(0xff))
  |> should.equal(0xff)
}

pub fn roundtrip_all_error_codes_test() {
  // Verify all known codes roundtrip correctly
  let codes = [
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c,
    0x0d, 0xff,
  ]
  list.each(codes, fn(code) {
    error.parse_error_code(code)
    |> error.encode_error_code()
    |> should.equal(code)
  })
}
