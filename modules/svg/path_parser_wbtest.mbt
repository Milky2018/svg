///|
test "parse_path_simple" {
  let commands = parse_path("M 10 20 L 30 40")
  inspect(commands.length(), content="2")
}

///|
test "parse_path_relative" {
  let commands = parse_path("m 10 20 l 30 40")
  inspect(commands.length(), content="2")
}

///|
test "parse_path_horizontal_vertical" {
  let commands = parse_path("M 0 0 H 100 V 50")
  inspect(commands.length(), content="3")
}

///|
test "parse_path_curve" {
  let commands = parse_path("M 10 10 C 20 20 40 20 50 10")
  inspect(commands.length(), content="2")
}

///|
test "parse_path_close" {
  let commands = parse_path("M 10 10 L 50 10 L 30 50 Z")
  inspect(commands.length(), content="4")
}

///|
test "parse_path_arc" {
  let commands = parse_path("M 10 10 A 5 5 0 0 1 20 20")
  inspect(commands.length(), content="2")
}
