import gleam/map
import html_parser
import html_parser/html_element.{HTMLElement, TextNode, to_node}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  assert Ok(result) =
    html_parser.parse("<div><span>Test</span><ul><li /><li/></ul></div>")

  should.equal(
    result,
    [
      HTMLElement(
        "div",
        map.new(),
        [
          HTMLElement("span", map.new(), [TextNode("Test")])
          |> to_node,
          HTMLElement(
            "ul",
            map.new(),
            [
              HTMLElement("li", map.new(), [])
              |> to_node,
              HTMLElement("li", map.new(), [])
              |> to_node,
            ],
          )
          |> to_node,
        ],
      ),
    ],
  )
}
