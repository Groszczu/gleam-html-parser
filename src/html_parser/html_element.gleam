import gleam/string
import gleam/list
import gleam/map.{Map}
import gleam/option

pub type HTMLElement {
  HTMLElement(
    tag_name: String,
    attributes: Map(String, String),
    children: List(HTMLElement),
  )
}

pub fn new(tag_name: String) -> HTMLElement {
  HTMLElement(tag_name: tag_name, attributes: map.new(), children: [])
}

pub fn to_string(html_element: HTMLElement) -> String {
  do_to_string(html_element, 0)
}

fn do_to_string(html_element: HTMLElement, depth: Int) -> String {
  let HTMLElement(
    tag_name: tag_name,
    children: children,
    attributes: attributes,
  ) = html_element

  let indentation = string.repeat("\t", depth)

  let attributes =
    attributes
    |> map.to_list()
    |> list.map(fn(attribute) {
      string.concat([attribute.0, "=", "\"", attribute.1, "\""])
    })
    |> string.join(" ")
    |> string.to_option()

  case children {
    [] ->
      string.concat([
        indentation,
        "<",
        tag_name,
        " ",
        attributes
        |> option.map(string.append(_, " "))
        |> option.unwrap(""),
        "/>",
      ])
    _ ->
      string.concat([
        indentation,
        "<",
        tag_name,
        attributes
        |> option.map(string.append(" ", _))
        |> option.unwrap(""),
        ">",
        "\n",
        children
        |> list.map(do_to_string(_, depth + 1))
        |> string.join("\n"),
        "\n",
        indentation,
        "<",
        tag_name,
        " />",
      ])
  }
}

pub fn set_attributes(
  html_element: HTMLElement,
  attributes: List(#(String, String)),
) -> HTMLElement {
  HTMLElement(..html_element, attributes: map.from_list(attributes))
}

pub fn insert_attribute(
  html_element: HTMLElement,
  name: String,
  value: String,
) -> HTMLElement {
  HTMLElement(
    ..html_element,
    attributes: map.insert(html_element.attributes, name, value),
  )
}

pub fn prepend_child(parent: HTMLElement, child: HTMLElement) -> HTMLElement {
  HTMLElement(..parent, children: [child, ..parent.children])
}

pub fn reverse_children(html_element: HTMLElement) -> HTMLElement {
  HTMLElement(..html_element, children: list.reverse(html_element.children))
}
