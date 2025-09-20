import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import slog.{type Level}
import slog/attr.{type Attr}
import slog/internal/formatter

/// Function that takes required elements of the log state and returns a formatted log line
///
pub type Formatter =
  slog.Formatter

/// Configuration builder to control formatting options
///
pub opaque type Configuration {
  Config(
    strict: Bool,
    flat: Bool,
    time_key: String,
    msg_key: String,
    level_key: String,
    time_format: TimeFormat,
    duration_format: DurationFormat,
    terminal_max_width: Int,
    terminal_colors: Bool,
  )
}

/// Time format defaults to RFC3339.  Unix times are always represented as a string to prevent loss of precision,
/// which is what most logging aggregators expect. Use `NoTimestamp` to drop timestamps from the output.
///
pub type TimeFormat {
  UnixSeconds
  UnixNanoseconds
  RFC3339
  NoTimestamp
}

/// Duration format defaults to `KeyWithUnits`. Units specified in the key suffix are used to convert duration values
/// to a common unit. This is useful if your log aggregator allows computing statistics based on the values but has no
/// mechanism to compare durations in different units.
///
/// Some log aggregators deal with units attached to the value, allowing measurements in different units to be
/// compared appropriately.
///
/// Allowable units in the key suffix are:
/// * Seconds = `_s`, `_sec`
/// * Milliseconds = `_ms`, `_msec`
/// * Microseconds = `_us`, `_usec`, `_µs`, `_µsec`
///
/// Examples: `request_ms`, `query_usec`
///
/// If the key lacks a unit suffix, an appropriate unit is chosen based on the magnitude of the
/// duration and the suffix added to the key.
///
/// # Example
/// ```gleam
/// // suppose you create a log attribute for a measured time and want
/// // all output values to be in milliseconds, so the key ends in _ms
/// attr.Duration("request_ms", duration.microseconds(2000))
///
/// // KeyWithUnits looks for the units you want at the end of the key.  If none
/// // is specified, an appropriate unit for the magnitude of the value is chosen.  In
/// // this case, the key ending in "_ms" or "_msec" is converted to a value in milliseconds
/// // so that every value for this key is in a common unit.  This can help with doing basic math
/// // using the query language of your log aggregator.
/// {"request_ms": 2.0}
///
/// // ValueWithUnits is useful with some log aggregators which parse durations as strings
/// // with units.  The unit is stripped from the key if it exists, but used to convert the value to
/// // the desired unit.
/// {"request": "2.0ms"}
///
/// // Dimensionless strips units and outputs a value with no units as a float.  If the unit was in the key,
/// // it will determine the units of the number. A key without a unit suffix is not recommended unless you
/// // know that all values are of the same order of magnitude.
/// {"request": 2.0}
/// ```
///
pub type DurationFormat {
  KeyWithUnits
  ValueWithUnits
  Dimensionless
}

/// Create a new configuration with the default settings.
///
/// # Defaults
///
/// * Formatter is strict. Last write wins for multiple attributes with the same key.
/// * Keys are flattened when using attribute groups.  For example, `Group("a", Int("b", 1))` would yield a key of `a.b` for both JSON and logfmt.  When `flatten_keys=False`, the JSON version would yield `a: {b: 1}`.  Logfmt is always flattened per the spec and would yield `a.b=1`.
/// * The key for the timestamp is `time`.  Set a different with [time_key](#time_key).
/// * The key for the log message is `msg`.  Set a different key with [msg_key](#msg_key).
/// * The key for level is `level`. Set a different key with [level_key](#level_key).
/// * Time format is RFC3339. Set a different format with [time_format](#time_format).
///
/// # Schemas
///
/// Log aggregators expect different formats for keys and required fields.  Check [slog/schema](/slog/schema.html) for
/// popular solutions.  The schema provides a formatter that your aggregator expects, along with additional options
/// unique to different aggregators (e.g.,  log streams).
///
/// # Example
/// ```gleam
/// // changing the defaults to lax formatting allowing duplicate keys and
/// // level key as "severity" instead of "level" with JSON format
/// let formatter =
///    format.configure()
///    |> format.strict(False)
///    |> format.level_key("severity")
///    |> format.json
/// let log = slog.new(max_level: slog.INFO, formatter:, sink: sink.stdout)
/// ```
///
pub fn configure() -> Configuration {
  Config(
    strict: True,
    flat: True,
    time_key: "time",
    msg_key: "msg",
    level_key: "level",
    time_format: RFC3339,
    duration_format: KeyWithUnits,
    terminal_max_width: 100,
    terminal_colors: True,
  )
}

