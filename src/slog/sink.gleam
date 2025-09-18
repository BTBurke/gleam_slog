import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/io
import gleam/result
import slog
import slog/internal/formatter

pub fn stdout(s: String, level: slog.Level) -> Nil {
  do_stdout(s, level |> formatter.level_to_string)
}

@target(javascript)
@external(javascript, "../slog_ffi.mjs", "console")
fn do_stdout(s: String, level: String) -> Nil

@target(erlang)
fn do_stdout(s: String, _level: String) -> Nil {
  // run IO in a separate process
  process.spawn_unlinked(fn() -> Nil { io.println(s) })
  Nil
}

pub fn stderr(s: String, level: slog.Level) -> Nil {
  do_stderr(s, level |> formatter.level_to_string)
}

@target(javascript)
@external(javascript, "../slog_ffi.mjs", "console")
fn do_stderr(s: String, level: String) -> Nil

@target(erlang)
fn do_stderr(s: String, _level: String) -> Nil {
  // run IO in a separate process
  process.spawn_unlinked(fn() -> Nil { io.println_error(s) })
  Nil
}

pub type FileInfo {
  FileInfo(size: Int)
}

pub type FileError(error) {
  DecoderError
  FileError(error)
}

pub fn read_file_info(path: String) -> Result(FileInfo, FileError(error)) {
  let finfo = do_file_info(path)
  case finfo {
    Error(e) -> Error(FileError(e))
    Ok(a) ->
      decode.run(a, decode.at([1], decode.int))
      |> result.map(FileInfo)
      |> result.replace_error(DecoderError)
  }
}

@external(erlang, "file", "read_file_info")
pub fn do_file_info(path: String) -> Result(Dynamic, error)

@target(javascript)
pub fn do_file_info(path: String) -> Result(Dynamic, error) {
  panic
}
