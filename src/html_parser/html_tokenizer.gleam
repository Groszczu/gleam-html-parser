import gleam/list
import gleam/map.{Map}
import gleam/string
import gleam/regex

type TokenizerState {
  // TODO: CharacterReferenceInAttributeValueState(allowed_char: String)
  DataState
  TagOpenState
  EndTagOpenState
  TagNameState(tag_props: TagTokenProps)
  SelfClosingStartTagState(tag_props: TagTokenProps)
  BeforeAttributeNameState(tag_props: TagTokenProps)
  AttributeNameState(tag_props: TagTokenProps, attribute: #(String, String))
  AfterAttributeNameState(
    tag_props: TagTokenProps,
    attribute: #(String, String),
  )
  BeforeAttributeValueState(
    tag_props: TagTokenProps,
    attribute: #(String, String),
  )
  AttributeValueState(
    tag_props: TagTokenProps,
    attribute: #(String, String),
    quote_type: AttributeValueType,
  )
  AfterAttributeValueState(tag_props: TagTokenProps)
}

type AttributeValueType {
  SingleQuoted
  DoubleQuoted
  Unquoted
}

pub type TagTokenProps {
  TagTokenProps(
    tag_name: String,
    self_closing: Bool,
    attributes: Map(String, String),
    start: Bool,
  )
}

pub type Token {
  DOCTYPEToken
  StartTagToken(tag_props: TagTokenProps)
  EndTagToken(tag_props: TagTokenProps)
  CommentToken
  CharacterToken(char: String)
  EndOfFileToken
}

/// Tokenizer implementation base on the https://www.w3.org/TR/2011/WD-html5-20110113/tokenization.html
pub fn tokenize(input) {
  do_tokenize(string.to_graphemes(input), DataState, [])
}

fn do_tokenize(input: List(String), state: TokenizerState, acc: List(Token)) {
  case state {
    DataState -> tokenize_data_state(input, acc)
    TagOpenState -> tokenize_tag_open_state(input, acc)
    EndTagOpenState -> tokenize_end_tag_open_state(input, acc)
    TagNameState(tag_props) -> tokenize_tag_name_state(input, acc, tag_props)
    SelfClosingStartTagState(tag_props) ->
      tokenize_self_closing_start_tag_state(input, acc, tag_props)
    BeforeAttributeNameState(tag_props) ->
      tokenize_before_attribute_name_state(input, acc, tag_props)
    AttributeNameState(tag_props, attribute) ->
      tokenize_attribute_name_state(input, acc, tag_props, attribute)
    AfterAttributeNameState(tag_props, attribute) ->
      tokenize_after_attribute_name_state(input, acc, tag_props, attribute)
    BeforeAttributeValueState(tag_props, attribute) ->
      tokenize_before_attribute_value_state(input, acc, tag_props, attribute)
    AttributeValueState(tag_props, attribute, quote_type) ->
      case quote_type {
        DoubleQuoted ->
          get_tokenize_attribute_value_state_handler("\"")(
            input,
            acc,
            tag_props,
            attribute,
          )
        SingleQuoted ->
          get_tokenize_attribute_value_state_handler("'")(
            input,
            acc,
            tag_props,
            attribute,
          )
        Unquoted ->
          tokenize_attribute_value_unqouted_state(
            input,
            acc,
            tag_props,
            attribute,
          )
      }
    AfterAttributeValueState(tag_props) ->
      tokenize_after_attribute_value_state(input, acc, tag_props)
  }
}

fn tokenize_data_state(input: List(String), acc: List(Token)) {
  // TODO: add "&" handler
  case input {
    [] -> Ok(list.reverse([EndOfFileToken, ..acc]))
    ["<", ..rest] -> do_tokenize(rest, TagOpenState, acc)
    [char, ..rest] -> tokenize_data_state(rest, [CharacterToken(char), ..acc])
  }
}

fn tokenize_tag_open_state(input: List(String), acc: List(Token)) {
  // TODO: add "!" and "?" handlers
  case input {
    ["/", ..rest] -> do_tokenize(rest, EndTagOpenState, acc)
    [char, ..rest] ->
      case is_letter(char) {
        True ->
          do_tokenize(
            rest,
            TagNameState(
              char
              |> string.lowercase
              |> new_start_tag_token_props,
            ),
            acc,
          )
        False -> Error(string.append("Error in TagOpenState, char: ", char))
      }
  }
}

fn tokenize_end_tag_open_state(input: List(String), acc: List(Token)) {
  case input {
    [">", ..] -> Error("Error in EndTagOpenState")
    [char, ..rest] ->
      case is_letter(char) {
        True ->
          do_tokenize(
            rest,
            TagNameState(
              char
              |> string.lowercase
              |> new_end_tag_token_props,
            ),
            acc,
          )
        False -> Error("Error in EndTagOpenState")
      }
    [] -> Error("Error in EndTagOpenState")
  }
}

fn tokenize_tag_name_state(input: List(String), acc: List(Token), tag_props) {
  // TODO: add "NULL" handler
  case input {
    ["/", ..rest] -> do_tokenize(rest, SelfClosingStartTagState(tag_props), acc)
    [">", ..rest] ->
      do_tokenize(rest, DataState, [new_tag_token(tag_props), ..acc])

    [" ", ..rest] | ["\t", ..rest] | ["\n", ..rest] | ["\f", ..rest] ->
      do_tokenize(rest, BeforeAttributeNameState(tag_props), acc)
    [char, ..rest] ->
      tokenize_tag_name_state(rest, acc, append_to_tags_name(tag_props, char))
    [] -> Error("Error in TagNameState")
  }
}

fn tokenize_self_closing_start_tag_state(input, acc, tag_props) {
  case input {
    [">", ..rest] ->
      do_tokenize(
        rest,
        DataState,
        [
          TagTokenProps(..tag_props, self_closing: True)
          |> new_tag_token,
          ..acc
        ],
      )
    [_, ..] -> Error("Error in SelfClosingStartTagState")
    [] -> Error("Error in SelfClosingStartTagState")
  }
}

fn tokenize_before_attribute_name_state(input, acc, tag_props) {
  // TODO: add "NULL" handler
  case input {
    [" ", ..rest] | ["\t", ..rest] | ["\n", ..rest] | ["\f", ..rest] ->
      // ignore
      tokenize_before_attribute_name_state(rest, acc, tag_props)
    ["/", ..rest] -> do_tokenize(rest, SelfClosingStartTagState(tag_props), acc)
    [">", ..rest] ->
      do_tokenize(rest, DataState, [new_tag_token(tag_props), ..acc])

    ["\"", ..] | ["'", ..] | ["<", ..] | ["=", ..] ->
      Error("Error in BeforeAttributeNameState")
    [char, ..rest] ->
      do_tokenize(rest, AttributeNameState(tag_props, new_attribute(char)), acc)
    [] -> Error("Error in BeforeAttributeNameState")
  }
}

fn tokenize_attribute_name_state(input, acc, tag_props, attribute) {
  // TODO: add "NULL" handler
  case input {
    [" ", ..rest] | ["\t", ..rest] | ["\n", ..rest] | ["\f", ..rest] ->
      do_tokenize(rest, AfterAttributeNameState(tag_props, attribute), acc)
    ["/", ..rest] ->
      do_tokenize(
        rest,
        SelfClosingStartTagState(set_attribute(tag_props, attribute)),
        acc,
      )

    ["=", ..rest] ->
      do_tokenize(rest, BeforeAttributeValueState(tag_props, attribute), acc)

    [">", ..rest] ->
      do_tokenize(
        rest,
        DataState,
        [
          tag_props
          |> set_attribute(attribute)
          |> new_tag_token,
          ..acc
        ],
      )
    ["\"", ..] | ["'", ..] | ["<", ..] -> Error("Error in AttributeNameState")
    [char, ..rest] ->
      tokenize_attribute_name_state(
        rest,
        acc,
        tag_props,
        append_to_attributes_name(attribute, char),
      )
    [] -> Error("Error in AttributeNameState")
  }
}

fn tokenize_after_attribute_name_state(input, acc, tag_props, attribute) {
  // TODO: add "NULL" handler
  case input {
    [" ", ..rest] | ["\t", ..rest] | ["\n", ..rest] | ["\f", ..rest] ->
      // ignore
      tokenize_after_attribute_name_state(rest, acc, tag_props, attribute)
    ["/", ..rest] ->
      do_tokenize(
        rest,
        SelfClosingStartTagState(set_attribute(tag_props, attribute)),
        acc,
      )
    ["=", ..rest] ->
      do_tokenize(rest, BeforeAttributeValueState(tag_props, attribute), acc)
    [">", ..rest] ->
      do_tokenize(
        rest,
        DataState,
        [
          tag_props
          |> set_attribute(attribute)
          |> new_tag_token,
          ..acc
        ],
      )
    ["\"", ..] | ["'", ..] | ["<", ..] ->
      Error("Error in AfterAttributeNameState")
    [char, ..rest] ->
      do_tokenize(
        rest,
        AttributeNameState(
          set_attribute(tag_props, attribute),
          new_attribute(char),
        ),
        acc,
      )
    [] -> Error("Error in AfterAttributeNameState")
  }
}

fn tokenize_before_attribute_value_state(input, acc, tag_props, attribute) {
  case input {
    // TODO: add "NULL" handler
    [" ", ..rest] | ["\t", ..rest] | ["\n", ..rest] | ["\f", ..rest] ->
      // ignore
      tokenize_before_attribute_value_state(rest, acc, tag_props, attribute)
    ["\"", ..rest] ->
      do_tokenize(
        rest,
        AttributeValueState(tag_props, attribute, DoubleQuoted),
        acc,
      )
    ["&", ..] ->
      do_tokenize(
        // reconsume "&"
        input,
        AttributeValueState(tag_props, attribute, Unquoted),
        acc,
      )
    ["'", ..rest] ->
      do_tokenize(
        rest,
        AttributeValueState(tag_props, attribute, SingleQuoted),
        acc,
      )
    [">", ..] -> Error("Error in BeforeAttributeValueState")
    ["<", ..] | ["=", ..] | ["`", ..] ->
      Error("Error in BeforeAttributeValueState")
    [char, ..rest] ->
      do_tokenize(
        rest,
        AttributeValueState(
          tag_props,
          append_to_attributes_value(attribute, char),
          Unquoted,
        ),
        acc,
      )
    [] -> Error("Error in BeforeAttributeValueState")
  }
}

fn get_tokenize_attribute_value_state_handler(qoute_char) {
  fn(input, acc, tag_props, attribute) {
    // TODO: add "NULL" handler
    case input {
      [char, ..rest] if char == qoute_char ->
        do_tokenize(
          rest,
          AfterAttributeValueState(set_attribute(tag_props, attribute)),
          acc,
        )
      //   ["&", ..rest] ->
      //     do_tokenize(
      //       rest,
      //       CharacterReferenceInAttributeValueState(qoute_char),
      //       acc,
      //     )
      [char, ..rest] ->
        get_tokenize_attribute_value_state_handler(qoute_char)(
          rest,
          acc,
          tag_props,
          append_to_attributes_value(attribute, char),
        )
      [] -> Error("Error in AttributeValueState")
    }
  }
}

fn tokenize_attribute_value_unqouted_state(input, acc, tag_props, attribute) {
  // TODO: add "NULL" handler
  case input {
    [" ", ..rest] | ["\t", ..rest] | ["\n", ..rest] | ["\f", ..rest] ->
      do_tokenize(
        rest,
        BeforeAttributeNameState(set_attribute(tag_props, attribute)),
        acc,
      )
    // ["&", ..rest] ->
    //   do_tokenize(rest, CharacterReferenceInAttributeValueState(">"), acc)
    [">", ..rest] ->
      do_tokenize(
        rest,
        DataState,
        [
          tag_props
          |> set_attribute(attribute)
          |> new_tag_token,
          ..acc
        ],
      )
    ["\"", ..] | ["'", ..] | ["<", ..] | ["=", ..] | ["`", ..] ->
      Error("Error in AttributeValueState (Unqouted)")
    [char, ..rest] ->
      tokenize_attribute_value_unqouted_state(
        rest,
        acc,
        tag_props,
        append_to_attributes_value(attribute, char),
      )
    [] -> Error("Error in AttributeValueState (Unqouted)")
  }
}

fn tokenize_after_attribute_value_state(input, acc, tag_props) {
  case input {
    [" ", ..rest] | ["\t", ..rest] | ["\n", ..rest] | ["\f", ..rest] ->
      do_tokenize(rest, BeforeAttributeNameState(tag_props), acc)
    ["/", ..rest] -> do_tokenize(rest, SelfClosingStartTagState(tag_props), acc)
    [">", ..rest] ->
      do_tokenize(rest, DataState, [new_tag_token(tag_props), ..acc])
    [_, ..] -> Error("Error in AfterAttributeValueState")
    [] -> Error("Error in AfterAttributeValueState")
  }
}

// Helpers ----------------------------------------------------------------
fn new_start_tag_token_props(tag_name) {
  TagTokenProps(tag_name, False, map.new(), True)
}

fn new_end_tag_token_props(tag_name) {
  TagTokenProps(tag_name, False, map.new(), False)
}

fn new_tag_token(tag_props) {
  case tag_props.start {
    True -> StartTagToken(tag_props)
    False -> EndTagToken(tag_props)
  }
}

fn new_attribute(char) {
  #(string.lowercase(char), "")
}

fn set_attribute(tag_props, attribute) {
  TagTokenProps(
    ..tag_props,
    attributes: tag_props.attributes
    // TODO: map insert will overwrite existing attributes. We should check if current attribute is not present and return Error otherwise
    |> map.insert(attribute.0, attribute.1),
  )
}

fn append_to_tags_name(tag_props, char) {
  TagTokenProps(
    ..tag_props,
    tag_name: string.append(tag_props.tag_name, string.lowercase(char)),
  )
}

fn append_to_attributes_name(attribute, char) {
  #(string.append(attribute.0, string.lowercase(char)), attribute.1)
}

fn append_to_attributes_value(attribute, char) {
  #(attribute.0, string.append(attribute.1, char))
}

fn is_letter(char) {
  matches(char, "[a-zA-Z]")
}

fn matches(checked, regex_string) {
  assert Ok(re) = regex.from_string(regex_string)

  re
  |> regex.check(checked)
}
