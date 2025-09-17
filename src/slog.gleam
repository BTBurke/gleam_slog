import gleam/list
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}
import slog/attr

pub type Attr =
  attr.Attr

pub type Logger(state) {
  Logger(
    state: state,
    with: fn(state, Attr) -> state,
    log: fn(state, Level, String) -> Nil,
  )
}

pub type Formatter =
  fn(Timestamp, Level, String, List(Attr)) -> String

pub type Sink =
  fn(String, Level) -> Nil

pub type Level {
  ALL
  ERROR
  WARN
  INFO
  DEBUG
}

fn level_to_int(l: Level) -> Int {
  case l {
    ALL -> 0
    ERROR -> 10
    WARN -> 20
    INFO -> 30
    DEBUG -> 99
  }
}

pub opaque type State {
  Direct(max_level: Level, attrs: List(Attr))
}

pub fn new(formatter: Formatter, sink: Sink, log_level: Level) {
  let initial_state = Direct(max_level: log_level, attrs: [])
  let with = fn(state, attr) { Direct(..state, attrs: [attr, ..state.attrs]) }
  let log = fn(state: State, level, msg) {
    case level_to_int(level) <= level_to_int(log_level) {
      False -> Nil
      _ -> {
        let ts = timestamp.system_time()
        formatter(ts, level, msg, state.attrs)
        |> sink(level)
      }
    }
  }
  Logger(initial_state, with, log)
}

pub fn with(l: Logger(state), a: Attr) -> Logger(state) {
  Logger(..l, state: l.with(l.state, a))
}

pub fn with_attrs(l: Logger(state), a: List(Attr)) -> Logger(state) {
  Logger(..l, state: a |> list.fold(l.state, l.with))
}

pub fn all(l: Logger(state), msg: String) {
  l.log(l.state, ALL, msg)
}

pub fn error(l: Logger(state), msg: String) {
  l.log(l.state, ERROR, msg)
}

pub fn warn(l: Logger(state), msg: String) {
  l.log(l.state, WARN, msg)
}

pub fn info(l: Logger(state), msg: String) {
  l.log(l.state, INFO, msg)
}

pub fn debug(l: Logger(state), msg: String) {
  l.log(l.state, DEBUG, msg)
}

pub fn log(l: Logger(state), level: Level, msg: String) {
  l.log(l.state, level, msg)
}

pub fn string(l: Logger(state), key: String, value: String) -> Logger(state) {
  l |> with(attr.String(key, value))
}

pub fn int(l: Logger(state), key: String, value: Int) -> Logger(state) {
  l |> with(attr.Int(key, value))
}

pub fn float(l: Logger(state), key: String, value: Float) -> Logger(state) {
  l |> with(attr.Float(key, value))
}

pub fn bool(l: Logger(state), key: String, value: Bool) -> Logger(state) {
  l |> with(attr.Bool(key, value))
}

pub fn duration(
  l: Logger(state),
  key: String,
  value: duration.Duration,
) -> Logger(state) {
  l |> with(attr.Duration(key, value))
}

pub fn group(l: Logger(state), key: String, value: List(Attr)) -> Logger(state) {
  l |> with(attr.Group(key, value))
}
