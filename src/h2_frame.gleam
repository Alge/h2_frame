import gleam/bit_array
import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

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

pub type FrameError {
  ConnectionError(error_code: ErrorCode)
  StreamError(stream_id: Int, error_code: ErrorCode)
  NeedMoreData
  InvalidPadding
  MalformedFrame
}

pub type Setting {
  HeaderTableSize(Int)
  EnablePush(Int)
  MaxConcurrentStreams(Int)
  InitialWindowSize(Int)
  MaxFrameSize(Int)
  MaxHeaderListSize(Int)
  UnknownSetting(id: Int, value: Int)
}

fn parse_settings_list(
  data: BitArray,
  settings: List(Setting),
) -> Result(List(Setting), FrameError) {
  case data {
    <<>> -> Ok(list.reverse(settings))

    <<setting_id:size(16), value:size(32), rest:bits>> -> {
      let setting = case setting_id {
        0x01 -> HeaderTableSize(value)
        0x02 -> EnablePush(value)
        0x03 -> MaxConcurrentStreams(value)
        0x04 -> InitialWindowSize(value)
        0x05 -> MaxFrameSize(value)
        0x06 -> MaxHeaderListSize(value)
        code -> UnknownSetting(code, value)
      }

      parse_settings_list(rest, [setting, ..settings])
    }

    _ -> Error(MalformedFrame)
  }
}

fn encode_settings_list(settings: List(Setting), encoded: BitArray) -> BitArray {
  case settings {
    [] -> encoded
    [setting, ..rest] -> {
      let #(id, value) = case setting {
        HeaderTableSize(v) -> #(0x01, v)
        EnablePush(v) -> #(0x02, v)
        MaxConcurrentStreams(v) -> #(0x03, v)
        InitialWindowSize(v) -> #(0x04, v)
        MaxFrameSize(v) -> #(0x05, v)
        MaxHeaderListSize(v) -> #(0x06, v)
        UnknownSetting(id, v) -> #(id, v)
      }

      let encoded_setting = <<id:size(16), value:size(32)>>

      encode_settings_list(rest, <<
        encoded:bits,
        encoded_setting:bits,
      >>)
    }
  }
}

pub type Frame {
  Data(stream_id: Int, end_stream: Bool, data: BitArray)
  Headers(
    stream_id: Int,
    end_stream: Bool,
    end_headers: Bool,
    priority: Option(StreamPriority),
    field_block_fragment: BitArray,
  )
  Priority(stream_id: Int, exclusive: Bool, stream_dependency: Int, weight: Int)
  RstStream(stream_id: Int, error_code: ErrorCode)
  Settings(ack: Bool, settings: List(Setting))
  PushPromise(
    stream_id: Int,
    end_headers: Bool,
    promised_stream_id: Int,
    field_block_fragment: BitArray,
  )
  Ping(ack: Bool, data: BitArray)
  Goaway(last_stream_id: Int, error_code: ErrorCode, debug_data: BitArray)
  WindowUpdate(stream_id: Int, window_size_increment: Int)
  Continuation(
    stream_id: Int,
    end_headers: Bool,
    field_block_fragment: BitArray,
  )
  Unknown(stream_id: Int, frame_type: Int, flags: Int, data: BitArray)
}

pub type StreamPriority {
  StreamPriority(exclusive: Bool, stream_dependency: Int, weight: Int)
}

fn encode_stream_priority(stream_priority: StreamPriority) -> BitArray {
  let exclusive_bit = case stream_priority.exclusive {
    True -> 1
    False -> 0
  }
  <<
    exclusive_bit:size(1),
    stream_priority.stream_dependency:size(31),
    stream_priority.weight:size(8),
  >>
}

