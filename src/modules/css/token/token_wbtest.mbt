///|
test "Token::to_string for each constructible variant" {
  inspect(Token::Ident("foo").to_string(), content="Ident(foo)")
  inspect(Token::Function("calc").to_string(), content="Function(calc)")
  inspect(Token::AtKeyword("media").to_string(), content="AtKeyword(media)")
  inspect(Token::Hash("id", HashType::Id).to_string(), content="Hash(id)")
  inspect(
    Token::Hash("123", HashType::Unrestricted).to_string(),
    content="Hash(123)",
  )
  inspect(Token::String("hi").to_string(), content="String(hi)")
  inspect(Token::BadString.to_string(), content="BadString")
  inspect(
    Token::Number(10.0, NumType::Integer).to_string(),
    content="Number(10, int)",
  )
  inspect(
    Token::Number(1.5, NumType::Number).to_string(),
    content="Number(1.5, num)",
  )
  inspect(Token::Percentage(50.0).to_string(), content="Percentage(50)")
  inspect(Token::Dimension(10.0, "px").to_string(), content="Dimension(10, px)")
  inspect(Token::Delim('>').to_string(), content="Delim(>)")
  inspect(Token::Whitespace.to_string(), content="Whitespace")
  inspect(Token::Colon.to_string(), content="Colon")
  inspect(Token::Semicolon.to_string(), content="Semicolon")
  inspect(Token::Comma.to_string(), content="Comma")
  inspect(Token::LeftBracket.to_string(), content="LeftBracket")
  inspect(Token::RightBracket.to_string(), content="RightBracket")
  inspect(Token::LeftParen.to_string(), content="LeftParen")
  inspect(Token::RightParen.to_string(), content="RightParen")
  inspect(Token::LeftBrace.to_string(), content="LeftBrace")
  inspect(Token::RightBrace.to_string(), content="RightBrace")
  inspect(Token::CDO.to_string(), content="CDO")
  inspect(Token::CDC.to_string(), content="CDC")
  inspect(Token::EOF.to_string(), content="EOF")
}
