import gleam/io
import html_parser/html_element.{HTMLElement}

pub fn parse(_html_content: String) -> List(HTMLElement) {
  [html_element.new("a")]
}

pub fn main() {
  let root =
    html_element.new("div")
    |> html_element.insert_attribute("role", "main")
    |> html_element.insert_attribute("title", "main")

  let li =
    html_element.new("li")
    |> html_element.insert_attribute("role", "listitem")
  let ul =
    html_element.new("ul")
    |> html_element.prepend_child(li)
    |> html_element.prepend_child(li)

  let root =
    root
    |> html_element.prepend_child(ul)
    |> html_element.prepend_child(html_element.new("span"))

  io.println(html_element.to_string(root))
}