fn parse_data(data: BitArray) -> Result(Frame, FrameError) {
  case data {
    <<
      length:size(24),
      _type:size(8),
      _unused_flags:size(4),
      padded:size(1),
      _unused_flags:size(2),
      end_stream_bit:size(1),
      _reserved:size(1),
      stream_id:size(31),
      pad_length:size(8 * padded),
      payload:bytes-size(length - 1 * padded),
    >> -> {
      // Make sure the pad length is not greater than the reported length of the payload
      use <- bool.guard(
        padded == 1 && pad_length >= length,
        Error(ConnectionError(ProtocolError)),
      )

      // stream_id cannot be 0
      use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))

      case payload {
        <<
          data:bytes-size(length - pad_length - 1 * padded),
          _padding:bytes-size(pad_length),
        >> -> {
          Ok(Data(
            stream_id: stream_id,
            end_stream: end_stream_bit == 1,
            data: data,
          ))
        }
        _ -> Error(MalformedFrame)
      }
    }
    _ -> Error(MalformedFrame)
  }
}

fn parse_headers(data: BitArray) -> Result(Frame, FrameError) {
  case data {
    <<
      length:size(24),
      _type:size(8),
      _unused_flags:size(2),
      priority:size(1),
      _unused_flag:size(1),
      padded:size(1),
      end_headers_bit:size(1),
      _unused_flags:size(1),
      end_stream_bit:size(1),
      _reserved:size(1),
      stream_id:size(31),
      pad_length:size(8 * padded),
      // Deprecated priority part
      exclusive:size(1 * priority),
      stream_dependency:size(31 * priority),
      weight:size(8 * priority),
      // End of deprecated priority part
      payload:bytes-size(length - 1 * padded - 5 * priority),
    >> -> {
      // Make sure the pad length is not greater than the reported length of the payload
      use <- bool.guard(
        padded == 1 && pad_length + 1 + 5 * priority >= length,
        Error(ConnectionError(ProtocolError)),
      )

      // stream_id cannot be 0
      use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))

      let stream_priority = case priority {
        1 -> {
          Some(StreamPriority(
            exclusive: exclusive == 1,
            stream_dependency: stream_dependency,
            weight: weight,
          ))
        }
        _ -> None
      }

      case payload {
        <<
          data:bytes-size(length - pad_length - 1 * padded - 5 * priority),
          _padding:bytes-size(pad_length),
        >> -> {
          Ok(Headers(
            stream_id: stream_id,
            end_stream: end_stream_bit == 1,
            end_headers: end_headers_bit == 1,
            priority: stream_priority,
            field_block_fragment: data,
          ))
        }
        _ -> Error(MalformedFrame)
      }
    }
    _ -> Error(MalformedFrame)
  }
}

fn parse_priority(data: BitArray) -> Result(Frame, FrameError) {
  case data {
    <<
      length:size(24),
      _type:size(8),
      _unused_flags:size(8),
      _reserved:size(1),
      stream_id:size(31),
      payload:bytes-size(length),
    >> -> {
      // Parsing is done in two steps to be able to catch invalid lengths
      use <- bool.guard(
        length != 5,
        Error(StreamError(stream_id: stream_id, error_code: FrameSizeError)),
      )

      // stream_id cannot be 0
      use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))

      case payload {
        <<exclusive:size(1), stream_dependency:size(31), weight:size(8)>> -> {
          // RFC 9113 Section 5.3.1: A stream cannot depend on itself
          use <- bool.guard(
            stream_id == stream_dependency,
            Error(StreamError(stream_id, ProtocolError)),
          )
          Ok(Priority(
            stream_id: stream_id,
            exclusive: exclusive == 1,
            stream_dependency: stream_dependency,
            weight: weight,
          ))
        }

        _ -> Error(MalformedFrame)
      }
    }
    _ -> Error(MalformedFrame)
  }
}

fn parse_rst_stream(data: BitArray) -> Result(Frame, FrameError) {
  case data {
    <<
      length:size(24),
      _type:size(8),
      _unused_flags:size(8),
      _reserved:size(1),
      stream_id:size(31),
      payload:bytes-size(length),
    >> -> {
      // Parsing is done in two steps to be able to catch invalid lengths
      use <- bool.guard(length != 4, Error(ConnectionError(FrameSizeError)))

      // stream_id cannot be 0
      use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))

      case payload {
        <<error_code:size(32)>> -> {
          Ok(RstStream(
            stream_id: stream_id,
            error_code: parse_error_code(error_code),
          ))
        }

        _ -> Error(MalformedFrame)
      }
    }
    _ -> Error(MalformedFrame)
  }
}

