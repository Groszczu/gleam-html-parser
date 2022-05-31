import gleeunit
import gleeunit/should
import html_parser/html_element
import gleam/string
import gleam/map
import gleam/list

pub fn main() {
  gleeunit.main()
}

pub fn new_test() {
  let anchor_element = html_element.new("a")

  anchor_element.tag_name
  |> should.equal("a")

  anchor_element.attributes
  |> map.size()
  |> should.equal(0)
}

pub fn set_attributes_test() {
  let href_attribute = #("href", "https://gleam.run")
  let style_attribute = #("style", "https://gleam.run")
  let attributes = [href_attribute, style_attribute]

  let anchor_element =
    html_element.new("a")
    |> html_element.set_attributes(attributes)

  anchor_element.attributes
  |> map.size()
  |> should.equal(list.length(attributes))

  anchor_element.attributes
  |> map.get(href_attribute.0)
  |> should.be_ok()

  anchor_element.attributes
  |> map.get(style_attribute.0)
  |> should.be_ok()

  anchor_element.attributes
  |> map.get("title")
  |> should.be_error()
}

pub fn to_string_test() {
  let root =
    html_element.new("div")
    |> html_element.insert_attribute("role", "main")
    |> html_element.insert_attribute("title", "main")

  let li =
    html_element.new("li")
    |> html_element.insert_attribute("role", "listitem")
  let ul =
    html_element.new("ul")
    |> html_element.prepend_child(html_element.to_node(li))
    |> html_element.prepend_child(html_element.to_node(li))

  let root =
    root
    |> html_element.prepend_child(html_element.to_node(ul))
    |> html_element.prepend_child(html_element.to_node(html_element.new("span")))

  root
  |> html_element.to_string()
  |> should.equal(string.concat([
    "<div role=\"main\" title=\"main\">", "\n", "\t", "<span />", "\n", "\t", "<ul>",
    "\n", "\t\t", "<li role=\"listitem\" />", "\n", "\t\t", "<li role=\"listitem\" />",
    "\n", "\t", "<ul />", "\n", "<div />",
  ]))
}