/// Strict mode removes duplicate keys with last write wins.  If group keys are flattened, a duplicate is removed only
/// if the entire flattened path matches.  This option is ignored for Javascript, as objects
/// are always strict.
///
pub fn strict(config: Configuration, which: Bool) -> Configuration {
  Config(..config, strict: which)
}

/// Flattens a group key to prevent nested values.  For example, a log group that produces nested JSON like
/// `{"request": {"path": "test", "method": "POST"}}` would flatten to `{"request.path": "test", "request.method": "POST"}`.
/// Changing this has no effect on logfmt-based formatters, which are always flattened.
///
pub fn flatten_keys(config: Configuration, which: Bool) -> Configuration {
  Config(..config, flat: which)
}

/// Set the key used for the timestamp.  Defaults to "time".
///
pub fn time_key(config: Configuration, key: String) -> Configuration {
  Config(..config, time_key: key)
}

/// Set the key used for the log message.  Defaults to "msg".
///
pub fn msg_key(config: Configuration, key: String) -> Configuration {
  Config(..config, msg_key: key)
}

/// Set the key used for log severity level.  Defaults to "level".
///
pub fn level_key(config: Configuration, key: String) -> Configuration {
  Config(..config, level_key: key)
}

/// Set the time format.  Defaults to RFC3339.
///
pub fn time_format(config: Configuration, format: TimeFormat) -> Configuration {
  Config(..config, time_format: format)
}

/// Set the duration format.  Defaults to `KeyWithUnits`.
///
pub fn duration_format(
  config: Configuration,
  format: DurationFormat,
) -> Configuration {
  Config(..config, duration_format: format)
}

/// Set the terminal max width. This only applies to the terminal formatter.
pub fn terminal_max_width(
  config: Configuration,
  max_width: Int,
) -> Configuration {
  Config(..config, terminal_max_width: max_width)
}

/// Set terminal colors for log levels. This only applies to the terminal formatter.
pub fn terminal_colors(config: Configuration, which: Bool) -> Configuration {
  Config(..config, terminal_colors: which)
}

/// Use JSON format for log lines.  See [configure](#configure) for defaults and other options.  Returns
/// a [Formatter](#Formatter) used when creating a new logger.
///
/// # Example
/// ```gleam
/// // A new logger with level key "severity" and JSON output
/// let formatter = format.configure() |> format.level_key("severity") |> format.json
/// let log = slog.new(max_level: INFO, formatter:, sink: sink.stdout)
///
/// log |> with(attr.String("log", "test")) |> info("testing slog")
/// // Output:
/// // {"time":<time>,"severity":"INFO","msg":"testing slog","log":"test"}
/// ```
///
pub fn json(config: Configuration) -> Formatter {
  fn(ts: Timestamp, level: Level, msg: String, attrs: List(Attr)) -> String {
    let Config(
      strict,
      flat,
      time_key,
      msg_key,
      level_key,
      time_format,
      duration_format,
      _width,
      _colors,
    ) = config
    let attrs =
      attrs
      |> list.reverse
      |> list.map(format_duration(format: duration_format))
      |> add_ts_level_msg(
        ts,
        level,
        msg,
        time_key:,
        msg_key:,
        level_key:,
        time_format:,
      )
    attrs |> formatter.to_json(strict:, flat:)
  }
}

// adds a timestamp, level, and msg as attributes to the logger using config options to determine formats
fn add_ts_level_msg(
  a: List(Attr),
  ts: Timestamp,
  level: Level,
  msg: String,
  time_key time_key: String,
  msg_key msg_key: String,
  level_key level_key: String,
  time_format time_format: TimeFormat,
) -> List(Attr) {
  [
    case time_format {
      RFC3339 ->
        attr.String(time_key, ts |> timestamp.to_rfc3339(calendar.utc_offset))
      UnixSeconds ->
        attr.String(
          time_key,
          ts |> timestamp.to_unix_seconds() |> float.to_string,
        )
      UnixNanoseconds ->
        attr.String(
          time_key,
          ts
            |> timestamp.to_unix_seconds_and_nanoseconds()
            |> fn(a) {
              a.0 |> int.to_string
              <> a.1 |> int.to_string |> string.pad_start(to: 9, with: "0")
            },
        )
      NoTimestamp -> attr.String("", "")
    },
    attr.String(level_key, level |> formatter.level_to_string),
    attr.String(msg_key, msg),
    ..a
  ]
  // remove empty keys
  |> list.filter(fn(a) { a.k != "" })
}