fn parse_settings(data: BitArray) -> Result(Frame, FrameError) {
  case data {
    <<
      length:size(24),
      _type:size(8),
      _unused_flags:size(7),
      ack:size(1),
      _reserved:size(1),
      stream_id:size(31),
      payload:bytes-size(length),
    >> -> {
      use <- bool.guard(stream_id != 0, Error(ConnectionError(ProtocolError)))

      use <- bool.guard(
        ack == 1 && length != 0,
        Error(ConnectionError(FrameSizeError)),
      )

      use <- bool.guard(length % 6 != 0, Error(ConnectionError(FrameSizeError)))

      use settings <- result.try(parse_settings_list(payload, []))
      Ok(Settings(ack: ack == 1, settings: settings))
    }

    _ -> Error(MalformedFrame)
  }
}

fn parse_push_promise(data: BitArray) -> Result(Frame, FrameError) {
  case data {
    <<
      length:size(24),
      _type:size(8),
      _unused_flags:size(4),
      padded:size(1),
      end_headers:size(1),
      _unused_flags:size(2),
      _reserved:size(1),
      stream_id:size(31),
      pad_length:size(8 * padded),
      payload:bytes-size(length - 1 * padded),
    >> -> {
      // Make sure the pad length is not greater than the reported length of the payload
      use <- bool.guard(
        padded == 1 && pad_length + 1 * padded + 4 >= length,
        Error(ConnectionError(ProtocolError)),
      )

      // stream_id cannot be 0
      use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))

      case payload {
        <<
          _reserved:size(1),
          promised_stream_id:size(31),
          data:bytes-size(length - pad_length - 1 * padded - 4),
          _padding:bytes-size(pad_length),
        >> -> {
          // RFC 9113 Section 6.6: Promised stream ID of 0x00 is invalid
          use <- bool.guard(
            promised_stream_id == 0,
            Error(ConnectionError(ProtocolError)),
          )
          Ok(PushPromise(
            stream_id: stream_id,
            end_headers: end_headers == 1,
            promised_stream_id: promised_stream_id,
            field_block_fragment: data,
          ))
        }
        _ -> Error(MalformedFrame)
      }
    }
    _ -> Error(MalformedFrame)
  }
}

fn parse_ping(data: BitArray) -> Result(Frame, FrameError) {
  case data {
    <<
      length:size(24),
      _type:size(8),
      _unused_flags:size(7),
      ack:size(1),
      _reserved:size(1),
      stream_id:size(31),
      data:bytes-size(length),
    >> -> {
      use <- bool.guard(length != 8, Error(ConnectionError(FrameSizeError)))

      use <- bool.guard(stream_id != 0, Error(ConnectionError(ProtocolError)))

      Ok(Ping(ack: ack == 1, data: data))
    }

    _ -> Error(MalformedFrame)
  }
}

fn parse_go_away(data: BitArray) -> Result(Frame, FrameError) {
  case data {
    <<
      length:size(24),
      _type:size(8),
      _unused_flags:size(8),
      _reserved:size(1),
      stream_id:size(31),
      payload:bytes-size(length),
    >> -> {
      use <- bool.guard(stream_id != 0, Error(ConnectionError(ProtocolError)))
      use <- bool.guard(length < 8, Error(ConnectionError(FrameSizeError)))

      case payload {
        <<
          _reserved:size(1),
          last_stream_id:size(31),
          error_code:size(32),
          debug_data:bytes,
        >> -> {
          Ok(Goaway(
            last_stream_id: last_stream_id,
            error_code: parse_error_code(error_code),
            debug_data: debug_data,
          ))
        }
        _ -> Error(MalformedFrame)
      }
    }

    _ -> Error(MalformedFrame)
  }
}

