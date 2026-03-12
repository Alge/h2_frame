import gleeunit/should
import h2o/frame
import h2o/frame/error
import h2o/frame/header.{FrameHeader}

pub fn parse_ping_test() {
  // RFC 9113 Section 6.7: PING frame contains 8 octets of opaque data
  let data = <<
    8:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4, 5, 6, 7,
    8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PingFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.Ping,
            flags: 0,
            stream_id: 0,
          ),
          ack: False,
          data: <<1, 2, 3, 4, 5, 6, 7, 8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_ping_ack_test() {
  // RFC 9113 Section 6.7: ACK (0x01) flag indicates a PING response
  let data = <<
    8:size(24), 6:size(8), 1:size(8), 0:size(1), 0:size(31), 0, 0, 0, 0, 0, 0, 0,
    0,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PingFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.Ping,
            flags: 1,
            stream_id: 0,
          ),
          ack: True,
          data: <<0, 0, 0, 0, 0, 0, 0, 0>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_ping_wrong_length_test() {
  // RFC 9113 Section 6.7: Length other than 8 MUST be treated as FRAME_SIZE_ERROR
  let data = <<
    4:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.ConnectionError(error.FrameSizeError)))
}

pub fn parse_ping_nonzero_stream_id_test() {
  // RFC 9113 Section 6.7: Stream ID other than 0x00 MUST be treated as PROTOCOL_ERROR
  let data = <<
    8:size(24), 6:size(8), 0:size(8), 0:size(1), 1:size(31), 0, 0, 0, 0, 0, 0, 0,
    0,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_ping_unknown_flags_ignored_test() {
  // RFC 9113 Section 4.1: Flags not defined for a frame type MUST be ignored
  let data = <<
    8:size(24), 6:size(8), 3:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4, 5, 6, 7,
    8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PingFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.Ping,
            flags: 3,
            stream_id: 0,
          ),
          ack: True,
          data: <<1, 2, 3, 4, 5, 6, 7, 8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_ping_unknown_flags_no_ack_test() {
  // RFC 9113 Section 4.1: Unknown flags ignored; ACK bit not set means ack=False
  let data = <<
    8:size(24), 6:size(8), 2:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4, 5, 6, 7,
    8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PingFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.Ping,
            flags: 2,
            stream_id: 0,
          ),
          ack: False,
          data: <<1, 2, 3, 4, 5, 6, 7, 8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_ping_truncated_payload_test() {
  // RFC 9113 Section 6.7: Incomplete payload when stream has insufficient data
  let data = <<
    8:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_ping_with_trailing_data_test() {
  // RFC 9113 Section 6.7: PING payload parsed correctly with trailing data from next frame
  let data = <<
    8:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31), 1, 2, 3, 4, 5, 6, 7,
    8, 99, 99,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PingFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.Ping,
            flags: 0,
            stream_id: 0,
          ),
          ack: False,
          data: <<1, 2, 3, 4, 5, 6, 7, 8>>,
        ),
        <<99, 99>>,
      ),
    ),
  )
}
