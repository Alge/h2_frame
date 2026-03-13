import gleam/bit_array
import gleam/bool
import gleam/int
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

pub type FrameType {
  DataFrame
  HeadersFrame
  PriorityFrame
  RstStreamFrame
  SettingsFrame
  PushPromiseFrame
  PingFrame
  GoAwayFrame
  WindowUpdateFrame
  ContinuationFrame
  UnknownFrame(Int)
}

pub type FrameHeader {
  FrameHeader(length: Int, frame_type: FrameType, flags: Int, stream_id: Int)
}

pub type HeaderError {
  IncompleteHeader
}

fn parse_frame_type(code: Int) -> FrameType {
  case code {
    0 -> DataFrame
    1 -> HeadersFrame
    2 -> PriorityFrame
    3 -> RstStreamFrame
    4 -> SettingsFrame
    5 -> PushPromiseFrame
    6 -> PingFrame
    7 -> GoAwayFrame
    8 -> WindowUpdateFrame
    9 -> ContinuationFrame
    _ -> UnknownFrame(code)
  }
}

fn encode_frame_type(frame_type: FrameType) -> Int {
  case frame_type {
    DataFrame -> 0
    HeadersFrame -> 1
    PriorityFrame -> 2
    RstStreamFrame -> 3
    SettingsFrame -> 4
    PushPromiseFrame -> 5
    PingFrame -> 6
    GoAwayFrame -> 7
    WindowUpdateFrame -> 8
    ContinuationFrame -> 9
    UnknownFrame(code) -> code
  }
}

pub fn encode_header(header: FrameHeader) -> BitArray {
  <<
    header.length:size(24),
    encode_frame_type(header.frame_type):size(8),
    header.flags:size(8),
    0:size(1),
    header.stream_id:size(31),
  >>
}

/// Parses a 9-byte HTTP/2 frame header from binary data.
/// Returns the frame header and any remaining bytes after it.
pub fn parse_header(
  data: BitArray,
) -> Result(#(FrameHeader, BitArray), HeaderError) {
  case data {
    <<
      length:size(24),
      type_code:size(8),
      flags:size(8),
      _reserved:size(1),
      stream_id:size(31),
      rest:bits,
    >> -> {
      Ok(#(
        FrameHeader(
          length: length,
          frame_type: parse_frame_type(type_code),
          flags: flags,
          stream_id: stream_id,
        ),
        rest,
      ))
    }
    _ -> Error(IncompleteHeader)
  }
}

