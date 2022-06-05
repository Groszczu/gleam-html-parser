import gleam/list
import gleam/map
import gleeunit
import gleeunit/should
import html_parser/errors
import html_parser/html_tokenizer.{
  CharacterToken, EndOfFileToken, EndTagToken, StartTagToken, TagTokenProps,
}

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn tokenize_test() {
  assert Ok(tokens) = html_tokenizer.tokenize("<div>test</div>")

  should.equal(
    tokens,
    [
      StartTagToken(TagTokenProps("div", False, map.new(), True)),
      CharacterToken("t"),
      CharacterToken("e"),
      CharacterToken("s"),
      CharacterToken("t"),
      EndTagToken(TagTokenProps("div", False, map.new(), False)),
      EndOfFileToken,
    ],
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

  [
    #("<div <", errors.UnexpectedCharacterInAttributeName),
    #("<a role=''img' />", errors.MissingWhitespaceBetweenAttributes),
    #("<div><a /a><div>", errors.UnexpectedSolidusInTag),
    #("<a role=>", errors.MissingAttributeValue),
  ]
  |> list.each(fn(test_case) {
    test_case.0
    |> html_tokenizer.tokenize
    |> should.equal(Error(test_case.1))
  })
}