fn parse_window_update(data: BitArray) -> Result(Frame, FrameError) {
  case data {
    <<
      length:size(24),
      _type:size(8),
      _unused_flags:size(8),
      _reserved:size(1),
      stream_id:size(31),
      payload:bytes-size(length),
    >> -> {
      use <- bool.guard(length != 4, Error(ConnectionError(FrameSizeError)))

      case payload {
        <<_reserved:size(1), window_size_increment:size(31)>> -> {
          use <- bool.guard(
            window_size_increment == 0 && stream_id == 0,
            Error(ConnectionError(ProtocolError)),
          )
          use <- bool.guard(
            window_size_increment == 0 && stream_id != 0,
            Error(StreamError(stream_id: stream_id, error_code: ProtocolError)),
          )
          Ok(WindowUpdate(
            stream_id: stream_id,
            window_size_increment: window_size_increment,
          ))
        }

        _ -> Error(MalformedFrame)
      }
    }
    _ -> Error(MalformedFrame)
  }
}

fn parse_continuation(data: BitArray) -> Result(Frame, FrameError) {
  case data {
    <<
      length:size(24),
      _type:size(8),
      _unused_flags:size(5),
      end_headers:size(1),
      _unused_flags:size(2),
      _reserved:size(1),
      stream_id:size(31),
      field_block_fragment:bytes-size(length),
    >> -> {
      use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))
      Ok(Continuation(
        stream_id: stream_id,
        end_headers: end_headers == 1,
        field_block_fragment: field_block_fragment,
      ))
    }
    _ -> Error(MalformedFrame)
  }
}

fn parse_unknown(data: BitArray) -> Result(Frame, FrameError) {
  case data {
    <<
      length:size(24),
      frame_type:size(8),
      flags:size(8),
      _reserved:size(1),
      stream_id:size(31),
      data:bytes-size(length),
    >> -> {
      Ok(Unknown(
        stream_id: stream_id,
        frame_type: frame_type,
        flags: flags,
        data: data,
      ))
    }
    _ -> Error(MalformedFrame)
  }
}

/// Reads the 9-byte frame header, validates the declared payload length
/// against max_frame_size, and slices out the complete frame.
/// Returns the raw frame bytes (header + payload) and the remaining bytes.
pub fn extract_frame(
  data: BitArray,
  max_frame_size: Int,
) -> Result(#(BitArray, BitArray), FrameError) {
  case data {
    <<length:size(24), rest:bits>> -> {
      use <- bool.guard(
        length > max_frame_size,
        Error(ConnectionError(FrameSizeError)),
      )

      case rest {
        <<data:bytes-size(6 + length), rest:bits>> -> {
          Ok(#(<<length:size(24), data:bits>>, rest))
        }

        _ -> Error(NeedMoreData)
      }
    }
    _ -> Error(NeedMoreData)
  }
}

/// Parses a complete HTTP/2 frame from binary data.
/// Expects exactly one frame's worth of bytes (as returned by extract_frame).
/// Returns MalformedFrame if the input is too short or has trailing bytes.
pub fn parse(data: BitArray) -> Result(Frame, FrameError) {
  case data {
    <<_length:size(24), frame_type:size(8), _:bits>> -> {
      case frame_type {
        0x00 -> parse_data(data)
        0x01 -> parse_headers(data)
        0x02 -> parse_priority(data)
        0x03 -> parse_rst_stream(data)
        0x04 -> parse_settings(data)
        0x05 -> parse_push_promise(data)
        0x06 -> parse_ping(data)
        0x07 -> parse_go_away(data)
        0x08 -> parse_window_update(data)
        0x09 -> parse_continuation(data)
        _ -> parse_unknown(data)
      }
    }
    _ -> Error(MalformedFrame)
  }
}

// Helper for converting bools to integer for easier building of frame BitArrays
fn to_int(b: Bool) -> Int {
  case b {
    True -> 1
    False -> 0
  }
}

pub fn encode_data(
  stream_id stream_id: Int,
  end_stream end_stream: Bool,
  data data: BitArray,
  padding padding: Option(Int),
) -> Result(BitArray, FrameError) {
  use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))
  use <- bool.guard(
    case padding {
      Some(p) -> p < 0 || p > 255
      None -> False
    },
    Error(InvalidPadding),
  )

  let #(padded, pad_length) = case padding {
    Some(pad_length) -> #(1, pad_length)
    None -> #(0, 0)
  }

  let length = bit_array.byte_size(data) + pad_length + 1 * padded

  Ok(<<
    length:size(24),
    // frame type, 0x00 for DATA
    0x00:size(8),
    // flags
    0:size(4),
    padded:size(1),
    0:size(2),
    to_int(end_stream):size(1),
    // end of flags
    // reserved bit
    0:size(1),
    stream_id:size(31),
    pad_length:size({ 8 * padded }),
    data:bits,
    0:size({ 8 * pad_length }),
  >>)
}