pub type FrameError {
  HeaderError(HeaderError)
  ConnectionError(ErrorCode)
  IncompletePayload
  InvalidPadding
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

fn parse_settings(
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

      parse_settings(rest, [setting, ..settings])
    }

    _ -> Error(IncompletePayload)
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

pub type Payload {
  Data(end_stream: Bool, data: BitArray)
  Headers(
    end_stream: Bool,
    end_headers: Bool,
    priority: Option(StreamPriority),
    data: BitArray,
  )
  Priority(exclusive: Bool, stream_dependency: Int, weight: Int)
  RstStream(error_code: ErrorCode)
  Settings(ack: Bool, settings: List(Setting))
  PushPromise(end_headers: Bool, promised_stream_id: Int, data: BitArray)
  Ping(ack: Bool, data: BitArray)
  GoAway(last_stream_id: Int, error_code: ErrorCode, debug_data: BitArray)
  WindowUpdate(window_size_increment: Int)
  Continuation(end_headers: Bool, data: BitArray)
  Unknown(data: BitArray)
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

fn parse_data_payload(
  frame_header: FrameHeader,
  payload: BitArray,
) -> Result(#(Payload, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id == 0,
    Error(ConnectionError(ProtocolError)),
  )
  let length = frame_header.length

  let padded = int.bitwise_and(frame_header.flags, 0x08) == 0x08
  let end_stream = int.bitwise_and(frame_header.flags, 0x01) == 0x01

  use #(payload, pad_length) <- result.try(case padded {
    True -> {
      case payload {
        <<pad_length:size(8), payload:bits>> -> Ok(#(payload, pad_length))
        _ -> Error(IncompletePayload)
      }
    }
    False -> Ok(#(payload, 0))
  })

  let data_length =
    length
    - pad_length
    - case padded {
      True -> 1
      False -> 0
    }

  use <- bool.guard(
    data_length < 0,
    Error(ConnectionError(ProtocolError)),
  )

  case payload {
    <<data:bytes-size(data_length), _padding:bytes-size(pad_length), rest:bits>> -> {
      Ok(#(Data(end_stream, data), rest))
    }

    _ -> Error(IncompletePayload)
  }
}

fn parse_headers_payload(
  frame_header: FrameHeader,
  payload: BitArray,
) -> Result(#(Payload, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id == 0,
    Error(ConnectionError(ProtocolError)),
  )

  let length = frame_header.length

  let end_stream = int.bitwise_and(frame_header.flags, 0x01) == 0x01
  let end_headers = int.bitwise_and(frame_header.flags, 0x04) == 0x04
  let padded = int.bitwise_and(frame_header.flags, 0x08) == 0x08
  let has_priority = int.bitwise_and(frame_header.flags, 0x20) == 0x20

  use #(payload, pad_length) <- result.try(case padded {
    True -> {
      case payload {
        <<pad_length:size(8), payload:bits>> -> Ok(#(payload, pad_length))
        _ -> Error(IncompletePayload)
      }
    }
    False -> Ok(#(payload, 0))
  })

  use #(payload, priority) <- result.try(case has_priority {
    True -> {
      case payload {
        <<
          exclusive_bit:size(1),
          stream_dependency:size(31),
          weight:size(8),
          rest:bits,
        >> -> {
          let exclusive = exclusive_bit == 1
          Ok(#(
            rest,
            Some(StreamPriority(
              exclusive: exclusive,
              stream_dependency: stream_dependency,
              weight: weight,
            )),
          ))
        }

        _ -> Error(IncompletePayload)
      }
    }
    False -> Ok(#(payload, None))
  })

  let data_length =
    length
    - pad_length
    - case padded {
      True -> 1
      False -> 0
    }
    - case has_priority {
      True -> 5
      False -> 0
    }

  use <- bool.guard(
    data_length < 0,
    Error(ConnectionError(ProtocolError)),
  )

  case payload {
    <<data:bytes-size(data_length), _padding:bytes-size(pad_length), rest:bits>> -> {
      Ok(#(
        Headers(
          end_stream: end_stream,
          end_headers: end_headers,
          priority: priority,
          data: data,
        ),
        rest,
      ))
    }

    _ -> Error(IncompletePayload)
  }
}

fn parse_priority_payload(
  frame_header: FrameHeader,
  payload: BitArray,
) -> Result(#(Payload, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id == 0,
    Error(ConnectionError(ProtocolError)),
  )
  use <- bool.guard(
    frame_header.length != 5,
    Error(ConnectionError(FrameSizeError)),
  )

  case payload {
    <<
      exclusive_bit:size(1),
      stream_dependency:size(31),
      weight:size(8),
      rest:bits,
    >> -> {
      let exclusive = exclusive_bit == 1
      Ok(#(
        Priority(
          exclusive: exclusive,
          stream_dependency: stream_dependency,
          weight: weight,
        ),
        rest,
      ))
    }
    _ -> Error(IncompletePayload)
  }
}

fn parse_rst_stream_payload(
  frame_header: FrameHeader,
  payload: BitArray,
) -> Result(#(Payload, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id == 0,
    Error(ConnectionError(ProtocolError)),
  )

  use <- bool.guard(
    frame_header.length != 4,
    Error(ConnectionError(FrameSizeError)),
  )

  case payload {
    <<error_code:size(32), rest:bits>> -> {
      Ok(#(RstStream(error_code: parse_error_code(error_code)), rest))
    }
    _ -> Error(IncompletePayload)
  }
}

