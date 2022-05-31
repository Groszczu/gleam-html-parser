import gleam/list
import gleam/function.{compose}
import gleam/map
import gleeunit
import gleeunit/should
import html_parser/html_tokenizer.{
  EndOfFileToken, EndTagToken, StartTagToken, TagTokenProps,
}

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn tokenize_test() {
  assert Ok(tokens) = html_tokenizer.tokenize("<div />")

  should.equal(
    tokens,
    [StartTagToken(TagTokenProps("div", True, map.new(), True)), EndOfFileToken],
  )

  assert Ok(tokens) =
    html_tokenizer.tokenize("<div><span role='img' class=\"icon\" /></div>")

  should.equal(
    tokens,
    [
      StartTagToken(TagTokenProps("div", False, map.new(), True)),
      StartTagToken(TagTokenProps(
        "span",
        True,
        [#("role", "img"), #("class", "icon")]
        |> map.from_list(),
        True,
      )),
      EndTagToken(TagTokenProps("div", False, map.new(), False)),
      EndOfFileToken,
    ],
  )

  ["<div <", "<a role=''img' />", "<div><a /a><div>"]
  |> list.each(compose(html_tokenizer.tokenize, should.be_error))
}
