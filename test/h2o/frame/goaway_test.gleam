import gleeunit/should
import h2o/frame
import h2o/frame/error
import h2o/frame/header.{FrameHeader}

pub fn parse_goaway_test() {
  // RFC 9113 Section 6.8: Basic GOAWAY frame with no debug data
  // last_stream_id=1, error_code=NO_ERROR
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0x00:size(32),
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.GoAwayFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.GoAway,
            flags: 0,
            stream_id: 0,
          ),
          last_stream_id: 1,
          error_code: error.NoError,
          debug_data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_with_error_test() {
  // RFC 9113 Section 6.8: GOAWAY with PROTOCOL_ERROR
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    5:size(31), 0x01:size(32),
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.GoAwayFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.GoAway,
            flags: 0,
            stream_id: 0,
          ),
          last_stream_id: 5,
          error_code: error.ProtocolError,
          debug_data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_with_debug_data_test() {
  // RFC 9113 Section 6.8: GOAWAY with additional debug data
  let data = <<
    13:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0x00:size(32), "hello":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.GoAwayFrame(
          header: FrameHeader(
            length: 13,
            frame_type: header.GoAway,
            flags: 0,
            stream_id: 0,
          ),
          last_stream_id: 1,
          error_code: error.NoError,
          debug_data: <<"hello":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_zero_last_stream_id_test() {
  // RFC 9113 Section 6.8: last_stream_id=0 means no streams were processed
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    0:size(31), 0x00:size(32),
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.GoAwayFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.GoAway,
            flags: 0,
            stream_id: 0,
          ),
          last_stream_id: 0,
          error_code: error.NoError,
          debug_data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_unknown_error_code_test() {
  // RFC 9113 Section 7: Unknown error codes MUST NOT trigger special behavior
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0xFF:size(32),
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.GoAwayFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.GoAway,
            flags: 0,
            stream_id: 0,
          ),
          last_stream_id: 1,
          error_code: error.UnknownErrorCode(0xFF),
          debug_data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_stream_id_nonzero_test() {
  // RFC 9113 Section 6.8: Stream ID must be 0x00, otherwise PROTOCOL_ERROR
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    1:size(31), 0x00:size(32),
  >>
  frame.parse(data)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_goaway_unknown_flags_ignored_test() {
  // RFC 9113 Section 6.8: No flags defined; all flags MUST be ignored
  let data = <<
    8:size(24), 7:size(8), 0xFF:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0x00:size(32),
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.GoAwayFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.GoAway,
            flags: 0xFF,
            stream_id: 0,
          ),
          last_stream_id: 1,
          error_code: error.NoError,
          debug_data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_goaway_truncated_payload_test() {
  // RFC 9113 Section 6.8: Incomplete payload (less than 8 bytes minimum)
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31),
  >>
  frame.parse(data)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_goaway_with_trailing_data_test() {
  // RFC 9113 Section 6.8: Trailing data from next frame returned
  let data = <<
    8:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0x00:size(32), 99, 99,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.GoAwayFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.GoAway,
            flags: 0,
            stream_id: 0,
          ),
          last_stream_id: 1,
          error_code: error.NoError,
          debug_data: <<>>,
        ),
        <<99, 99>>,
      ),
    ),
  )
}

pub fn parse_goaway_debug_data_with_trailing_test() {
  // RFC 9113 Section 6.8: Debug data AND trailing data from next frame
  let data = <<
    11:size(24), 7:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    1:size(31), 0x02:size(32), "err":utf8, 99, 99,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.GoAwayFrame(
          header: FrameHeader(
            length: 11,
            frame_type: header.GoAway,
            flags: 0,
            stream_id: 0,
          ),
          last_stream_id: 1,
          error_code: error.InternalError,
          debug_data: <<"err":utf8>>,
        ),
        <<99, 99>>,
      ),
    ),
  )
}
