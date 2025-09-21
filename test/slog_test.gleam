import file_streams/file_open_mode
import file_streams/file_stream
import file_streams/file_stream_error
import gleam/bit_array
import gleam/result
import gleam/string
import slog
import slog/attr
import slog/format
import slog/sink

@external(erlang, "file", "delete")
fn del_file(path: String) -> Result(Nil, error)

fn read_full(path: String) -> String {
  let assert Ok(content) =
    file_stream.open(path, [file_open_mode.Read])
    |> result.map(file_stream.read_remaining_bytes)
    |> result.try(fn(x) { x |> result.map(bit_array.to_string) })
  content |> result.unwrap("")
}

fn quote(s: String) -> String {
  s |> string.replace("'", "\"")
}

@target(erlang)
pub fn file_log_test() {
  let path = "./test.log"
  let assert Ok(s) = sink.configure(path) |> sink.create_ok(True) |> sink.file
  let f =
    format.configure() |> format.time_format(format.NoTimestamp) |> format.json
  let logger = slog.new(f, s, slog.DEBUG)
  logger
  |> slog.with(attr.String("test", "logger"))
  |> slog.int("a", 1)
  |> slog.info("test message")

  let output = read_full(path)
  let _ = del_file(path)
  assert output
    == "{'level':'INFO','msg':'test message','a':1,'test':'logger'}" |> quote
}

pub fn file_not_exist_test() {
  let assert Error(sink.FileError(_, file_stream_error.Enoent)) =
    sink.configure("/does/not/exist") |> sink.create_ok(False) |> sink.file
}