fn parse_settings_payload(
  frame_header: FrameHeader,
  payload: BitArray,
) -> Result(#(Payload, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id != 0,
    Error(ConnectionError(ProtocolError)),
  )

  use <- bool.guard(
    frame_header.length % 6 != 0,
    Error(ConnectionError(FrameSizeError)),
  )

  let ack = int.bitwise_and(frame_header.flags, 0x01) == 0x01

  use <- bool.guard(
    frame_header.length != 0 && ack,
    Error(ConnectionError(FrameSizeError)),
  )

  let length = frame_header.length

  case payload {
    <<payload:bytes-size(length), rest:bits>> -> {
      use settings <- result.try(parse_settings(payload, []))
      Ok(#(Settings(ack: ack, settings: settings), rest))
    }
    _ -> Error(IncompletePayload)
  }
}

fn parse_push_promise_payload(
  frame_header: FrameHeader,
  payload: BitArray,
) -> Result(#(Payload, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id == 0,
    Error(ConnectionError(ProtocolError)),
  )
  let length = frame_header.length

  let end_headers = int.bitwise_and(frame_header.flags, 0x04) == 0x04
  let padded = int.bitwise_and(frame_header.flags, 0x08) == 0x08

  use #(payload, pad_length) <- result.try(case padded {
    True -> {
      case payload {
        <<pad_length:size(8), payload:bits>> -> Ok(#(payload, pad_length))
        _ -> Error(IncompletePayload)
      }
    }
    False -> Ok(#(payload, 0))
  })

  let data_length =
    length
    - pad_length
    - case padded {
      True -> 1
      False -> 0
    }
    - 4

  use <- bool.guard(
    data_length < 0,
    Error(ConnectionError(ProtocolError)),
  )

  case payload {
    <<
      _reserved:size(1),
      promised_stream_id:size(31),
      data:bytes-size(data_length),
      _padding:bytes-size(pad_length),
      rest:bits,
    >> -> {
      Ok(#(
        PushPromise(
          end_headers: end_headers,
          promised_stream_id: promised_stream_id,
          data: data,
        ),
        rest,
      ))
    }
    _ -> Error(IncompletePayload)
  }
}

fn parse_ping_payload(
  frame_header: FrameHeader,
  payload: BitArray,
) -> Result(#(Payload, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id != 0,
    Error(ConnectionError(ProtocolError)),
  )

  // Make sure the length reported in header is 8 bytes
  use <- bool.guard(
    frame_header.length != 8,
    Error(ConnectionError(FrameSizeError)),
  )

  case payload {
    <<data:bytes-size(8), rest:bits>> -> {
      let ack = int.bitwise_and(frame_header.flags, 0x01) == 0x01
      Ok(#(Ping(ack: ack, data: data), rest))
    }

    _ -> Error(IncompletePayload)
  }
}

fn parse_go_away_payload(
  frame_header: FrameHeader,
  payload: BitArray,
) -> Result(#(Payload, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id != 0,
    Error(ConnectionError(ProtocolError)),
  )

  use <- bool.guard(
    frame_header.length < 8,
    Error(ConnectionError(FrameSizeError)),
  )

  let debug_data_length = frame_header.length - 8

  case payload {
    <<
      _reserved:size(1),
      last_stream_id:size(31),
      error_code:size(32),
      debug_data:bytes-size(debug_data_length),
      rest:bits,
    >> -> {
      Ok(#(
        GoAway(
          last_stream_id: last_stream_id,
          error_code: parse_error_code(error_code),
          debug_data: debug_data,
        ),
        rest,
      ))
    }

    _ -> Error(IncompletePayload)
  }
}

