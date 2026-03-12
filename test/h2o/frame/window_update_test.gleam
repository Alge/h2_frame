import gleeunit/should
import h2o/frame
import h2o/frame/error
import h2o/frame/header.{FrameHeader}

pub fn parse_window_update_test() {
  // RFC 9113 Section 6.9: Basic WINDOW_UPDATE on a stream
  let data = <<
    4:size(24), 8:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    1000:size(31),
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.WindowUpdateFrame(
          header: FrameHeader(
            length: 4,
            frame_type: header.WindowUpdate,
            flags: 0,
            stream_id: 1,
          ),
          window_size_increment: 1000,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_window_update_connection_test() {
  // RFC 9113 Section 6.9: WINDOW_UPDATE on connection (stream_id=0 is valid)
  let data = <<
    4:size(24), 8:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    65_535:size(31),
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.WindowUpdateFrame(
          header: FrameHeader(
            length: 4,
            frame_type: header.WindowUpdate,
            flags: 0,
            stream_id: 0,
          ),
          window_size_increment: 65_535,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_window_update_max_increment_test() {
  // RFC 9113 Section 6.9: Maximum window size increment 2^31-1
  let data = <<
    4:size(24), 8:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    2_147_483_647:size(31),
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.WindowUpdateFrame(
          header: FrameHeader(
            length: 4,
            frame_type: header.WindowUpdate,
            flags: 0,
            stream_id: 1,
          ),
          window_size_increment: 2_147_483_647,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_window_update_zero_increment_stream_test() {
  // RFC 9113 Section 6.9: Increment of 0 on a stream MUST be treated as
  // stream error PROTOCOL_ERROR. We report as ConnectionError since we have no stream context.
  let data = <<
    4:size(24), 8:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    0:size(31),
  >>
  frame.parse(data)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_window_update_zero_increment_connection_test() {
  // RFC 9113 Section 6.9: Increment of 0 on connection MUST be treated as
  // connection error PROTOCOL_ERROR
  let data = <<
    4:size(24), 8:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    0:size(31),
  >>
  frame.parse(data)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_window_update_wrong_length_short_test() {
  // RFC 9113 Section 6.9: Length other than 4 MUST be treated as connection error FRAME_SIZE_ERROR
  let data = <<
    3:size(24), 8:size(8), 0:size(8), 0:size(1), 1:size(31), 0, 0, 0,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.ConnectionError(error.FrameSizeError)))
}

pub fn parse_window_update_wrong_length_long_test() {
  // RFC 9113 Section 6.9: Length greater than 4 is also FRAME_SIZE_ERROR
  let data = <<
    5:size(24), 8:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    1000:size(31), 0,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.ConnectionError(error.FrameSizeError)))
}

pub fn parse_window_update_unknown_flags_ignored_test() {
  // RFC 9113 Section 6.9: No flags defined; all flags MUST be ignored
  let data = <<
    4:size(24), 8:size(8), 0xFF:size(8), 0:size(1), 1:size(31), 0:size(1),
    1000:size(31),
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.WindowUpdateFrame(
          header: FrameHeader(
            length: 4,
            frame_type: header.WindowUpdate,
            flags: 0xFF,
            stream_id: 1,
          ),
          window_size_increment: 1000,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_window_update_truncated_payload_test() {
  // RFC 9113 Section 6.9: Incomplete payload
  let data = <<4:size(24), 8:size(8), 0:size(8), 0:size(1), 1:size(31), 0, 0>>
  frame.parse(data)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_window_update_with_trailing_data_test() {
  // RFC 9113 Section 6.9: Trailing data from next frame returned
  let data = <<
    4:size(24), 8:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    1000:size(31), 99, 99,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.WindowUpdateFrame(
          header: FrameHeader(
            length: 4,
            frame_type: header.WindowUpdate,
            flags: 0,
            stream_id: 1,
          ),
          window_size_increment: 1000,
        ),
        <<99, 99>>,
      ),
    ),
  )
}
