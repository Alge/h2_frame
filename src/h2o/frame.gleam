pub type FrameType {
    Ping
}

pub type FrameHeader {
    FrameHeader(length: Int, frame_type: FrameType, flags: Int, stream_id: Int)
}

pub type FrameError {
    UnknownFrameType(Int)
    IncompleteHeader
}

pub fn parse_frame_type(code: Int) -> Result(FrameType, Nil) {
    case code {
        6 -> {
            Ok(Ping)
        }
        _ -> Error(Nil)
    }
}

pub fn parse_header(data: BitArray) -> Result(FrameHeader, FrameError) {
    case data {
        <<length:size(24), type_code:size(8), flags:size(8), _reserverd:size(1), stream_id:size(31)>> -> {
            case parse_frame_type(type_code) {
                Ok(frame_type) -> {
                    Ok(FrameHeader(length:length, frame_type: frame_type, flags: flags, stream_id: stream_id))
                }
                _ -> Error(UnknownFrameType(type_code))
            }
        }

        _ -> Error(IncompleteHeader)
    }
}