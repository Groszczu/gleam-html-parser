import gleam/io
import gleam/list
import gleam/string
import gleam/option.{None, Option, Some}
import html_parser/errors.{HTMLParserError}
import html_parser/html_tokenizer.{
  CharacterToken, DOCTYPEToken, EndOfFileToken, EndTagToken, StartTagToken, TagTokenProps,
  Token,
}
import html_parser/html_element.{
  HTMLElement, TextNode, append_child, insert_attribute, new, prepend_child, reverse_children,
  set_attributes_map, set_children, to_node,
}

pub fn parse(input: String) -> Result(List(HTMLElement), HTMLParserError) {
  try tokens = html_tokenizer.tokenize(input)
  do_parse(tokens, [], [], [])
}

fn do_parse(
  input: List(Token),
  stack: List(Token),
  open_elements: List(HTMLElement),
  closed_elements: List(HTMLElement),
) {
  case input, stack, open_elements, closed_elements {
    [EndOfFileToken], [], [], closed_elements ->
      Ok(list.reverse(closed_elements))
    [], [_, ..], _, _ -> Error(errors.StackNotEmpty)
    [
      StartTagToken(TagTokenProps(
        self_closing: True,
        tag_name: tag_name,
        attributes: attributes,
        ..,
      )) as token,
      ..rest
    ], stack, [], closed_elements ->
      do_parse(
        rest,
        stack,
        [],
        [
          new(tag_name)
          |> set_attributes_map(attributes),
          ..closed_elements
        ],
      )

    [
      StartTagToken(TagTokenProps(
        self_closing: False,
        tag_name: tag_name,
        attributes: attributes,
        ..,
      )) as token,
      ..rest
    ], stack, [], closed_elements ->
      do_parse(
        rest,
        stack,
        [
          new(tag_name)
          |> set_attributes_map(attributes),
        ],
        closed_elements,
      )

    [
      StartTagToken(TagTokenProps(
        self_closing: True,
        tag_name: tag_name,
        attributes: attributes,
        ..,
      )) as token,
      ..rest
    ], stack, [last_open_element, ..open_elements], closed_elements ->
      do_parse(
        rest,
        stack,
        [
          last_open_element
          |> prepend_child(
            new(tag_name)
            |> set_attributes_map(attributes)
            |> to_node,
          ),
          ..open_elements
        ],
        closed_elements,
      )

    [
      StartTagToken(TagTokenProps(
        self_closing: False,
        tag_name: tag_name,
        attributes: attributes,
        ..,
      )) as token,
      ..rest
    ], stack, [_, ..] as open_elements, closed_elements ->
      do_parse(
        rest,
        stack,
        [
          new(tag_name)
          |> set_attributes_map(attributes),
          ..open_elements
        ],
        closed_elements,
      )

    [EndTagToken(_), ..], _, [], _ ->
      Error(errors.UnexpectedEndTagBeforeStartTag)

    [EndTagToken(TagTokenProps(tag_name: end_tag_name, ..)), ..rest], _, [
      HTMLElement(tag_name: start_tag_name, ..) as last_open_element,
      prev_open_element,
      ..open_elements
    ], closed_elements if end_tag_name == start_tag_name ->
      do_parse(
        rest,
        stack,
        [
          prev_open_element
          |> prepend_child(
            last_open_element
            |> to_node,
          ),
          ..open_elements
        ],
        closed_elements,
      )

    [EndTagToken(TagTokenProps(tag_name: end_tag_name, ..)), ..rest], _, [
      HTMLElement(tag_name: start_tag_name, ..) as only_open_element,
    ], closed_elements if end_tag_name == start_tag_name ->
      do_parse(
        rest,
        stack,
        [],
        [
          only_open_element
          |> reverse_children,
          ..closed_elements
        ],
      )

    [EndTagToken(_), ..], _, _, _ -> Error(errors.UnexpectedNotMatchingEndTag)
    // TODO: Implement top level text nodes
    [CharacterToken(_), ..], _, [], _ -> Error(errors.NotImplemented)
    [CharacterToken(char), ..rest], stack, [
      HTMLElement(children: [TextNode(text), ..children], ..) as last_open_element,
      ..open_elements
    ], closed_elements ->
      do_parse(
        rest,
        stack,
        [
          last_open_element
          |> set_children([TextNode(string.append(text, char)), ..children]),
          ..open_elements
        ],
        closed_elements,
      )
    [CharacterToken(char), ..rest], stack, [
      HTMLElement(children: children, ..) as last_open_element,
      ..open_elements
    ], closed_elements ->
      do_parse(
        rest,
        stack,
        [
          last_open_element
          |> set_children([TextNode(char), ..children]),
          ..open_elements
        ],
        closed_elements,
      )
  }
}

pub fn main() {
  let root =
    new("div")
    |> insert_attribute("role", "main")
    |> insert_attribute("title", "main")
    |> append_child(TextNode("Root"))

  let li =
    new("li")
    |> insert_attribute("role", "listitem")
  let ul =
    new("ul")
    |> append_child(to_node(li))
    |> append_child(to_node(li))

  let root =
    root
    |> append_child(to_node(ul))
    |> append_child(to_node(new("span")))

  io.println(html_element.to_string(root))
}
