import gleam/dict
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import slog/attr.{type Attr, Group}
import slog/logger.{type Level}

pub type Formatter =
  logger.Formatter

pub opaque type Configuration {
  Config(strict: Bool, flat: Bool, time_key: String, msg_key: String)
}

/// Create a new configuration with the default settings.
///
/// # Defaults
///
/// - Formatter is strict. Last write wins for multiple attributes with the same key.
/// - Keys are flattened when using attribute groups.  For example, `Group("a", Int("b", 1))` would yield a key of `a.b` for both JSON and logfmt.  When `flatten_keys=False`, the JSON version would yield `a: {b: 1}`.  Logfmt is always flattened per the spec and would yield `a.b=1`.
/// - The key for the timestamp is `ts`. The expected timestamp key can vary depending on your log aggregator.  Set it with `time_key`.
/// - The key for the log message is `msg`.  Set a different key with `msg_key`.
///
pub fn configure() -> Configuration {
  Config(strict: True, flat: True, time_key: "ts", msg_key: "msg")
}

pub fn strict(config: Configuration, which: Bool) -> Configuration {
  Config(..config, strict: which)
}

pub fn flatten_keys(config: Configuration, which: Bool) -> Configuration {
  Config(..config, flat: which)
}

pub fn time_key(config: Configuration, key: String) -> Configuration {
  Config(..config, time_key: key)
}

pub fn msg_key(config: Configuration, key: String) -> Configuration {
  Config(..config, msg_key: key)
}

/// Use JSON format for log lines.  See `configure()` for defaults and other options.
///
pub fn json(config: Configuration) -> Formatter {
  fn(ts: Timestamp, level: Level, msg: String, attrs: List(Attr)) -> String {
    let attrs =
      attrs
      |> list.reverse
      |> add_ts_level_msg(
        ts,
        level,
        msg,
        time_key: config.time_key,
        msg_key: config.msg_key,
      )
    attrs |> to_json(strict: config.strict, flat: config.flat)
  }
}

/// Create a JSON-formatted string from a list of attributes.  You should not need to call this directly.
///
pub fn to_json(
  attrs: List(Attr),
  strict strict: Bool,
  flat flat: Bool,
) -> String {
  let attrs_tuple_list = case flat {
    True -> to_json_tuple_flat([], attrs, None, strict)
    _ -> to_json_tuple(attrs, strict)
  }
  attrs_tuple_list |> json.object |> json.to_string
}

fn add_ts_level_msg(
  a: List(Attr),
  ts: Timestamp,
  level: Level,
  msg: String,
  time_key time_key: String,
  msg_key msg_key: String,
) -> List(Attr) {
  [
    attr.String(time_key, ts |> timestamp.to_rfc3339(calendar.utc_offset)),
    attr.String("level", level |> level_to_string),
    attr.String(msg_key, msg),
    ..a
  ]
}

/// Convert a list of attributes to a `#(String, JSON)` pair.  You should not need to call this directly, but it
/// may be a useful intermediate data structure if developing a custom formatter.
///
pub fn to_json_tuple(attrs: List(Attr), strict: Bool) -> List(#(String, Json)) {
  // strictness is defined as the removal of repeated keys, keeping only the last value for each unique key
  case strict {
    False -> attrs |> list.map(attr.to_json_tuple)
    _ -> attrs |> list.map(attr.to_json_tuple) |> dict.from_list |> dict.to_list
  }
}

pub fn logfmt(config: Configuration) -> Formatter {
  fn(ts: Timestamp, level: Level, msg: String, attrs: List(Attr)) -> String {
    let attrs =
      attrs
      |> list.reverse
      |> add_ts_level_msg(
        ts,
        level,
        msg,
        time_key: config.time_key,
        msg_key: config.msg_key,
      )
    attrs |> to_logfmt(strict: config.strict)
  }
}

pub fn to_logfmt(attrs: List(Attr), strict strict: Bool) -> String {
  attrs |> to_string_tuple(strict) |> list.map(join_logfmt) |> string.join(" ")
}

/// Convert a list of attributes to a `#(String, String)` pair.  You should not need to call this directly, but it
/// may be a useful intermediate data structure if developing a custom formatter.
///
pub fn to_string_tuple(
  attrs: List(Attr),
  strict: Bool,
) -> List(#(String, String)) {
  to_json_tuple_flat([], attrs, None, strict)
  |> list.map(fn(a) { #(a.0, a.1 |> json.to_string) })
}

/// Convert a list of attributes to a `#(String, JSON)` pair with grouped or nested keys flattened.  You should not need to call this directly, but it
/// may be a useful intermediate data structure if developing a custom formatter.
///
pub fn to_json_tuple_flat(
  acc: List(#(String, Json)),
  a: List(Attr),
  p: Option(String),
  strict: Bool,
) -> List(#(String, Json)) {
  case a {
    [] ->
      case strict {
        True -> acc |> list.reverse |> dict.from_list |> dict.to_list
        _ -> acc |> list.reverse
      }
    [first, ..rest] ->
      case first {
        Group(k, v) ->
          to_json_tuple_flat(
            list.append(
              to_json_tuple_flat([], v, Some(join_key(p, k)), False),
              acc,
            ),
            rest,
            p,
            strict,
          )

        _ -> {
          // get flat key and json value
          let k = attr.to_string_tuple(first, p) |> pair.first
          let v = attr.to_json_tuple(first) |> pair.second
          to_json_tuple_flat([#(k, v), ..acc], rest, p, strict)
        }
      }
  }
}

/// produces flattened keys
fn join_key(p: Option(String), k: String) -> String {
  case p {
    None -> k
    Some(path) -> path <> "." <> k
  }
}

fn join_logfmt(a: #(String, String)) -> String {
  a.0 <> "=" <> a.1
}

fn level_to_string(l: Level) -> String {
  case l {
    logger.ALL -> "ALL"
    logger.ERROR -> "ERROR"
    logger.WARN -> "WARN"
    logger.INFO -> "INFO"
    logger.DEBUG -> "DEBUG"
  }
}
