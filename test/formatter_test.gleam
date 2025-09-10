import gleam/json
import gleam/option.{None, Some}
import gleam/string
import gleam/time/duration
import slog/attr
import slog/formatter.{LogLine}

pub fn json_simple_test() {
  let ll =
    LogLine(msg: Some("test"), ts: None, level: None, attrs: [
      attr.Int("test", 1),
      attr.String("a", "b"),
    ])
  assert formatter.json(ll) == Some("{'msg':'test','a':'b','test':1}" |> quote)
}

type Custom {
  Custom(a: String)
}

pub fn json_all_types_test() {
  let ll =
    LogLine(msg: Some("test"), ts: None, level: None, attrs: [
      attr.Int("a", 1),
      attr.String("b", "z"),
      attr.Bool("c", False),
      attr.Float("d", 2.4),
      attr.Duration("t_ms", duration.milliseconds(200)),
      attr.Any("any", Custom("any1"), fn(k, v: Custom) {
        #(k, json.string(v.a))
      }),
      attr.Group("g", [attr.Int("h", 1), attr.String("i", "j")]),
    ])
  assert formatter.json(ll)
    == Some(
      "{'msg':'test','g':{'h':1,'i':'j'},'any':'any1','t_ms':200.0,'d':2.4,'c':false,'b':'z','a':1}"
      |> quote,
    )
}

pub fn json_duration_test() {
  let ll =
    LogLine(msg: None, ts: None, level: None, attrs: [
      // auto should determine unit
      attr.Duration("auto", duration.milliseconds(4)),
      attr.Duration("auto", duration.milliseconds(3200)),
      attr.Duration("t_ms", duration.milliseconds(200)),
      attr.Duration("t_sec", duration.milliseconds(2400)),
    ])
  assert formatter.json(ll)
    == Some(
      "{'t_sec':2.4,'t_ms':200.0,'auto_s':3.2,'auto_ms':4.0}"
      |> quote,
    )
}

pub fn json_groups_test() {
  let ll =
    LogLine(msg: Some("test"), ts: None, level: None, attrs: [
      attr.Group("c", [attr.Int("d", 2), attr.String("e", "f")]),
      attr.Int("a", 1),
      attr.String("b", "z"),
    ])
  assert formatter.json(ll)
    == Some(
      "{'msg':'test','b':'z','a':1,'c':{'d':2,'e':'f'}}"
      |> quote,
    )
}

pub fn json_strict_test() {
  let ll =
    LogLine(msg: None, ts: None, level: None, attrs: [
      attr.Group("a", [attr.Int("d", 2), attr.String("e", "f")]),
      attr.Int("a", 1),
      attr.String("a", "z"),
    ])

  // lax formatter yields repeated keys
  assert formatter.json(ll)
    == Some(
      "{'a':'z','a':1,'a':{'d':2,'e':'f'}}"
      |> quote,
    )
  // strict formatter allows only one value per key, keeping the last value
  assert formatter.json_strict(ll)
    == Some(
      "{'a':{'d':2,'e':'f'}}"
      |> quote,
    )
}

fn quote(s: String) -> String {
  string.replace(s, "'", "\"")
}

pub fn json_none_test() {
  let ll = LogLine(msg: None, ts: None, level: None, attrs: [])
  assert formatter.json(ll) == None
}

pub fn logfmt_simple_test() {
  let ll =
    LogLine(msg: Some("test"), ts: None, level: None, attrs: [
      attr.Int("test", 1),
      attr.String("a", "b"),
    ])
  assert formatter.logfmt(ll) == Some("msg=test a=b test=1")
}

pub fn logfmt_quote_test() {
  let ll =
    LogLine(
      msg: Some("a message that should be quoted"),
      ts: None,
      level: None,
      attrs: [
        attr.Int("test", 1),
        attr.String("a", "b"),
      ],
    )
  assert formatter.logfmt(ll)
    == Some("msg=\"a message that should be quoted\" a=b test=1")
}

pub fn logfmt_all_types_test() {
  let ll =
    LogLine(msg: Some("test"), ts: None, level: None, attrs: [
      attr.Int("a", 1),
      attr.String("b", "z"),
      attr.Bool("c", False),
      attr.Float("d", 2.4),
      attr.Duration("t_ms", duration.milliseconds(200)),
      attr.Any("any", Custom("any1"), fn(k, v: Custom) {
        #(k, json.string(v.a))
      }),
    ])
  assert formatter.logfmt(ll)
    == Some("msg=test any=any1 t_ms=200.0 d=2.4 c=false b=z a=1")
}

pub fn logfmt_duration_test() {
  let ll =
    LogLine(msg: None, ts: None, level: None, attrs: [
      // auto should determine unit
      attr.Duration("auto", duration.milliseconds(4)),
      attr.Duration("auto", duration.milliseconds(3200)),
      attr.Duration("t_ms", duration.milliseconds(200)),
      attr.Duration("t_sec", duration.milliseconds(2400)),
    ])
  assert formatter.logfmt(ll)
    == Some("t_sec=2.4 t_ms=200.0 auto_s=3.2 auto_ms=4.0")
}

pub fn logfmt_groups_test() {
  let ll =
    LogLine(msg: Some("test"), ts: None, level: None, attrs: [
      attr.Group("c", [attr.Int("d", 2), attr.String("e", "f")]),
      attr.Int("a", 1),
      attr.String("b", "z"),
    ])
  assert formatter.logfmt(ll) == Some("msg=test b=z a=1 c.e=f c.d=2")
}

pub fn logfmt_strict_test() {
  let ll =
    LogLine(msg: None, ts: None, level: None, attrs: [
      attr.Group("a", [attr.Int("d", 2), attr.String("e", "f")]),
      attr.Int("a", 1),
      attr.String("a", "z"),
    ])

  // lax formatter yields repeated keys
  assert formatter.logfmt(ll) == Some("a=z a=1 a.e=f a.d=2")

  // strict formatter allows only one value per key, keeping the last value
  // note: this behavior is slightly different than the JSON formatter because of the dotted keys
  assert formatter.logfmt_strict(ll) == Some("a=1 a.d=2 a.e=f")
}

pub fn logfmt_none_test() {
  let ll = LogLine(msg: None, ts: None, level: None, attrs: [])
  assert formatter.logfmt(ll) == None
}
