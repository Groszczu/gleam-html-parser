pub type HTMLParserError {
  StackNotEmpty
  UnexpectedNullCharacter
  UnexpectedSolidusInTag
  UnexpectedEqualsSignBeforeAttributeName
  UnexpectedCharacterInAttributeName
  UnexpectedCharacterInUnquotedAttributeValue
  UnexpectedEndTagBeforeStartTag
  UnexpectedNotMatchingEndTag
  MissingEndTagName
  MissingAttributeValue
  MissingWhitespaceBetweenAttributes
  EOFBeforeTagName
  EOFInTag
  InvalidFirstCharacterOfTagName

  NotImplemented
}
