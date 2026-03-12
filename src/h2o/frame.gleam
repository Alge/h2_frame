import gleam/bool
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import h2o/frame/error
import h2o/frame/header

pub type FrameError {
  HeaderError(header.HeaderError)
  ConnectionError(error.ErrorCode)
  IncompletePayload
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

pub type Frame {
  DataFrame(header: header.FrameHeader, end_stream: Bool, data: BitArray)
  HeadersFrame(
    header: header.FrameHeader,
    end_stream: Bool,
    end_headers: Bool,
    priority: Option(Priority),
    data: BitArray,
  )
  PriorityFrame(
    header: header.FrameHeader,
    exclusive: Bool,
    stream_dependency: Int,
    weight: Int,
  )
  RstStreamFrame(header: header.FrameHeader, error_code: error.ErrorCode)
  SettingsFrame(header: header.FrameHeader, ack: Bool, settings: List(Setting))
  PushPromiseFrame(
    header: header.FrameHeader,
    end_headers: Bool,
    promised_stream_id: Int,
    data: BitArray,
  )
  PingFrame(header: header.FrameHeader, ack: Bool, data: BitArray)
  GoAwayFrame(
    header: header.FrameHeader,
    last_stream_id: Int,
    error_code: error.ErrorCode,
    debug_data: BitArray,
  )
  WindowUpdateFrame(header: header.FrameHeader, window_size_increment: Int)
  ContinuationFrame(
    header: header.FrameHeader,
    end_headers: Bool,
    data: BitArray,
  )
  UnknownFrame(
    header: header.FrameHeader,
    data: BitArray,
  )
}

pub type Priority {
  Priority(exclusive: Bool, stream_dependency: Int, weight: Int)
}

fn parse_data_frame(
  frame_header: header.FrameHeader,
  payload: BitArray,
) -> Result(#(Frame, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id == 0,
    Error(ConnectionError(error.ProtocolError)),
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
    Error(ConnectionError(error.ProtocolError)),
  )

  case payload {
    <<data:bytes-size(data_length), _padding:bytes-size(pad_length), rest:bits>> -> {
      Ok(#(DataFrame(frame_header, end_stream, data), rest))
    }

    _ -> Error(IncompletePayload)
  }
}

fn parse_headers_frame(
  frame_header: header.FrameHeader,
  payload: BitArray,
) -> Result(#(Frame, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id == 0,
    Error(ConnectionError(error.ProtocolError)),
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
            Some(Priority(
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
    Error(ConnectionError(error.ProtocolError)),
  )

  case payload {
    <<data:bytes-size(data_length), _padding:bytes-size(pad_length), rest:bits>> -> {
      Ok(#(
        HeadersFrame(
          header: frame_header,
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

fn parse_priority_frame(
  frame_header: header.FrameHeader,
  payload: BitArray,
) -> Result(#(Frame, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id == 0,
    Error(ConnectionError(error.ProtocolError)),
  )
  use <- bool.guard(
    frame_header.length != 5,
    Error(ConnectionError(error.FrameSizeError)),
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
        PriorityFrame(
          header: frame_header,
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

fn parse_reset_stream_frame(
  frame_header: header.FrameHeader,
  payload: BitArray,
) -> Result(#(Frame, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id == 0,
    Error(ConnectionError(error.ProtocolError)),
  )

  use <- bool.guard(
    frame_header.length != 4,
    Error(ConnectionError(error.FrameSizeError)),
  )

  case payload {
    <<error_code:size(32), rest:bits>> -> {
      Ok(#(
        RstStreamFrame(
          header: frame_header,
          error_code: error.parse_error_code(error_code),
        ),
        rest,
      ))
    }
    _ -> Error(IncompletePayload)
  }
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

fn parse_settings_frame(
  frame_header: header.FrameHeader,
  payload: BitArray,
) -> Result(#(Frame, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id != 0,
    Error(ConnectionError(error.ProtocolError)),
  )

  use <- bool.guard(
    frame_header.length % 6 != 0,
    Error(ConnectionError(error.FrameSizeError)),
  )

  let ack = int.bitwise_and(frame_header.flags, 0x01) == 0x01

  use <- bool.guard(
    frame_header.length != 0 && ack,
    Error(ConnectionError(error.FrameSizeError)),
  )

  let length = frame_header.length

  case payload {
    <<payload:bytes-size(length), rest:bits>> -> {
      use settings <- result.try(parse_settings(payload, []))
      Ok(#(
        SettingsFrame(header: frame_header, ack: ack, settings: settings),
        rest,
      ))
    }
    _ -> Error(IncompletePayload)
  }
}

fn parse_push_promise_frame(
  frame_header: header.FrameHeader,
  payload: BitArray,
) -> Result(#(Frame, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id == 0,
    Error(ConnectionError(error.ProtocolError)),
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
    Error(ConnectionError(error.ProtocolError)),
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
        PushPromiseFrame(
          header: frame_header,
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

fn parse_ping_frame(
  frame_header: header.FrameHeader,
  payload: BitArray,
) -> Result(#(Frame, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id != 0,
    Error(ConnectionError(error.ProtocolError)),
  )

  // Make sure the length reported in header is 8 bytes
  use <- bool.guard(
    frame_header.length != 8,
    Error(ConnectionError(error.FrameSizeError)),
  )

  case payload {
    <<data:bytes-size(8), rest:bits>> -> {
      let ack = int.bitwise_and(frame_header.flags, 0x01) == 0x01
      Ok(#(PingFrame(header: frame_header, ack: ack, data: data), rest))
    }

    _ -> Error(IncompletePayload)
  }
}

fn parse_go_away_frame(
  frame_header: header.FrameHeader,
  payload: BitArray,
) -> Result(#(Frame, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id != 0,
    Error(ConnectionError(error.ProtocolError)),
  )

  use <- bool.guard(
    frame_header.length < 8,
    Error(ConnectionError(error.ProtocolError)),
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
        GoAwayFrame(
          header: frame_header,
          last_stream_id: last_stream_id,
          error_code: error.parse_error_code(error_code),
          debug_data: debug_data,
        ),
        rest,
      ))
    }

    _ -> Error(IncompletePayload)
  }
}

fn parse_window_update_frame(
  frame_header: header.FrameHeader,
  payload: BitArray,
) -> Result(#(Frame, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.length != 4,
    Error(ConnectionError(error.FrameSizeError)),
  )

  case payload {
    <<_reserved:size(1), window_size_increment:size(31), rest:bits>> -> {
      use <- bool.guard(
        window_size_increment <= 0,
        Error(ConnectionError(error.ProtocolError)),
      )

      Ok(#(
        WindowUpdateFrame(
          header: frame_header,
          window_size_increment: window_size_increment,
        ),
        rest,
      ))
    }
    _ -> Error(IncompletePayload)
  }
}

fn parse_continuation_frame(
  frame_header: header.FrameHeader,
  payload: BitArray,
) -> Result(#(Frame, BitArray), FrameError) {
  use <- bool.guard(
    frame_header.stream_id == 0,
    Error(ConnectionError(error.ProtocolError)),
  )

  let end_headers = int.bitwise_and(frame_header.flags, 0x04) == 0x04

  let length = frame_header.length

  case payload {
    <<data:bytes-size(length), rest:bits>> -> {
      Ok(#(
        ContinuationFrame(
          header: frame_header,
          end_headers: end_headers,
          data: data,
        ),
        rest,
      ))
    }
    _ -> Error(IncompletePayload)
  }
}

fn parse_unknown_frame(
  frame_header: header.FrameHeader,
  payload: BitArray,
) -> Result(#(Frame, BitArray), FrameError) {
  let length = frame_header.length

  case payload {
    <<data:bytes-size(length), rest:bits>> -> {
      Ok(#(
        UnknownFrame(
          header: frame_header,
          data: data,
        ),
        rest,
      ))
    }
    _ -> Error(IncompletePayload)
  }
}

pub fn parse(data: BitArray) -> Result(#(Frame, BitArray), FrameError) {
  use #(frame_header, remainder) <- result.try(
    header.parse_header(data)
    |> result.map_error(HeaderError),
  )

  case frame_header.frame_type {
    header.Data -> parse_data_frame(frame_header, remainder)
    header.Headers -> parse_headers_frame(frame_header, remainder)
    header.Priority -> parse_priority_frame(frame_header, remainder)
    header.RstStream -> parse_reset_stream_frame(frame_header, remainder)
    header.Settings -> parse_settings_frame(frame_header, remainder)
    header.PushPromise -> parse_push_promise_frame(frame_header, remainder)
    header.Ping -> parse_ping_frame(frame_header, remainder)
    header.GoAway -> parse_go_away_frame(frame_header, remainder)
    header.WindowUpdate -> parse_window_update_frame(frame_header, remainder)
    header.Continuation -> parse_continuation_frame(frame_header, remainder)
    header.Unknown(_code) -> parse_unknown_frame(frame_header, remainder)
  }
}