fn parse_window_update_payload(
  frame_header: FrameHeader,
  payload: BitArray,
) -> Result(#(Payload, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.length != 4,
    Error(ConnectionError(FrameSizeError)),
  )

  case payload {
    <<_reserved:size(1), window_size_increment:size(31), rest:bits>> -> {
      use <- bool.guard(
        window_size_increment == 0,
        Error(ConnectionError(ProtocolError)),
      )

      Ok(#(WindowUpdate(window_size_increment: window_size_increment), rest))
    }
    _ -> Error(IncompletePayload)
  }
}

fn parse_continuation_payload(
  frame_header: FrameHeader,
  payload: BitArray,
) -> Result(#(Payload, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id == 0,
    Error(ConnectionError(ProtocolError)),
  )

  let end_headers = int.bitwise_and(frame_header.flags, 0x04) == 0x04

  let length = frame_header.length

  case payload {
    <<data:bytes-size(length), rest:bits>> -> {
      Ok(#(Continuation(end_headers: end_headers, data: data), rest))
    }
    _ -> Error(IncompletePayload)
  }
}

fn parse_unknown_payload(
  frame_header: FrameHeader,
  payload: BitArray,
) -> Result(#(Payload, BitArray), FrameError) {
  let length = frame_header.length

  case payload {
    <<data:bytes-size(length), rest:bits>> -> {
      Ok(#(Unknown(data: data), rest))
    }
    _ -> Error(IncompletePayload)
  }
}

/// Parses a frame payload given an already-parsed frame header.
/// Returns the decoded payload and any remaining bytes after the frame.
pub fn parse_payload(
  frame_header: FrameHeader,
  data: BitArray,
) -> Result(#(Payload, BitArray), FrameError) {
  case frame_header.frame_type {
    DataFrame -> parse_data_payload(frame_header, data)
    HeadersFrame -> parse_headers_payload(frame_header, data)
    PriorityFrame -> parse_priority_payload(frame_header, data)
    RstStreamFrame -> parse_rst_stream_payload(frame_header, data)
    SettingsFrame -> parse_settings_payload(frame_header, data)
    PushPromiseFrame -> parse_push_promise_payload(frame_header, data)
    PingFrame -> parse_ping_payload(frame_header, data)
    GoAwayFrame -> parse_go_away_payload(frame_header, data)
    WindowUpdateFrame -> parse_window_update_payload(frame_header, data)
    ContinuationFrame -> parse_continuation_payload(frame_header, data)
    UnknownFrame(_code) -> parse_unknown_payload(frame_header, data)
  }
}

/// Parses a complete HTTP/2 frame from binary data.
/// Returns the frame header, payload, and any remaining bytes
/// that follow the frame.
pub fn parse(
  data: BitArray,
) -> Result(#(FrameHeader, Payload, BitArray), FrameError) {
  use #(frame_header, remainder) <- result.try(
    parse_header(data)
    |> result.map_error(HeaderError),
  )

  use #(payload, rest) <- result.try(parse_payload(frame_header, remainder))

  Ok(#(frame_header, payload, rest))
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
    Some(pad_length) -> #(True, pad_length)
    None -> #(False, 0)
  }

  let length = bit_array.byte_size(data)

  let length = case padded {
    True -> length + pad_length + 1
    False -> length
  }

  let flags = 0

  let flags = case end_stream {
    True -> int.bitwise_or(flags, 0x01)
    False -> flags
  }

  let flags = case padded {
    True -> int.bitwise_or(flags, 0x08)
    False -> flags
  }

  let frame_header =
    FrameHeader(
      length: length,
      flags: flags,
      frame_type: DataFrame,
      stream_id: stream_id,
    )

  let encoded_data = <<encode_header(frame_header):bits>>

  let encoded_data = case padded {
    True -> <<encoded_data:bits, pad_length:size(8)>>
    False -> encoded_data
  }

  let encoded_data = <<encoded_data:bits, data:bits>>

  case padded {
    True -> Ok(<<encoded_data:bits, 0:size({ pad_length * 8 })>>)
    False -> Ok(encoded_data)
  }
}

