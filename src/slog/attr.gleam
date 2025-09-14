import gleam/json
import gleam/list
import gleam/option.{type Option, Some}
import gleam/pair
import gleam/string
import gleam/time/duration

pub type Attr {
  String(k: String, v: String)
  Int(k: String, v: Int)
  Float(k: String, v: Float)
  Bool(k: String, v: Bool)
  Duration(k: String, v: duration.Duration)
  Group(k: String, v: List(Attr))
}

pub fn to_string_tuple(a: Attr, path: Option(String)) -> #(String, String) {
  let value =
    to_json_tuple(a)
    |> pair.map_second(json.to_string)
    |> pair.map_second(unquote)

  case path {
    Some(p) -> #(p <> "." <> value.0, value.1)
    _ -> value
  }
}

pub fn to_json_tuple(a: Attr) -> #(String, json.Json) {
  case a {
    Int(k, v) -> #(k, json.int(v))
    String(k, v) -> #(k, json.string(v))
    Float(k, v) -> #(k, json.float(v))
    Bool(k, v) -> #(k, json.bool(v))
    Duration(k, v) -> duration_to_float(k, v) |> pair.map_second(json.float)
    Group(k, v) -> #(k, v |> list.map(to_json_tuple) |> json.object)
  }
}

fn duration_to_float(k: String, v: duration.Duration) -> #(String, Float) {
  let to_msec = fn(n: Float) { n *. 1000.0 }
  let to_usec = fn(n: Float) { n *. 1_000_000.0 }

  // gleam can only match on string prefixes, so we reverse it and look for units listed
  // at the end of the key backwards
  case string.reverse(k) {
    // second (s, sec)
    "s_" <> _ -> #(k, v |> duration.to_seconds)
    "ces_" <> _ -> #(k, v |> duration.to_seconds)
    // millisecond (ms, msec)
    "sm_" <> _ -> #(k, v |> duration.to_seconds |> to_msec)
    "cesm_" <> _ -> #(k, v |> duration.to_seconds |> to_msec)
    // microsecond (μs, μsec, us, usec)
    "su_" <> _ -> #(k, v |> duration.to_seconds |> to_usec)
    "cesu_" <> _ -> #(k, v |> duration.to_seconds |> to_usec)
    "sμ_" <> _ -> #(k, v |> duration.to_seconds |> to_usec)
    "cesμ_" <> _ -> #(k, v |> duration.to_seconds |> to_usec)
    // auto adjust and update key for units
    _ ->
      case duration.to_seconds_and_nanoseconds(v) {
        #(0, ns) if ns >= 1_000_000 -> duration_to_float(k <> "_ms", v)
        #(0, _) -> duration_to_float(k <> "_us", v)
        #(_, _) -> duration_to_float(k <> "_s", v)
      }
  }
}

fn unquote(a: String) -> String {
  case string.contains(a, " ") {
    True -> a
    _ -> string.replace(a, "\"", "")
  }
}
