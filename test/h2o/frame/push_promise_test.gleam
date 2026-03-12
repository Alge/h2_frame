import gleeunit/should
import h2o/frame
import h2o/frame/error
import h2o/frame/header.{FrameHeader}

pub fn parse_push_promise_test() {
  // RFC 9113 Section 6.6: Basic PUSH_PROMISE frame
  // reserved=0, promised_stream_id=2, fragment="abc"
  let data = <<
    7:size(24), 5:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    2:size(31), "abc":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PushPromiseFrame(
          header: FrameHeader(
            length: 7,
            frame_type: header.PushPromise,
            flags: 0,
            stream_id: 1,
          ),
          end_headers: False,
          promised_stream_id: 2,
          data: <<"abc":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_end_headers_test() {
  // RFC 9113 Section 6.6: END_HEADERS (0x04) flag
  let data = <<
    7:size(24), 5:size(8), 4:size(8), 0:size(1), 1:size(31), 0:size(1),
    2:size(31), "abc":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PushPromiseFrame(
          header: FrameHeader(
            length: 7,
            frame_type: header.PushPromise,
            flags: 4,
            stream_id: 1,
          ),
          end_headers: True,
          promised_stream_id: 2,
          data: <<"abc":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_padded_test() {
  // RFC 9113 Section 6.6: PADDED (0x08) flag
  // pad_length=2, reserved=0, promised_stream_id=2, fragment="ab", padding=0x00 0x00
  let data = <<
    9:size(24), 5:size(8), 8:size(8), 0:size(1), 1:size(31), 2:size(8),
    0:size(1), 2:size(31), "ab":utf8, 0, 0,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PushPromiseFrame(
          header: FrameHeader(
            length: 9,
            frame_type: header.PushPromise,
            flags: 8,
            stream_id: 1,
          ),
          end_headers: False,
          promised_stream_id: 2,
          data: <<"ab":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_padded_end_headers_test() {
  // RFC 9113 Section 6.6: Both PADDED (0x08) and END_HEADERS (0x04)
  let data = <<
    9:size(24), 5:size(8), 0x0C:size(8), 0:size(1), 1:size(31), 2:size(8),
    0:size(1), 2:size(31), "ab":utf8, 0, 0,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PushPromiseFrame(
          header: FrameHeader(
            length: 9,
            frame_type: header.PushPromise,
            flags: 0x0C,
            stream_id: 1,
          ),
          end_headers: True,
          promised_stream_id: 2,
          data: <<"ab":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_stream_id_zero_test() {
  // RFC 9113 Section 6.6: Stream ID 0x00 MUST be treated as connection error PROTOCOL_ERROR
  let data = <<
    7:size(24), 5:size(8), 0:size(8), 0:size(1), 0:size(31), 0:size(1),
    2:size(31), "abc":utf8,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_push_promise_padding_exceeds_payload_test() {
  // RFC 9113 Section 6.6: Padding length >= payload length is PROTOCOL_ERROR
  // length=6, pad_length=6 leaves no room
  let data = <<
    6:size(24), 5:size(8), 8:size(8), 0:size(1), 1:size(31), 6:size(8),
    0:size(1), 2:size(31), 0,
  >>
  frame.parse(data)
  |> should.equal(Error(frame.ConnectionError(error.ProtocolError)))
}

pub fn parse_push_promise_empty_fragment_test() {
  // RFC 9113 Section 6.6: PUSH_PROMISE with empty fragment is valid
  let data = <<
    4:size(24), 5:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    2:size(31),
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PushPromiseFrame(
          header: FrameHeader(
            length: 4,
            frame_type: header.PushPromise,
            flags: 0,
            stream_id: 1,
          ),
          end_headers: False,
          promised_stream_id: 2,
          data: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_unknown_flags_ignored_test() {
  // RFC 9113 Section 4.1: Unknown flags MUST be ignored
  // 0xF3 has undefined bits set, no PADDED or END_HEADERS active
  let data = <<
    7:size(24), 5:size(8), 0xF3:size(8), 0:size(1), 1:size(31), 0:size(1),
    2:size(31), "abc":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PushPromiseFrame(
          header: FrameHeader(
            length: 7,
            frame_type: header.PushPromise,
            flags: 0xF3,
            stream_id: 1,
          ),
          end_headers: False,
          promised_stream_id: 2,
          data: <<"abc":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_push_promise_truncated_payload_test() {
  // RFC 9113 Section 6.6: Incomplete payload (can't even read promised stream ID)
  let data = <<7:size(24), 5:size(8), 0:size(8), 0:size(1), 1:size(31), 0, 0>>
  frame.parse(data)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_push_promise_padded_empty_payload_test() {
  // RFC 9113 Section 6.6: PADDED flag set but no payload bytes at all
  let data = <<7:size(24), 5:size(8), 8:size(8), 0:size(1), 1:size(31)>>
  frame.parse(data)
  |> should.equal(Error(frame.IncompletePayload))
}

pub fn parse_push_promise_with_trailing_data_test() {
  // RFC 9113 Section 6.6: Trailing data from next frame returned
  let data = <<
    7:size(24), 5:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(1),
    2:size(31), "abc":utf8, 99, 99,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PushPromiseFrame(
          header: FrameHeader(
            length: 7,
            frame_type: header.PushPromise,
            flags: 0,
            stream_id: 1,
          ),
          end_headers: False,
          promised_stream_id: 2,
          data: <<"abc":utf8>>,
        ),
        <<99, 99>>,
      ),
    ),
  )
}

pub fn parse_push_promise_padded_zero_padding_test() {
  // RFC 9113 Section 6.6: PADDED flag with pad_length=0 is valid
  let data = <<
    8:size(24), 5:size(8), 8:size(8), 0:size(1), 1:size(31), 0:size(8),
    0:size(1), 2:size(31), "abc":utf8,
  >>
  frame.parse(data)
  |> should.equal(
    Ok(
      #(
        frame.PushPromiseFrame(
          header: FrameHeader(
            length: 8,
            frame_type: header.PushPromise,
            flags: 8,
            stream_id: 1,
          ),
          end_headers: False,
          promised_stream_id: 2,
          data: <<"abc":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}