pub fn encode_headers(
  stream_id stream_id: Int,
  end_stream end_stream: Bool,
  end_headers end_headers: Bool,
  priority priority: Option(StreamPriority),
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
    Some(pad_length) -> #(True, pad_length)
    None -> #(False, 0)
  }

  let length = bit_array.byte_size(data)

  let length = case padded {
    True -> length + pad_length + 1
    False -> length
  }

  let length = case priority {
    Some(_) -> length + 5
    None -> length
  }

  let flags = 0

  let flags = case end_stream {
    True -> int.bitwise_or(flags, 0x01)
    False -> flags
  }

  let flags = case end_headers {
    True -> int.bitwise_or(flags, 0x04)
    False -> flags
  }

  let flags = case padded {
    True -> int.bitwise_or(flags, 0x08)
    False -> flags
  }

  let flags = case priority {
    Some(_) -> int.bitwise_or(flags, 0x20)
    None -> flags
  }

  let frame_header =
    FrameHeader(
      length: length,
      frame_type: HeadersFrame,
      flags: flags,
      stream_id: stream_id,
    )

  let encoded_data = <<encode_header(frame_header):bits>>

  let encoded_data = case padded {
    True -> <<encoded_data:bits, pad_length:size(8)>>
    False -> encoded_data
  }

  let encoded_data = case priority {
    Some(priority) -> <<
      encoded_data:bits,
      encode_stream_priority(priority):bits,
    >>
    None -> encoded_data
  }

  let encoded_data = <<encoded_data:bits, data:bits>>

  case padded {
    True -> Ok(<<encoded_data:bits, 0:size({ pad_length * 8 })>>)
    False -> Ok(encoded_data)
  }
}

pub fn encode_priority(
  stream_id stream_id: Int,
  exclusive exclusive: Bool,
  stream_dependency stream_dependency: Int,
  weight weight: Int,
) -> Result(BitArray, FrameError) {
  use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))

  let length = 5

  let flags = 0

  let frame_header =
    FrameHeader(
      length: length,
      frame_type: PriorityFrame,
      flags: flags,
      stream_id: stream_id,
    )

  let stream_priority =
    StreamPriority(
      exclusive: exclusive,
      stream_dependency: stream_dependency,
      weight: weight,
    )

  Ok(<<
    encode_header(frame_header):bits,
    encode_stream_priority(stream_priority):bits,
  >>)
}

pub fn encode_rst_stream(
  stream_id stream_id: Int,
  error_code error_code: ErrorCode,
) -> Result(BitArray, FrameError) {
  use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))

  let length = 4

  let flags = 0

  let frame_header =
    FrameHeader(
      length: length,
      frame_type: RstStreamFrame,
      flags: flags,
      stream_id: stream_id,
    )

  Ok(<<
    encode_header(frame_header):bits,
    encode_error_code(error_code):size(32),
  >>)
}

pub fn encode_settings(
  ack ack: Bool,
  settings settings: List(Setting),
) -> Result(BitArray, FrameError) {
  use <- bool.guard(
    ack == True && settings != [],
    Error(ConnectionError(ProtocolError)),
  )

  let stream_id = 0

  let flags = 0

  let flags = case ack {
    True -> int.bitwise_or(flags, 0x01)
    False -> flags
  }

  let encoded_settings = encode_settings_list(settings, <<>>)

  let length = bit_array.byte_size(encoded_settings)

  let frame_header =
    FrameHeader(
      length: length,
      frame_type: SettingsFrame,
      flags: flags,
      stream_id: stream_id,
    )

  Ok(<<encode_header(frame_header):bits, encoded_settings:bits>>)
}

