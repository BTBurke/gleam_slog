import gleam/dynamic
import gleam/erlang/process
import gleam/io
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

pub type FileInfo

@external(erlang, "file", "read_file_info")
pub fn file_info(path: String) -> Result(dynamic.Dynamic, error)

@target(javascript)
pub fn file_info(path: String) -> Result(FileInfo, error) {
  panic
}
