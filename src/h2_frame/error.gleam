pub type ErrorCode {
  NoError
  ProtocolError
  InternalError
  FlowControlError
  SettingsTimeout
  StreamClosed
  FrameSizeError
  RefusedStream
  Cancel
  CompressionError
  ConnectError
  EnhanceYourCalm
  InadequateSecurity
  Http11Required
  UnknownErrorCode(Int)
}

pub fn parse_error_code(code: Int) -> ErrorCode {
  case code {
    0x00 -> NoError
    0x01 -> ProtocolError
    0x02 -> InternalError
    0x03 -> FlowControlError
    0x04 -> SettingsTimeout
    0x05 -> StreamClosed
    0x06 -> FrameSizeError
    0x07 -> RefusedStream
    0x08 -> Cancel
    0x09 -> CompressionError
    0x0a -> ConnectError
    0x0b -> EnhanceYourCalm
    0x0c -> InadequateSecurity
    0x0d -> Http11Required
    code -> UnknownErrorCode(code)
  }
}

pub fn encode_error_code(error_code: ErrorCode) -> Int {
  case error_code {
    NoError -> 0x00
    ProtocolError -> 0x01
    InternalError -> 0x02
    FlowControlError -> 0x03
    SettingsTimeout -> 0x04
    StreamClosed -> 0x05
    FrameSizeError -> 0x06
    RefusedStream -> 0x07
    Cancel -> 0x08
    CompressionError -> 0x09
    ConnectError -> 0x0a
    EnhanceYourCalm -> 0x0b
    InadequateSecurity -> 0x0c
    Http11Required -> 0x0d
    UnknownErrorCode(code) -> code
  }
}
