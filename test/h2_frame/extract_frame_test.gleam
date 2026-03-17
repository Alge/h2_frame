import gleeunit/should
import h2_frame

// Default max frame size per RFC 9113 Section 6.5.2
const default_max_frame_size = 16_384

pub fn extract_frame_single_frame_test() {
  // A complete DATA frame: length=5, type=0x00, flags=0, stream_id=1, payload="hello"
  let data = <<
    5:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8,
  >>
  h2_frame.extract_frame(data, default_max_frame_size)
  |> should.equal(Ok(#(data, <<>>)))
}

pub fn extract_frame_with_remaining_bytes_test() {
  // Two frames concatenated; extract_frame should return only the first
  let frame1 = <<
    5:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8,
  >>
  let frame2 = <<
    3:size(24), 0:size(8), 0:size(8), 0:size(1), 2:size(31), "bye":utf8,
  >>
  let data = <<frame1:bits, frame2:bits>>
  h2_frame.extract_frame(data, default_max_frame_size)
  |> should.equal(Ok(#(frame1, frame2)))
}

pub fn extract_frame_zero_length_payload_test() {
  // Frame with zero-length payload (e.g. SETTINGS ACK)
  let data = <<0:size(24), 4:size(8), 1:size(8), 0:size(1), 0:size(31)>>
  h2_frame.extract_frame(data, default_max_frame_size)
  |> should.equal(Ok(#(data, <<>>)))
}

pub fn extract_frame_incomplete_header_test() {
  // Less than 9 bytes — not enough for the frame header
  let data = <<5:size(24), 0:size(8), 0:size(8)>>
  h2_frame.extract_frame(data, default_max_frame_size)
  |> should.equal(Error(h2_frame.NeedMoreData))
}

pub fn extract_frame_empty_input_test() {
  // Empty input — incomplete
  h2_frame.extract_frame(<<>>, default_max_frame_size)
  |> should.equal(Error(h2_frame.NeedMoreData))
}

pub fn extract_frame_incomplete_payload_test() {
  // Header says 10 bytes of payload but only 5 available
  let data = <<
    10:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31), "short":utf8,
  >>
  h2_frame.extract_frame(data, default_max_frame_size)
  |> should.equal(Error(h2_frame.NeedMoreData))
}

pub fn extract_frame_header_only_no_payload_test() {
  // Header says 5 bytes of payload but none present
  let data = <<5:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31)>>
  h2_frame.extract_frame(data, default_max_frame_size)
  |> should.equal(Error(h2_frame.NeedMoreData))
}

pub fn extract_frame_exceeds_max_frame_size_test() {
  // RFC 9113 Section 4.2: payload length exceeding max_frame_size
  // MUST be treated as connection error FRAME_SIZE_ERROR
  // Header declares length of 100 but max is 50
  let data = <<
    100:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31), 0:size(800),
  >>
  h2_frame.extract_frame(data, 50)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.FrameSizeError)))
}

pub fn extract_frame_exactly_max_frame_size_test() {
  // Payload length exactly equal to max_frame_size should succeed
  // Using max_frame_size=5
  let data = <<
    5:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8,
  >>
  h2_frame.extract_frame(data, 5)
  |> should.equal(Ok(#(data, <<>>)))
}

pub fn extract_frame_one_over_max_frame_size_test() {
  // Payload length one byte over max_frame_size is a connection error
  let data = <<
    6:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31), "hello!":utf8,
  >>
  h2_frame.extract_frame(data, 5)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.FrameSizeError)))
}

pub fn extract_frame_unknown_frame_type_test() {
  // extract_frame doesn't care about frame type — it just slices bytes
  let data = <<
    3:size(24), 0xFF:size(8), 0xAB:size(8), 0:size(1), 42:size(31), "abc":utf8,
  >>
  h2_frame.extract_frame(data, default_max_frame_size)
  |> should.equal(Ok(#(data, <<>>)))
}

pub fn extract_frame_preserves_remaining_partial_test() {
  // Remaining bytes can be a partial next frame (fewer than 9 bytes)
  let frame = <<
    5:size(24), 0:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8,
  >>
  let partial = <<0, 0, 1>>
  let data = <<frame:bits, partial:bits>>
  h2_frame.extract_frame(data, default_max_frame_size)
  |> should.equal(Ok(#(frame, partial)))
}

pub fn extract_frame_reserved_bit_preserved_test() {
  // Reserved bit set to 1 in the header — extract_frame preserves raw bytes
  let data = <<
    3:size(24), 0:size(8), 0:size(8), 1:size(1), 1:size(31), "abc":utf8,
  >>
  h2_frame.extract_frame(data, default_max_frame_size)
  |> should.equal(Ok(#(data, <<>>)))
}
