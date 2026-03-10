import h2o/frame.{FrameHeader, Ping}
import gleeunit/should

pub fn parse_ping_header_test() {
     // 9-byte header: length=0, type=6 (PING), flags=0, stream_id=0
    let data = <<0:size(24), 6:size(8), 0:size(8), 0:size(1), 0:size(31)>>

    frame.parse_header(data)
    |> should.equal(Ok(FrameHeader(length:0, frame_type: Ping, flags:0, stream_id:0)))
}

pub fn parse_too_short_header_test() {
     // 4-byte header, too short: length=0, type=6 (PING)
    let data = <<0:size(24), 6:size(8)>>

    frame.parse_header(data)
    |> should.equal(Error(frame.IncompleteHeader))
}

pub fn parse_invalid_frame_type_test() {
     // 9-byte header: length=0, type=255 (which is invalid), flags=0, stream_id=0
    let data = <<0:size(24), 255:size(8), 0:size(8), 0:size(1), 0:size(31)>>

    frame.parse_header(data)
    |> should.equal(Error(frame.UnknownFrameType(255)))
}