import gleeunit/should
import h2o/frame/header.{FrameHeader}

pub fn parse_ping_header_test() {
  // 9-byte header: length=0, type=6 (PING), flags=0, stream_id=0
  let data = <<0:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31)>>

  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(length: 0, frame_type: header.Ping, flags: 0, stream_id: 0),
        <<>>,
      ),
    ),
  )
}

pub fn parse_too_short_header_test() {
  // 4-byte header, too short: length=0, type=6 (PING)
  let data = <<0:size(24), 6:size(8)>>

  header.parse_header(data)
  |> should.equal(Error(header.IncompleteHeader))
}

pub fn parse_data_header_test() {
  let data = <<0:size(24), 0:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(length: 0, frame_type: header.Data, flags: 0, stream_id: 0),
        <<>>,
      ),
    ),
  )
}

pub fn parse_headers_header_test() {
  let data = <<0:size(24), 1:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 0,
          frame_type: header.Headers,
          flags: 0,
          stream_id: 0,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_priority_header_test() {
  let data = <<0:size(24), 2:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 0,
          frame_type: header.Priority,
          flags: 0,
          stream_id: 0,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_rst_stream_header_test() {
  let data = <<0:size(24), 3:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 0,
          frame_type: header.RstStream,
          flags: 0,
          stream_id: 0,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_settings_header_test() {
  let data = <<0:size(24), 4:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 0,
          frame_type: header.Settings,
          flags: 0,
          stream_id: 0,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_header_test() {
  let data = <<0:size(24), 5:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 0,
          frame_type: header.PushPromise,
          flags: 0,
          stream_id: 0,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_header_test() {
  let data = <<0:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 0,
          frame_type: header.GoAway,
          flags: 0,
          stream_id: 0,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_window_update_header_test() {
  let data = <<0:size(24), 8:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 0,
          frame_type: header.WindowUpdate,
          flags: 0,
          stream_id: 0,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_continuation_header_test() {
  let data = <<0:size(24), 9:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 0,
          frame_type: header.Continuation,
          flags: 0,
          stream_id: 0,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_header_with_length_test() {
  // PING header with length=100
  let data = <<100:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 100,
          frame_type: header.Ping,
          flags: 0,
          stream_id: 0,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_header_with_flags_test() {
  // PING header with ACK flag (0x01)
  let data = <<0:size(24), 6:size(8), 1:size(8), 0:size(1), 0:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 0,
          frame_type: header.Ping,
          flags: 1,
          stream_id: 0,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_header_with_stream_id_test() {
  // DATA header on stream 5
  let data = <<0:size(24), 0:size(8), 0:size(8), 0:size(1), 5:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 0,
          frame_type: header.Data,
          flags: 0,
          stream_id: 5,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_header_with_all_fields_test() {
  // HEADERS frame: length=256, flags=0x05 (END_STREAM | END_HEADERS), stream 7
  let data = <<256:size(24), 1:size(8), 5:size(8), 0:size(1), 7:size(31)>>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 256,
          frame_type: header.Headers,
          flags: 5,
          stream_id: 7,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_header_with_trailing_payload_test() {
  // PING header followed by 8 bytes of payload
  let data = <<
    8:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31), 0, 0, 0, 0, 0, 0,
    0, 0,
  >>
  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 8,
          frame_type: header.Ping,
          flags: 0,
          stream_id: 0,
        ),
        <<0, 0, 0, 0, 0, 0, 0, 0>>,
      ),
    ),
  )
}

pub fn parse_unknown_frame_type_test() {
  // 9-byte header: length=0, type=255 (which is not known), flags=0, stream_id=0
  let data = <<0:size(24), 255:size(8), 0:size(8), 0:size(1), 0:size(31)>>

  header.parse_header(data)
  |> should.equal(
    Ok(
      #(
        FrameHeader(
          length: 0,
          frame_type: header.Unknown(255),
          flags: 0,
          stream_id: 0,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn encode_ping_header_test() {
  let header =
    FrameHeader(length: 0, frame_type: header.Ping, flags: 0, stream_id: 0)
  header.encode_header(header)
  |> should.equal(<<0:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31)>>)
}

pub fn encode_header_with_all_fields_test() {
  let header =
    FrameHeader(
      length: 256,
      frame_type: header.Headers,
      flags: 5,
      stream_id: 7,
    )
  header.encode_header(header)
  |> should.equal(<<
    256:size(24), 1:size(8), 5:size(8), 0:size(1), 7:size(31),
  >>)
}

pub fn encode_unknown_frame_type_test() {
  let header =
    FrameHeader(
      length: 0,
      frame_type: header.Unknown(255),
      flags: 0,
      stream_id: 0,
    )
  header.encode_header(header)
  |> should.equal(<<
    0:size(24), 255:size(8), 0:size(8), 0:size(1), 0:size(31),
  >>)
}
