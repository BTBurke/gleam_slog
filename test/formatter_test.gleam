import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import slog
import slog/attr
import slog/format
import slog/internal/formatter
import slog/sink

fn json(a: List(attr.Attr), strict strict: Bool, flat flat: Bool) -> String {
  formatter.to_json(a |> list.reverse, strict:, flat:)
}

fn logfmt(a: List(attr.Attr), strict strict: Bool) -> String {
  formatter.to_logfmt(a |> list.reverse, strict:)
}

pub fn json_simple_test() {
  let ll = [
    attr.String("msg", "test"),
    attr.Int("test", 1),
    attr.String("a", "b"),
  ]
  assert json(ll, False, False) == "{'a':'b','test':1,'msg':'test'}" |> quote
}

pub fn json_all_types_test() {
  let ll = [
    attr.String("msg", "test"),
    attr.Int("a", 1),
    attr.String("b", "z"),
    attr.Bool("c", False),
    attr.Float("d", 2.4),
    attr.Duration("t_ms", duration.milliseconds(200)),
    attr.Group("g", [attr.Int("h", 1), attr.String("i", "j")]),
  ]
  assert json(ll, False, False)
    == "{'g':{'h':1,'i':'j'},'t_ms':200.0,'d':2.4,'c':false,'b':'z','a':1,'msg':'test'}"
    |> quote
}

pub fn json_duration_test() {
  let ll = [
    // auto should determine unit
    attr.Duration("auto", duration.milliseconds(4)),
    attr.Duration("auto", duration.milliseconds(3200)),
    attr.Duration("t_ms", duration.milliseconds(200)),
    attr.Duration("t_sec", duration.milliseconds(2400)),
  ]
  assert json(ll, False, False)
    == "{'t_sec':2.4,'t_ms':200.0,'auto_s':3.2,'auto_ms':4.0}"
    |> quote
}

pub fn json_groups_test() {
  let ll = [
    attr.Group("c", [attr.Int("d", 2), attr.String("e", "f")]),
    attr.Int("a", 1),
    attr.String("b", "z"),
  ]
  assert json(ll, strict: False, flat: False)
    == "{'b':'z','a':1,'c':{'d':2,'e':'f'}}"
    |> quote
}

pub fn json_strict_test() {
  let ll = [
    attr.Group("a", [attr.Int("d", 2), attr.String("e", "f")]),
    attr.Int("a", 1),
    attr.String("a", "z"),
  ]

  // lax formatter yields repeated keys
  assert json(ll, strict: False, flat: False)
    == "{'a':'z','a':1,'a':{'d':2,'e':'f'}}"
    |> quote
  // strict formatter allows only one value per key, keeping the last value
  assert json(ll, strict: True, flat: False)
    == "{'a':{'d':2,'e':'f'}}"
    |> quote
}

fn quote(s: String) -> String {
  string.replace(s, "'", "\"")
}

pub fn json_none_test() {
  assert json([], strict: False, flat: False) == ""
}

pub fn logfmt_simple_test() {
  let ll = [
    attr.String("msg", "test"),
    attr.Int("test", 1),
    attr.String("a", "b"),
  ]
  assert logfmt(ll, strict: False) == "a=b test=1 msg=test"
}

pub fn logfmt_quote_test() {
  let ll = [
    attr.String("msg", "a message that should be quoted"),
    attr.Int("test", 1),
    attr.String("a", "b"),
  ]
  assert logfmt(ll, strict: False)
    == "a=b test=1 msg=\"a message that should be quoted\""
}

pub fn logfmt_all_types_test() {
  let ll = [
    attr.Int("a", 1),
    attr.String("b", "z"),
    attr.Bool("c", False),
    attr.Float("d", 2.4),
    attr.Duration("t_ms", duration.milliseconds(200)),
  ]
  assert logfmt(ll, strict: False) == "t_ms=200.0 d=2.4 c=false b=z a=1"
}

pub fn logfmt_duration_test() {
  let ll = [
    // auto should determine unit
    attr.Duration("auto", duration.milliseconds(4)),
    attr.Duration("auto", duration.milliseconds(3200)),
    attr.Duration("t_ms", duration.milliseconds(200)),
    attr.Duration("t_sec", duration.milliseconds(2400)),
  ]
  assert logfmt(ll, strict: False)
    == "t_sec=2.4 t_ms=200.0 auto_s=3.2 auto_ms=4.0"
}

pub fn logfmt_groups_test() {
  let ll = [
    attr.String("msg", "test"),
    attr.Group("c", [attr.Int("d", 2), attr.String("e", "f")]),
    attr.Int("a", 1),
    attr.String("b", "z"),
  ]
  assert logfmt(ll, strict: False) == "b=z a=1 c.e=f c.d=2 msg=test"
}

pub fn logfmt_strict_test() {
  let ll = [
    attr.Group("a", [attr.Int("d", 2), attr.String("e", "f")]),
    attr.Int("a", 1),
    attr.String("a", "z"),
  ]

  // lax formatter yields repeated keys
  assert logfmt(ll, strict: False) == "a=z a=1 a.e=f a.d=2"

  // strict formatter allows only one value per key, keeping the last value
  // note: this behavior is slightly different than the JSON formatter because of the dotted keys
  assert logfmt(ll, strict: True) == "a=1 a.d=2 a.e=f"
}

pub fn logfmt_none_test() {
  assert logfmt([], strict: False) == ""
}

// tests the algorithm for conversion back and forth from unix nano
pub fn unixnano_test() {
  let ts = timestamp.system_time()
  let as_string =
    ts
    |> timestamp.to_unix_seconds_and_nanoseconds()
    |> fn(a) {
      a.0 |> int.to_string
      <> a.1 |> int.to_string |> string.pad_start(to: 9, with: "0")
    }
  let nano_part =
    as_string
    |> string.slice(at_index: -9, length: 9)
    |> int.parse
    |> result.unwrap(0)
  let sec_part =
    as_string |> string.drop_end(up_to: 9) |> int.parse |> result.unwrap(0)

  assert ts == timestamp.from_unix_seconds_and_nanoseconds(sec_part, nano_part)
}

fn ts0() -> timestamp.Timestamp {
  timestamp.from_unix_seconds(0)
}

pub fn terminal_test() {
  let terminal_formatter =
    format.configure() |> format.terminal_colors(False) |> format.terminal
  let a = [
    attr.String("service", "frobulator"),
    attr.Int("retries", 99),
  ]
  let logline = terminal_formatter(ts0(), slog.ERROR, "something went wrong", a)
  assert logline == "ERROR  something went wrong  retries=99 service=frobulator"
}

pub fn fileinfo_test() {
  let a = sink.do_file_info("./test/formattertest.gleam")
  let size = case a {
    Ok(a) -> {
      decode.run(a, decode.at([1], decode.int))
      |> option.from_result
    }
    _ -> option.None
  }
  echo size
}
