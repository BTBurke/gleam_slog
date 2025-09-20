import file_streams/file_open_mode
import file_streams/file_stream
import file_streams/file_stream_error.{type FileStreamError}
import gleam/result
import slog
import slog/internal/formatter

@target(erlang)
import gleam/io

@target(erlang)
import gleam/erlang/process

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
@external(javascript, "../slog_ffi.mjs", "console_error")
fn do_stderr(s: String, level: String) -> Nil

@target(erlang)
fn do_stderr(s: String, _level: String) -> Nil {
  // run IO in a separate process
  process.spawn_unlinked(fn() -> Nil { io.println_error(s) })
  Nil
}

pub type FileError {
  FileError(msg: String, posix: FileStreamError)
}

pub opaque type Configuration {
  Configuration(path: String, create_ok: Bool)
}

pub fn configure(path: String) -> Configuration {
  Configuration(path:, create_ok: False)
}

pub fn create_ok(c: Configuration, which: Bool) -> Configuration {
  Configuration(..c, create_ok: which)
}

pub fn file(config: Configuration) -> Result(slog.Sink, FileError) {
  case file_info(config.path) {
    Error(e) ->
      case e, config.create_ok {
        // error occurs on javascript when file stats are not yet available, YOLO opening the file
        file_stream_error.Enosys, _ -> open_file_for_write_sink(config.path)
        // file does not exist and ok to create it
        file_stream_error.Enoent, True -> open_file_for_write_sink(config.path)
        file_stream_error.Enoent, False ->
          Error(FileError(
            msg: "file at path "
              <> config.path
              <> "does not exist, creating file prohibited by configuration",
            posix: e,
          ))
        _, _ -> Error(FileError(msg: e |> file_stream_error.describe, posix: e))
      }
    Ok(a) ->
      case a.ftype, a.access {
        Regular, Write
        | Regular, ReadWrite
        | Symlink, Write
        | Symlink, ReadWrite
        -> open_file_for_write_sink(config.path)
        _, _ ->
          Error(FileError(
            msg: "File type and/or permissions do not allow writes: filetype="
              <> a.ftype |> ftype_to_string
              <> " permissions="
              <> a.access |> perm_to_string,
            posix: file_stream_error.Eacces,
          ))
      }
  }
}

// opens the file in append mode, file is created if it doesn't exist
// this is not an efficient implementation on Erlang, but is the only one that will work
// on both targets.  Better to use the supervised version on Erlang.
fn open_file_for_write_sink(path: String) -> Result(slog.Sink, FileError) {
  let f =
    file_stream.open(path, [
      file_open_mode.Append,
    ])
  case f {
    Error(e) -> Error(FileError(msg: e |> file_stream_error.describe, posix: e))
    Ok(file_handle) -> Ok(file_sink(file_handle))
  }
}

@target(erlang)
fn file_sink(file_handle: file_stream.FileStream) -> slog.Sink {
  fn(s: String, _level: slog.Level) -> Nil {
    process.spawn_unlinked(fn() {
      file_stream.write_chars(file_handle, s)
      |> result.lazy_unwrap(fn() { Nil })
    })
    Nil
  }
}

@target(javascript)
fn file_sink(file_handle: file_stream.FileStream) -> slog.Sink {
  fn(s: String, _level: slog.Level) -> Nil {
    file_stream.write_chars(file_handle, s)
    |> result.lazy_unwrap(fn() { Nil })
    Nil
  }
}

fn ftype_to_string(ft: Filetype) -> String {
  case ft {
    Regular -> "regular"
    Directory -> "directory"
    Symlink -> "symlink"
    Device -> "device"
    Other -> "other"
  }
}

fn perm_to_string(p: Permission) -> String {
  case p {
    Read -> "read"
    Write -> "write"
    ReadWrite -> "read_write"
    None -> "none"
  }
}

// https://www.erlang.org/doc/apps/kernel/file.html#t:file_info/0

type OptKey {
  Time
}

type OptValue {
  // returns access, mod, creation time in Unix seconds
  Posix
  // options not currently used
  //  Local
  //  Universal
}

pub type Filetype {
  Regular
  Directory
  Symlink
  Device
  Other
}

pub type Permission {
  Read
  Write
  ReadWrite
  None
}

pub type FileInfo {
  FileInfo(
    size: Int,
    ftype: Filetype,
    access: Permission,
    // access, mod, creation time in unix seconds
    atime: Int,
    mtime: Int,
    ctime: Int,
    mode: Int,
    links: Int,
    major_device: Int,
    minor_device: Int,
    inode: Int,
    uid: Int,
    gid: Int,
  )
}

pub fn file_info(path: String) -> Result(FileInfo, FileStreamError) {
  do_file_info(path, [#(Time, Posix)])
}

@target(erlang)
@external(erlang, "file", "read_file_info")
fn do_file_info(
  path: String,
  opts: List(#(OptKey, OptValue)),
) -> Result(FileInfo, FileStreamError)

@target(javascript)
fn do_file_info(
  _path: String,
  _opts: List(#(OptKey, OptValue)),
) -> Result(FileInfo, FileStreamError) {
  Error(file_stream_error.Enosys)
}