// formats duration attributes according to config option
fn format_duration(format format: DurationFormat) {
  fn(a: Attr) -> Attr {
    case a {
      attr.Duration(k, v) ->
        case format {
          KeyWithUnits -> a
          ValueWithUnits -> {
            let d = attr.duration_to_float(k, v)
            let unit =
              d.0 |> string.split("_") |> list.last |> result.unwrap("")
            attr.String(
              d.0 |> string.replace("_" <> unit, ""),
              d.1 |> float.to_string <> unit,
            )
          }
          Dimensionless -> {
            let d = attr.duration_to_float(k, v)
            let unit =
              d.0 |> string.split("_") |> list.last |> result.unwrap("")
            attr.Float(d.0 |> string.replace("_" <> unit, ""), d.1)
          }
        }
      _ -> a
    }
  }
}

/// Use Logfmt format for log lines.  See [configure](#configure) for defaults and other options.  Returns
/// a [Formatter](#Formatter) used when creating a new logger.
///
/// # Example
/// ```gleam
/// // A new logger with level key "severity" and Logfmt output
/// let formatter = format.configure() |> format.level_key("severity") |> format.logfmt
/// let log = slog.new(max_level: INFO, formatter:, sink: sink.stdout)
///
/// log |> with(attr.String("log", "test")) |> info("testing slog")
/// // Output:
/// // time=<time> severity=INFO msg="testing slog" log=test
/// ```
///
pub fn logfmt(config: Configuration) -> Formatter {
  fn(ts: Timestamp, level: Level, msg: String, attrs: List(Attr)) -> String {
    let Config(
      strict,
      _flat,
      time_key,
      msg_key,
      level_key,
      time_format,
      duration_format,
      _width,
      _colors,
    ) = config
    let attrs =
      attrs
      // preserve insertion order in output
      |> list.reverse
      // convert durations to appropriate format
      |> list.map(format_duration(format: duration_format))
      // add timestamp, level, msg as formatter attrs according to options
      |> add_ts_level_msg(
        ts,
        level,
        msg,
        time_key:,
        msg_key:,
        level_key:,
        time_format:,
      )
    attrs |> formatter.to_logfmt(strict:)
  }
}

/// Use a formatter designed for the terminal during development -- compact and readable. The width at which to wrap lines
/// and whether to use colors can be set using configuration options [terminal_max_width](#terminal_max_width)
/// and [terminal_colors](#terminal_colors).  Default is wrapping at column 100 and to use colors for log levels.
///
/// # Example
/// ```gleam
/// let formatter =
///   format.configure()
///   |> format.terminal_colors(False)
///   |> format.terminal
/// let development_logger = slog.new(max_level: slog.DEBUG, formatter:, sink: sink.stdout)
///
/// development_logger
///   |> with_attrs([attr.String("service", "frobulator"), attr.Int("retries", 99)])
///   |> error("something went wrong")
/// // output:
/// // ERROR  something went wrong  service=frobulator retries=99
/// ```
pub fn terminal(config: Configuration) -> Formatter {
  fn(_ts: Timestamp, level: Level, msg: String, attrs: List(Attr)) -> String {
    let separator = "  "
    let formatted_attrs =
      attrs
      |> list.reverse
      |> list.map(format_duration(format: ValueWithUnits))
      |> formatter.to_logfmt(strict: True)

    let formatted_level = case level {
      slog.ERROR -> level |> formatter.level_to_string |> red
      slog.WARN -> level |> formatter.level_to_string |> yellow
      slog.DEBUG -> level |> formatter.level_to_string |> pink
      _ -> level |> formatter.level_to_string
    }
    let full_width =
      case config.terminal_colors {
        True -> formatted_level
        _ -> level |> formatter.level_to_string
      }
      |> string.pad_end(to: 5, with: " ")
      <> separator
      <> case config.terminal_colors {
        True -> msg |> bold
        _ -> msg
      }
      <> separator
      <> formatted_attrs

    case string.length(full_width) > config.terminal_max_width {
      False -> full_width
      _ -> {
        // TODO: find a fancier way to split on spaces and wrap lines by column
        let chunked =
          full_width
          |> string.to_graphemes
          |> list.sized_chunk(into: config.terminal_max_width)
        chunked
        // stitch graphemes back together into one terminal line
        |> list.map(fn(s) { string.join(s, "") })
        // join terminal lines with continuation marker
        |> string.join("\n   ↪")
      }
    }
  }
}

// ----------  ANSI color codes -------------
//
fn code(i: List(Int)) -> String {
  "\u{001b}[" <> i |> list.map(int.to_string) |> string.join(";") <> "m"
}

fn red(s: String) -> String {
  code([31]) <> s <> code([39])
  // Alt: 91 is bright red
}

fn pink(s: String) -> String {
  code([38, 5, 219]) <> s <> code([39])
}

fn yellow(s: String) -> String {
  code([33]) <> s <> code([39])
  // Alt: 93 is bright yellow
}

fn bold(s: String) -> String {
  code([1]) <> s <> code([22])
}
