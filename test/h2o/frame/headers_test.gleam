import gleam/option.{None, Some}
import gleeunit/should
import h2o/frame
import h2o/frame/error
import h2o/frame/header.{FrameHeader}

pub fn parse_headers_test() {
  // RFC 9113 Section 6.2: Basic HEADERS frame with fragment only
  let data = <<
    5:size(24), 1:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.HeadersFrame(
          header: FrameHeader(
            length: 5,
            frame_type: header.Headers,
            flags: 0,
            stream_id: 1,
          ),
          end_stream: False,
          end_headers: False,
          priority: None,
          data: <<"hello":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_headers_end_stream_test() {
  // RFC 9113 Section 6.2: END_STREAM (0x01) flag
  let data = <<
    3:size(24), 1:size(8), 1:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.HeadersFrame(
          header: FrameHeader(
            length: 3,
            frame_type: header.Headers,
            flags: 1,
            stream_id: 1,
          ),
          end_stream: True,
          end_headers: False,
          priority: None,
          data: <<"abc":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_headers_end_headers_test() {
  // RFC 9113 Section 6.2: END_HEADERS (0x04) flag
  let data = <<
    3:size(24), 1:size(8), 4:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.HeadersFrame(
          header: FrameHeader(
            length: 3,
            frame_type: header.Headers,
            flags: 4,
            stream_id: 1,
          ),
          end_stream: False,
          end_headers: True,
          priority: None,
          data: <<"abc":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_headers_end_stream_and_end_headers_test() {
  // RFC 9113 Section 6.2: Both END_STREAM (0x01) and END_HEADERS (0x04)
  let data = <<
    3:size(24), 1:size(8), 5:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.HeadersFrame(
          header: FrameHeader(
            length: 3,
            frame_type: header.Headers,
            flags: 5,
            stream_id: 1,
          ),
          end_stream: True,
          end_headers: True,
          priority: None,
          data: <<"abc":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_headers_priority_test() {
  // RFC 9113 Section 6.2: PRIORITY (0x20) flag adds 5 bytes
  // exclusive=0, stream_dependency=3, weight=15, fragment="ab"
  let data = <<
    7:size(24), 1:size(8), 0x20:size(8), 0:size(1), 1:size(31), 0:size(1),
    3:size(31), 15:size(8), "ab":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.HeadersFrame(
          header: FrameHeader(
            length: 7,
            frame_type: header.Headers,
            flags: 0x20,
            stream_id: 1,
          ),
          end_stream: False,
          end_headers: False,
          priority: Some(frame.Priority(
            exclusive: False,
            stream_dependency: 3,
            weight: 15,
          )),
          data: <<"ab":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_headers_priority_exclusive_test() {
  // RFC 9113 Section 6.2: PRIORITY with exclusive bit set
  let data = <<
    7:size(24), 1:size(8), 0x20:size(8), 0:size(1), 1:size(31), 1:size(1),
    5:size(31), 255:size(8), "ab":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.HeadersFrame(
          header: FrameHeader(
            length: 7,
            frame_type: header.Headers,
            flags: 0x20,
            stream_id: 1,
          ),
          end_stream: False,
          end_headers: False,
          priority: Some(frame.Priority(
            exclusive: True,
            stream_dependency: 5,
            weight: 255,
          )),
          data: <<"ab":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_headers_padded_test() {
  // RFC 9113 Section 6.2: PADDED (0x08) flag
  // pad_length=2, fragment="abc", padding=0x00 0x00
  let data = <<
    6:size(24), 1:size(8), 8:size(8), 0:size(1), 1:size(31), 2:size(8),
    "abc":utf8, 0, 0,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.HeadersFrame(
          header: FrameHeader(
            length: 6,
            frame_type: header.Headers,
            flags: 8,
            stream_id: 1,
          ),
          end_stream: False,
          end_headers: False,
          priority: None,
          data: <<"abc":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_headers_padded_and_priority_test() {
  // RFC 9113 Section 6.2: Both PADDED (0x08) and PRIORITY (0x20)
  // Payload: pad_length + exclusive/dep/weight + fragment + padding
  // pad_length=2, exclusive=1, dep=7, weight=100, fragment="ab", padding=0x00 0x00
  let data = <<
    10:size(24), 1:size(8), 0x28:size(8), 0:size(1), 1:size(31), 2:size(8),
    1:size(1), 7:size(31), 100:size(8), "ab":utf8, 0, 0,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.HeadersFrame(
          header: FrameHeader(
            length: 10,
            frame_type: header.Headers,
            flags: 0x28,
            stream_id: 1,
          ),
          end_stream: False,
          end_headers: False,
          priority: Some(frame.Priority(
            exclusive: True,
            stream_dependency: 7,
            weight: 100,
          )),
          data: <<"ab":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_headers_all_flags_test() {
  // RFC 9113 Section 6.2: All defined flags set (END_STREAM|END_HEADERS|PADDED|PRIORITY = 0x2D)
  // pad_length=1, exclusive=0, dep=0, weight=0, fragment="x", padding=0x00
  let data = <<
    8:size(24), 1:size(8), 0x2D:size(8), 0:size(1), 1:size(31), 1:size(8),
    0:size(1), 0:size(31), 0:size(8), "x":utf8, 0,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.HeadersFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.Headers,
            flags: 0x2D,
            stream_id: 1,
          ),
          end_stream: True,
          end_headers: True,
          priority: Some(frame.Priority(
            exclusive: False,
            stream_dependency: 0,
            weight: 0,
          )),
          data: <<"x":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_headers_stream_id_zero_test() {
  // RFC 9113 Section 6.2: Stream ID 0x00 MUST be treated as connection error PROTOCOL_ERROR
  let data = <<
    3:size(24), 1:size(8), 0:size(8), 0:size(1), 0:size(31), "abc":utf8,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_headers_padding_exceeds_payload_test() {
  // RFC 9113 Section 6.2: Padding length >= payload length is PROTOCOL_ERROR
  // length=3, pad_length=3 leaves no room for fragment
  let data = <<
    3:size(24), 1:size(8), 8:size(8), 0:size(1), 1:size(31), 3:size(8), 0, 0,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_headers_padded_priority_padding_exceeds_test() {
  // RFC 9113 Section 6.2: With PADDED+PRIORITY, padding must account for priority fields too
  // length=7, pad_length=2, priority=5 bytes, that leaves 7-1-5-2 = -1 for fragment
  let data = <<
    7:size(24), 1:size(8), 0x28:size(8), 0:size(1), 1:size(31), 2:size(8),
    0:size(1), 0:size(31), 0:size(8), 0,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_headers_priority_truncated_test() {
  // RFC 9113 Section 6.2: PRIORITY flag set but not enough bytes for priority fields
  // length=3 but priority needs 5 bytes
  let data = <<
    3:size(24), 1:size(8), 0x20:size(8), 0:size(1), 1:size(31), 0, 0, 0,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_headers_empty_fragment_test() {
  // RFC 9113 Section 6.2: HEADERS frame with empty fragment is valid
  let data = <<0:size(24), 1:size(8), 0:size(8), 0:size(1), 1:size(31)>>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.HeadersFrame(
          header: FrameHeader(
            length: 0,
            frame_type: header.Headers,
            flags: 0,
            stream_id: 1,
          ),
          end_stream: False,
          end_headers: False,
          priority: None,
          data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_headers_unknown_flags_ignored_test() {
  // RFC 9113 Section 4.1: Unknown flags MUST be ignored
  // 0xD2 has undefined bits set, no defined flags active
  let data = <<
    3:size(24), 1:size(8), 0xD2:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.HeadersFrame(
          header: FrameHeader(
            length: 3,
            frame_type: header.Headers,
            flags: 0xD2,
            stream_id: 1,
          ),
          end_stream: False,
          end_headers: False,
          priority: None,
          data: <<"abc":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_headers_truncated_payload_test() {
  // RFC 9113 Section 6.2: Incomplete payload
  let data = <<
    10:size(24), 1:size(8), 0:size(8), 0:size(1), 1:size(31), "short":utf8,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_headers_with_trailing_data_test() {
  // RFC 9113 Section 6.2: Trailing data from next frame returned
  let data = <<
    3:size(24), 1:size(8), 0:size(8), 0:size(1), 1:size(31), "abc":utf8, 99, 99,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.HeadersFrame(
          header: FrameHeader(
            length: 3,
            frame_type: header.Headers,
            flags: 0,
            stream_id: 1,
          ),
          end_stream: False,
          end_headers: False,
          priority: None,
          data: <<"abc":utf8>>,
        ),
        <<99, 99>>,
      ),
    ),
  )
}

pub fn parse_headers_padded_empty_payload_test() {
  // RFC 9113 Section 6.2: PADDED flag set but no payload bytes at all
  let data = <<5:size(24), 1:size(8), 8:size(8), 0:size(1), 1:size(31)>>
  frame.parse(data)
  |> should.equal(Error(frame.IncompletePayload))
}
