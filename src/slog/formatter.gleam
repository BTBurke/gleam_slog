import gleam/dict
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import slog/attr.{type Attr, Group, to_tuple_json, to_tuple_string}

pub type LogLine(v) {
  LogLine(
    msg: Option(String),
    level: Option(Int),
    ts: Option(Timestamp),
    attrs: List(Attr(v)),
  )
}

pub fn json(ll: LogLine(v)) -> Option(String) {
  do_json(ll, False)
}

pub fn json_strict(ll: LogLine(v)) -> Option(String) {
  do_json(ll, True)
}

fn do_json(ll: LogLine(v), strict: Bool) -> Option(String) {
  let attrs =
    ll.attrs
    // preserve order of insertion in logline
    |> list.reverse
    |> add_msg(ll.msg)
    |> add_timestamp(ll.ts)

  case attrs |> list.is_empty {
    // empty logline
    True -> None

    // marshal to json, controlling order so ts, msg appear first, then attrs, then groups
    _ -> {
      // strictness is defined as the removal of repeated keys, keeping only the last value for each unique key
      let attrs_json = case strict {
        False -> attrs |> list.map(to_tuple_json)
        _ -> attrs |> list.map(to_tuple_json) |> dict.from_list |> dict.to_list
      }

      attrs_json
      |> json.object
      |> json.to_string
      |> Some
    }
  }
}

pub fn logfmt(ll: LogLine(v)) -> Option(String) {
  do_logfmt(ll, False)
}

pub fn logfmt_strict(ll: LogLine(v)) -> Option(String) {
  do_logfmt(ll, True)
}

fn do_logfmt(ll: LogLine(v), strict: Bool) -> Option(String) {
  let attrs =
    ll.attrs
    // preserve order of insertion in logline
    |> list.reverse
    |> add_msg(ll.msg)
    |> add_timestamp(ll.ts)

  case attrs |> list.is_empty {
    // empty logline
    True -> None

    // marshal, controlling order so ts, msg appear first, then attrs, then groups
    _ -> {
      // strictness is defined as the removal of repeated keys, keeping only the last value for each unique key
      let attrs_log = case strict {
        False -> to_tuple_list([], attrs, None)
        _ -> to_tuple_list([], attrs, None) |> dict.from_list |> dict.to_list
      }

      attrs_log
      |> list.map(join_logfmt)
      |> string.join(" ")
      |> Some
    }
  }
}

fn to_tuple_list(
  acc: List(#(String, String)),
  a: List(Attr(v)),
  p: Option(String),
) -> List(#(String, String)) {
  case a {
    [] -> acc |> list.reverse
    [first, ..rest] ->
      case first {
        Group(k, v) ->
          to_tuple_list(
            list.append(to_tuple_list([], v, Some(join_key(p, k))), acc),
            rest,
            p,
          )

        _ -> to_tuple_list([to_tuple_string(first, p), ..acc], rest, p)
      }
  }
}

fn join_key(p: Option(String), k: String) -> String {
  case p {
    None -> k
    Some(path) -> path <> "." <> k
  }
}

fn join_logfmt(a: #(String, String)) -> String {
  a.0 <> "=" <> a.1
}

fn add_msg(attrs: List(Attr(v)), msg: Option(String)) -> List(Attr(v)) {
  case msg {
    Some(m) -> [attr.String("msg", m), ..attrs]
    _ -> attrs
  }
}

fn add_timestamp(attrs: List(Attr(v)), ts: Option(Timestamp)) -> List(Attr(v)) {
  case ts {
    Some(t) -> [
      attr.String("ts", t |> timestamp.to_rfc3339(calendar.utc_offset)),
      ..attrs
    ]
    _ -> attrs
  }
}