pub fn encode_headers(
  stream_id stream_id: Int,
  end_stream end_stream: Bool,
  end_headers end_headers: Bool,
  priority priority: Option(StreamPriority),
  field_block_fragment field_block_fragment: BitArray,
  padding padding: Option(Int),
) -> Result(BitArray, FrameError) {
  use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))
  use <- bool.guard(
    case padding {
      Some(p) -> p < 0 || p > 255
      None -> False
    },
    Error(InvalidPadding),
  )
  let #(padded, pad_length) = case padding {
    Some(pad_length) -> #(1, pad_length)
    None -> #(0, 0)
  }

  let #(has_priority_bit, priority_data) = case priority {
    Some(p) -> #(1, encode_stream_priority(p))
    None -> #(0, <<>>)
  }

  let priority_len = 5 * has_priority_bit
  let padding_len = pad_length + 1 * padded
  let length =
    priority_len + bit_array.byte_size(field_block_fragment) + padding_len

  Ok(<<
    length:size(24),
    // frame type, 0x01 for HEADERS
    0x01:size(8),
    // flags
    0:size(2),
    has_priority_bit:size(1),
    0:size(1),
    padded:size(1),
    to_int(end_headers):size(1),
    0:size(1),
    to_int(end_stream):size(1),
    // end of flags
    // reserved bit
    0:size(1),
    stream_id:size(31),
    pad_length:size({ 8 * padded }),
    priority_data:bits,
    field_block_fragment:bits,
    0:size({ 8 * pad_length }),
  >>)
}

pub fn encode_priority(
  stream_id stream_id: Int,
  exclusive exclusive: Bool,
  stream_dependency stream_dependency: Int,
  weight weight: Int,
) -> Result(BitArray, FrameError) {
  use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))

  Ok(<<
    5:size(24),
    // frame type, 0x02 for PRIORITY
    0x02:size(8),
    // flags
    0:size(8),
    // reserved bit
    0:size(1),
    stream_id:size(31),
    to_int(exclusive):size(1),
    stream_dependency:size(31),
    weight:size(8),
  >>)
}

pub fn encode_rst_stream(
  stream_id stream_id: Int,
  error_code error_code: ErrorCode,
) -> Result(BitArray, FrameError) {
  use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))

  Ok(<<
    4:size(24),
    // frame type, 0x03 for RSTSTREAM
    0x03:size(8),
    // flags
    0:size(8),
    // reserved bit
    0:size(1),
    stream_id:size(31),
    encode_error_code(error_code):size(32),
  >>)
}

pub fn encode_settings(
  ack ack: Bool,
  settings settings: List(Setting),
) -> Result(BitArray, FrameError) {
  use <- bool.guard(
    ack == True && settings != [],
    Error(ConnectionError(FrameSizeError)),
  )

  let encoded_settings = encode_settings_list(settings, <<>>)

  let length = bit_array.byte_size(encoded_settings)

  Ok(<<
    length:size(24),
    // frame type, 0x04 for SETTINGS
    0x04:size(8),
    // flags
    0:size(7),
    to_int(ack):size(1),
    // reserved bit
    0:size(1),
    // stream_id is always 0
    0:size(31),
    encoded_settings:bits,
  >>)
}

