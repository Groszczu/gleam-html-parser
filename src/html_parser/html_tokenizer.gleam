import gleam/list
import gleam/map.{Map}
import gleam/string
import gleam/regex
import html_parser/errors.{HTMLParserError}

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

/// Tokenizer implementation based on the https://html.spec.whatwg.org/multipage/parsing.html#tokenization
pub fn tokenize(input) -> Result(List(Token), HTMLParserError) {
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
        False -> Error(errors.InvalidFirstCharacterOfTagName)
      }
    [] -> Error(errors.EOFBeforeTagName)
  }
}

fn tokenize_end_tag_open_state(input: List(String), acc: List(Token)) {
  case input {
    [">", ..] -> Error(errors.MissingEndTagName)
    [char, ..] ->
      case is_letter(char) {
        True ->
          do_tokenize(input, TagNameState(new_end_tag_token_props("")), acc)
        False -> Error(errors.InvalidFirstCharacterOfTagName)
      }
    [] -> Error(errors.EOFBeforeTagName)
  }
}

fn tokenize_tag_name_state(input: List(String), acc: List(Token), tag_props) {
  // TODO: add "NULL" handler
  case input {
    [" ", ..rest] | ["\t", ..rest] | ["\n", ..rest] | ["\f", ..rest] ->
      do_tokenize(rest, BeforeAttributeNameState(tag_props), acc)
    ["/", ..rest] -> do_tokenize(rest, SelfClosingStartTagState(tag_props), acc)
    [">", ..rest] ->
      do_tokenize(rest, DataState, [new_tag_token(tag_props), ..acc])

    [char, ..rest] ->
      tokenize_tag_name_state(rest, acc, append_to_tags_name(tag_props, char))
    [] -> Error(errors.EOFInTag)
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
    [_, ..] -> Error(errors.UnexpectedSolidusInTag)
    [] -> Error(errors.EOFInTag)
  }
}

fn tokenize_before_attribute_name_state(input, acc, tag_props) {
  // TODO: add "NULL" handler
  case input {
    [" ", ..rest] | ["\t", ..rest] | ["\n", ..rest] | ["\f", ..rest] ->
      // ignore
      tokenize_before_attribute_name_state(rest, acc, tag_props)

    // ["/", ..rest] -> do_tokenize(rest, SelfClosingStartTagState(tag_props), acc)
    // [">", ..rest] ->
    //   do_tokenize(rest, DataState, [new_tag_token(tag_props), ..acc])
    ["/", ..] | [">", ..] | [] ->
      do_tokenize(
        input,
        AfterAttributeNameState(tag_props, new_attribute("")),
        acc,
      )
    ["=", ..] -> Error(errors.UnexpectedEqualsSignBeforeAttributeName)

    [_, ..] ->
      do_tokenize(input, AttributeNameState(tag_props, new_attribute("")), acc)
  }
}

fn tokenize_attribute_name_state(input, acc, tag_props, attribute) {
  // TODO: add "NULL" handler
  case input {
    [] | [" ", ..] | ["\t", ..] | ["\n", ..] | ["\f", ..] | ["/", ..] | [
      ">",
      ..
    ] -> do_tokenize(input, AfterAttributeNameState(tag_props, attribute), acc)

    ["=", ..rest] ->
      do_tokenize(rest, BeforeAttributeValueState(tag_props, attribute), acc)

    ["\"", ..] | ["'", ..] | ["<", ..] ->
      Error(errors.UnexpectedCharacterInAttributeName)
    [char, ..rest] ->
      tokenize_attribute_name_state(
        rest,
        acc,
        tag_props,
        append_to_attributes_name(attribute, char),
      )
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
    [_, ..] ->
      do_tokenize(
        input,
        AttributeNameState(
          set_attribute(tag_props, attribute),
          new_attribute(""),
        ),
        acc,
      )
    [] -> Error(errors.EOFInTag)
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
    ["'", ..rest] ->
      do_tokenize(
        rest,
        AttributeValueState(tag_props, attribute, SingleQuoted),
        acc,
      )
    [">", ..] -> Error(errors.MissingAttributeValue)
    _ ->
      do_tokenize(
        input,
        AttributeValueState(tag_props, attribute, Unquoted),
        acc,
      )
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
      [] -> Error(errors.EOFInTag)
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
      Error(errors.UnexpectedCharacterInAttributeName)
    [char, ..rest] ->
      tokenize_attribute_value_unqouted_state(
        rest,
        acc,
        tag_props,
        append_to_attributes_value(attribute, char),
      )
    [] -> Error(errors.EOFInTag)
  }
}

fn tokenize_after_attribute_value_state(input, acc, tag_props) {
  case input {
    [" ", ..rest] | ["\t", ..rest] | ["\n", ..rest] | ["\f", ..rest] ->
      do_tokenize(rest, BeforeAttributeNameState(tag_props), acc)
    ["/", ..rest] -> do_tokenize(rest, SelfClosingStartTagState(tag_props), acc)
    [">", ..rest] ->
      do_tokenize(rest, DataState, [new_tag_token(tag_props), ..acc])
    [_, ..] -> Error(errors.MissingWhitespaceBetweenAttributes)
    [] -> Error(errors.EOFInTag)
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
  case attribute.0 {
    "" -> tag_props
    _ ->
      TagTokenProps(
        ..tag_props,
        attributes: tag_props.attributes
        // TODO: map insert will overwrite existing attributes. We should check if current attribute is not present and return Error otherwise
        |> map.insert(attribute.0, attribute.1),
      )
  }
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
