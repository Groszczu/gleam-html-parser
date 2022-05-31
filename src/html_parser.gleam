import gleam/io
import gleam/string
import html_parser/html_element.{
  HTMLElement, TextNode, append_child, insert_attribute, new, to_node,
}

type ParserState {
  ParserState(root_element: HTMLElement, stack: List(HTMLElement))
}

pub type ParserError {
  StackNotEmpty
}

pub fn parse(input: String) -> Result(HTMLElement, ParserError) {
  do_parse(
    string.to_graphemes(input),
    ParserState(root_element: new("root"), stack: []),
  )
}

fn do_parse(
  input: List(String),
  state: ParserState,
) -> Result(HTMLElement, ParserError) {
  let ParserState(root_element: root_element, stack: stack) = state
  case input, stack {
    [], [] -> Ok(root_element)
    [], _ -> Error(StackNotEmpty)
    ["<", ..input], _ -> Ok(root_element)
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