pub fn encode_push_promise(
  stream_id stream_id: Int,
  end_headers end_headers: Bool,
  promised_stream_id promised_stream_id: Int,
  field_block_fragment field_block_fragment: BitArray,
  padding padding: Option(Int),
) -> Result(BitArray, FrameError) {
  use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))
  use <- bool.guard(
    case padding {
      Some(p) -> p < 0 || p > 255
      None -> False
    },
    Error(InvalidPadding),
  )

  let #(padded, pad_length) = case padding {
    Some(pad_length) -> #(1, pad_length)
    None -> #(0, 0)
  }

  let length =
    bit_array.byte_size(field_block_fragment) + pad_length + 1 * padded + 4

  Ok(<<
    length:size(24),
    // frame type, 0x05 for PUSH_PROMISE
    0x05:size(8),
    // flags
    0:size(4),
    padded:size(1),
    to_int(end_headers):size(1),
    0:size(2),
    // end of flags
    // reserved bit
    0:size(1),
    stream_id:size(31),
    pad_length:size({ 8 * padded }),
    0:size(1),
    promised_stream_id:size(31),
    field_block_fragment:bits,
    0:size({ 8 * pad_length }),
  >>)
}

pub fn encode_ping(
  ack ack: Bool,
  data data: BitArray,
) -> Result(BitArray, FrameError) {
  use <- bool.guard(
    bit_array.byte_size(data) != 8,
    Error(ConnectionError(FrameSizeError)),
  )

  Ok(<<
    8:size(24),
    // frame type, 0x06 for PING
    0x06:size(8),
    // flags
    0:size(7),
    to_int(ack):size(1),
    // end of flags
    // reserved bit
    0:size(1),
    0:size(31),
    data:bits,
  >>)
}

pub fn encode_goaway(
  last_stream_id last_stream_id: Int,
  error_code error_code: ErrorCode,
  debug_data debug_data: BitArray,
) -> BitArray {
  let length = bit_array.byte_size(debug_data) + 8
  <<
    length:size(24),
    // frame type, 0x07 for GOAWAY
    0x07:size(8),
    // flags
    0:size(8),
    // end of flags
    // reserved bit
    0:size(1),
    0:size(31),
    0:size(1),
    last_stream_id:size(31),
    encode_error_code(error_code):size(32),
    debug_data:bits,
  >>
}

pub fn encode_window_update(
  stream_id stream_id: Int,
  window_size_increment window_size_increment: Int,
) -> Result(BitArray, FrameError) {
  use <- bool.guard(
    window_size_increment == 0,
    Error(ConnectionError(ProtocolError)),
  )

  Ok(<<
    4:size(24),
    // frame type, 0x08 for WINDOW_UPDATE
    0x08:size(8),
    // flags
    0:size(8),
    // end of flags
    // reserved bit
    0:size(1),
    stream_id:size(31),
    0:size(1),
    window_size_increment:size(31),
  >>)
}

pub fn encode_continuation(
  stream_id stream_id: Int,
  end_headers end_headers: Bool,
  field_block_fragment field_block_fragment: BitArray,
) -> Result(BitArray, FrameError) {
  use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))

  Ok(<<
    bit_array.byte_size(field_block_fragment):size(24),
    // frame type, 0x09 for CONTINUATION
    0x09:size(8),
    // flags
    0:size(5),
    to_int(end_headers):size(1),
    0:size(2),
    // end of flags
    // reserved bit
    0:size(1),
    stream_id:size(31),
    field_block_fragment:bits,
  >>)
}

pub fn encode_unknown(
  frame_type_code frame_type_code: Int,
  stream_id stream_id: Int,
  flags flags: Int,
  data data: BitArray,
) -> BitArray {
  <<
    bit_array.byte_size(data):size(24),
    frame_type_code:size(8),
    flags:size(8),
    0:size(1),
    stream_id:size(31),
    data:bits,
  >>
}