pub fn encode_push_promise(
  stream_id stream_id: Int,
  end_headers end_headers: Bool,
  promised_stream_id promised_stream_id: Int,
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
    Some(pad_length) -> #(True, pad_length)
    None -> #(False, 0)
  }

  let length = 4 + bit_array.byte_size(data)

  let length = case padded {
    True -> length + pad_length + 1
    False -> length
  }

  let flags = 0

  let flags = case end_headers {
    True -> int.bitwise_or(flags, 0x04)
    False -> flags
  }

  let flags = case padded {
    True -> int.bitwise_or(flags, 0x08)
    False -> flags
  }

  let frame_header =
    FrameHeader(
      length: length,
      flags: flags,
      frame_type: PushPromiseFrame,
      stream_id: stream_id,
    )

  let encoded_data = <<encode_header(frame_header):bits>>

  let encoded_data = case padded {
    True -> <<encoded_data:bits, pad_length:size(8)>>
    False -> encoded_data
  }

  let encoded_data = <<
    encoded_data:bits,
    0:size(1),
    promised_stream_id:size(31),
  >>

  let encoded_data = <<encoded_data:bits, data:bits>>

  case padded {
    True -> Ok(<<encoded_data:bits, 0:size({ pad_length * 8 })>>)
    False -> Ok(encoded_data)
  }
}

pub fn encode_ping(
  ack ack: Bool,
  data data: BitArray,
) -> Result(BitArray, FrameError) {
  use <- bool.guard(
    bit_array.byte_size(data) != 8,
    Error(ConnectionError(ProtocolError)),
  )

  let stream_id = 0

  let length = 8

  let flags = 0

  let flags = case ack {
    True -> int.bitwise_or(flags, 0x01)
    False -> flags
  }

  let frame_header =
    FrameHeader(
      length: length,
      flags: flags,
      frame_type: PingFrame,
      stream_id: stream_id,
    )

  Ok(<<encode_header(frame_header):bits, data:bits>>)
}

pub fn encode_goaway(
  last_stream_id last_stream_id: Int,
  error_code error_code: ErrorCode,
  debug_data debug_data: BitArray,
) -> BitArray {
  let stream_id = 0

  let length = 8 + bit_array.byte_size(debug_data)

  let flags = 0

  let frame_header =
    FrameHeader(
      length: length,
      flags: flags,
      frame_type: GoAwayFrame,
      stream_id: stream_id,
    )

  <<
    encode_header(frame_header):bits,
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

  let length = 4

  let flags = 0

  let frame_header =
    FrameHeader(
      length: length,
      flags: flags,
      frame_type: WindowUpdateFrame,
      stream_id: stream_id,
    )

  Ok(<<
    encode_header(frame_header):bits,
    0:size(1),
    window_size_increment:size(31),
  >>)
}

pub fn encode_continuation(
  stream_id stream_id: Int,
  end_headers end_headers: Bool,
  data data: BitArray,
) -> Result(BitArray, FrameError) {
  use <- bool.guard(stream_id == 0, Error(ConnectionError(ProtocolError)))

  let length = bit_array.byte_size(data)

  let flags = 0

  let flags = case end_headers {
    True -> int.bitwise_or(flags, 0x04)
    False -> flags
  }

  let frame_header =
    FrameHeader(
      length: length,
      flags: flags,
      frame_type: ContinuationFrame,
      stream_id: stream_id,
    )

  Ok(<<encode_header(frame_header):bits, data:bits>>)
}

pub fn encode_unknown(
  frame_type_code frame_type_code: Int,
  stream_id stream_id: Int,
  flags flags: Int,
  data data: BitArray,
) -> BitArray {
  // Maybe shouldn't return a Error? Or maybe for symetry?
  let length = bit_array.byte_size(data)

  let frame_header =
    FrameHeader(
      length: length,
      flags: flags,
      frame_type: UnknownFrame(frame_type_code),
      stream_id: stream_id,
    )

  <<encode_header(frame_header):bits, data:bits>>
}
