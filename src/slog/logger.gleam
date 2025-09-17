import gleam/list
import gleam/time/timestamp.{type Timestamp}
import slog/attr

pub type Attr =
  attr.Attr

pub type Logger(state) {
  Logger(
    state: state,
    with: fn(Logger(state), Attr) -> Logger(state),
    log: fn(Logger(state), Level, String) -> Nil,
  )
}

pub type Formatter =
  fn(Timestamp, Level, String, List(Attr)) -> String

pub type Sink =
  fn(String) -> Nil

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

pub fn new(max_level: Level, formatter: Formatter, sink: Sink) {
  let initial_state = Direct(max_level: max_level, attrs: [])
  let with = fn(logger, attr) {
    Logger(
      ..logger,
      state: Direct(..logger.state, attrs: [attr, ..logger.state.attrs]),
    )
  }
  let log = fn(logger: Logger(State), level, msg) {
    case level_to_int(level) <= level_to_int(max_level) {
      False -> Nil
      _ -> {
        let ts = timestamp.system_time()
        formatter(ts, level, msg, logger.state.attrs)
        |> sink
      }
    }
  }
  Logger(initial_state, with, log)
}

pub fn with(l: Logger(state), a: Attr) -> Logger(state) {
  l.with(l, a)
}

pub fn with_attrs(l: Logger(state), a: List(Attr)) -> Logger(state) {
  a |> list.fold(l, l.with)
}

pub fn all(l: Logger(state), msg: String) {
  l.log(l, ALL, msg)
}

pub fn error(l: Logger(state), msg: String) {
  l.log(l, ERROR, msg)
}

pub fn warn(l: Logger(state), msg: String) {
  l.log(l, WARN, msg)
}

pub fn info(l: Logger(state), msg: String) {
  l.log(l, INFO, msg)
}

pub fn debug(l: Logger(state), msg: String) {
  l.log(l, DEBUG, msg)
}
