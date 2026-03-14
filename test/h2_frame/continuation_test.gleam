import gleeunit/should
import h2_frame

pub fn parse_continuation_test() {
  // RFC 9113 Section 6.10: Basic CONTINUATION frame with fragment
  let data = <<
    5:size(24), 9:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8,
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(
      #(
        h2_frame.Continuation(
          stream_id: 1,
          end_headers: False,
          field_block_fragment: <<
            "hello":utf8,
          >>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_continuation_end_headers_test() {
  // RFC 9113 Section 6.10: END_HEADERS (0x04) flag signals last continuation
  let data = <<
    3:size(24), 9:size(8), 4:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(
      #(
        h2_frame.Continuation(
          stream_id: 1,
          end_headers: True,
          field_block_fragment: <<
            "abc":utf8,
          >>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_continuation_empty_fragment_test() {
  // RFC 9113 Section 6.10: Empty fragment is valid
  let data = <<0:size(24), 9:size(8), 0:size(8), 0:size(1), 1:size(31)>>
  h2_frame.parse(data)
  |> should.equal(
    Ok(
      #(
        h2_frame.Continuation(
          stream_id: 1,
          end_headers: False,
          field_block_fragment: <<>>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_continuation_stream_id_zero_test() {
  // RFC 9113 Section 6.10: Stream ID 0x00 MUST be treated as connection error PROTOCOL_ERROR
  let data = <<
    3:size(24), 9:size(8), 0:size(8), 0:size(1), 0:size(31), "abc":utf8,
  >>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn parse_continuation_unknown_flags_ignored_test() {
  // RFC 9113 Section 4.1: Unknown flags MUST be ignored
  // 0xFB has all bits set except END_HEADERS
  let data = <<
    3:size(24), 9:size(8), 0xFB:size(8), 0:size(1), 1:size(31), "abc":utf8,
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(
      #(
        h2_frame.Continuation(
          stream_id: 1,
          end_headers: False,
          field_block_fragment: <<
            "abc":utf8,
          >>,
        ),
        <<>>,
      ),
    ),
  )
}

pub fn parse_continuation_truncated_payload_test() {
  // RFC 9113 Section 6.10: Incomplete payload
  let data = <<
    10:size(24), 9:size(8), 0:size(8), 0:size(1), 1:size(31), "short":utf8,
  >>
  h2_frame.parse(data)
  |> should.equal(Error(h2_frame.Incomplete))
}

pub fn parse_continuation_with_trailing_data_test() {
  // RFC 9113 Section 6.10: Trailing data from next frame returned
  let data = <<
    3:size(24), 9:size(8), 0:size(8), 0:size(1), 1:size(31), "abc":utf8, 99, 99,
  >>
  h2_frame.parse(data)
  |> should.equal(
    Ok(
      #(
        h2_frame.Continuation(
          stream_id: 1,
          end_headers: False,
          field_block_fragment: <<
            "abc":utf8,
          >>,
        ),
        <<99, 99>>,
      ),
    ),
  )
}

// --- Encode tests ---

pub fn encode_continuation_test() {
  h2_frame.encode_continuation(
    stream_id: 1,
    end_headers: False,
    field_block_fragment: <<"hello":utf8>>,
  )
  |> should.equal(
    Ok(<<5:size(24), 9:size(8), 0:size(8), 0:size(1), 1:size(31), "hello":utf8>>),
  )
}

pub fn encode_continuation_end_headers_test() {
  h2_frame.encode_continuation(
    stream_id: 1,
    end_headers: True,
    field_block_fragment: <<"abc":utf8>>,
  )
  |> should.equal(
    Ok(<<3:size(24), 9:size(8), 4:size(8), 0:size(1), 1:size(31), "abc":utf8>>),
  )
}

pub fn encode_continuation_empty_fragment_test() {
  h2_frame.encode_continuation(
    stream_id: 1,
    end_headers: False,
    field_block_fragment: <<>>,
  )
  |> should.equal(
    Ok(<<0:size(24), 9:size(8), 0:size(8), 0:size(1), 1:size(31)>>),
  )
}

pub fn encode_continuation_stream_id_zero_test() {
  h2_frame.encode_continuation(
    stream_id: 0,
    end_headers: False,
    field_block_fragment: <<"abc":utf8>>,
  )
  |> should.equal(Error(h2_frame.ConnectionError(h2_frame.ProtocolError)))
}

pub fn encode_continuation_roundtrip_test() {
  let assert Ok(encoded) =
    h2_frame.encode_continuation(
      stream_id: 3,
      end_headers: True,
      field_block_fragment: <<"hpack":utf8>>,
    )
  h2_frame.parse(encoded)
  |> should.equal(
    Ok(
      #(
        h2_frame.Continuation(
          stream_id: 3,
          end_headers: True,
          field_block_fragment: <<"hpack":utf8>>,
        ),
        <<>>,
      ),
    ),
  )
}
