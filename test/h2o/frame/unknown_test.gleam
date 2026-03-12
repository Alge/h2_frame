import gleeunit/should
import h2o/frame
import h2o/frame/header.{FrameHeader}

pub fn parse_unknown_frame_test() {
  // RFC 9113 Section 4.1: Unknown frame types MUST be ignored
  // Frame type 0xFF with some payload
  let data = <<
    5:size(24), 0xFF:size(8), 0:size(8), 0:size(1), 0:size(31), "hello":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.UnknownFrame(
          header: FrameHeader(
            length: 5,
            frame_type: header.Unknown(0xFF),
            flags: 0,
            stream_id: 0,
          ),
          data: <<"hello":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_unknown_frame_with_stream_id_test() {
  // RFC 9113 Section 4.1: Unknown frames can have any stream ID
  let data = <<
    3:size(24), 0x0A:size(8), 0:size(8), 0:size(1), 5:size(31), "abc":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.UnknownFrame(
          header: FrameHeader(
            length: 3,
            frame_type: header.Unknown(0x0A),
            flags: 0,
            stream_id: 5,
          ),
          data: <<"abc":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_unknown_frame_with_flags_test() {
  // RFC 9113 Section 4.1: Unknown frame flags are preserved but ignored
  let data = <<
    3:size(24), 0x0B:size(8), 0xFF:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.UnknownFrame(
          header: FrameHeader(
            length: 3,
            frame_type: header.Unknown(0x0B),
            flags: 0xFF,
            stream_id: 1,
          ),
          data: <<"abc":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_unknown_frame_empty_payload_test() {
  // RFC 9113 Section 4.1: Unknown frame with zero-length payload
  let data = <<
    0:size(24), 0x0C:size(8), 0:size(8), 0:size(1), 0:size(31),
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.UnknownFrame(
          header: FrameHeader(
            length: 0,
            frame_type: header.Unknown(0x0C),
            flags: 0,
            stream_id: 0,
          ),
          data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_unknown_frame_truncated_payload_test() {
  // RFC 9113 Section 4.1: Incomplete payload
  let data = <<
    10:size(24), 0x0D:size(8), 0:size(8), 0:size(1), 0:size(31), "short":utf8,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_unknown_frame_with_trailing_data_test() {
  // RFC 9113 Section 4.1: Trailing data from next frame returned
  let data = <<
    3:size(24), 0x0E:size(8), 0:size(8), 0:size(1), 0:size(31), "abc":utf8, 99,
    99,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.UnknownFrame(
          header: FrameHeader(
            length: 3,
            frame_type: header.Unknown(0x0E),
            flags: 0,
            stream_id: 0,
          ),
          data: <<"abc":utf8>>,
        ),
        <<99, 99>>,
      ),
    ),
  )
}
