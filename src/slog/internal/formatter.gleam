import gleam/dict
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/string
import slog/attr.{type Attr}

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
  case attrs_tuple_list {
    [] -> ""
    a -> a |> json.object |> json.to_string
  }
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

/// Create a Logfmt-formatted string from a list of attributes.  You should not need to call this directly.
///
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
        attr.Group(k, v) ->
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
  case string.contains(a.1, " ") {
    False -> a.0 <> "=" <> a.1 |> string.replace("\"", "")
    _ -> a.0 <> "=" <> a.1
  }
}
