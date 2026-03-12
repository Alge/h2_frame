pub type FrameType {
  Data
  Headers
  Priority
  RstStream
  Settings
  PushPromise
  Ping
  GoAway
  WindowUpdate
  Continuation
  Unknown(Int)
}

pub type FrameHeader {
  FrameHeader(length: Int, frame_type: FrameType, flags: Int, stream_id: Int)
}

pub type HeaderError {
  IncompleteHeader
}

fn parse_frame_type(code: Int) -> FrameType {
  case code {
    0 -> Data
    1 -> Headers
    2 -> Priority
    3 -> RstStream
    4 -> Settings
    5 -> PushPromise
    6 -> Ping
    7 -> GoAway
    8 -> WindowUpdate
    9 -> Continuation
    _ -> Unknown(code)
  }
}

fn encode_frame_type(frame_type: FrameType) -> Int {
  case frame_type {
    Data -> 0
    Headers -> 1
    Priority -> 2
    RstStream -> 3
    Settings -> 4
    PushPromise -> 5
    Ping -> 6
    GoAway -> 7
    WindowUpdate -> 8
    Continuation -> 9
    Unknown(code) -> code
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
