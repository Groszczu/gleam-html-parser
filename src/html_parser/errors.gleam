pub type HTMLParserError {
  StackNotEmpty
  UnexpectedNullCharacter
  UnexpectedSolidusInTag
  UnexpectedEqualsSignBeforeAttributeName
  UnexpectedCharacterInAttributeName
  UnexpectedCharacterInUnquotedAttributeValue
  MissingEndTagName
  MissingAttributeValue
  MissingWhitespaceBetweenAttributes
  EOFBeforeTagName
  EOFInTag
  InvalidFirstCharacterOfTagName
}
