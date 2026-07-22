///|
/// Parse a value inside CSS math functions and resolve it to a dimension
/// Handles recursively nested calc(), min(), max(), clamp()
fn parse_css_value_to_px(value : String, ctx : ComputeContext) -> Double? {
  let v = value.trim()
  if v.is_empty() {
    return None
  }

  // Handle nested calc()
  if v.has_prefix("calc(") && v.has_suffix(")") {
    let inner = view_to_string(
      v.view(start_offset=5, end_offset=v.length() - 1),
    )
    return parse_simple_calc_expr(inner, ctx)
  }

  // Handle nested min()
  if v.has_prefix("min(") && v.has_suffix(")") {
    let inner = view_to_string(
      v.view(start_offset=4, end_offset=v.length() - 1),
    )
    let args = split_css_args(inner)
    let mut min_val : Double? = None
    for arg in args {
      match parse_css_value_to_px(arg, ctx) {
        Some(val) =>
          match min_val {
            None => min_val = Some(val)
            Some(current) => if val < current { min_val = Some(val) }
          }
        None => return None
      }
    }
    return min_val
  }

  // Handle nested max()
  if v.has_prefix("max(") && v.has_suffix(")") {
    let inner = view_to_string(
      v.view(start_offset=4, end_offset=v.length() - 1),
    )
    let args = split_css_args(inner)
    let mut max_val : Double? = None
    for arg in args {
      match parse_css_value_to_px(arg, ctx) {
        Some(val) =>
          match max_val {
            None => max_val = Some(val)
            Some(current) => if val > current { max_val = Some(val) }
          }
        None => return None
      }
    }
    return max_val
  }

  // Handle nested clamp()
  if v.has_prefix("clamp(") && v.has_suffix(")") {
    let inner = view_to_string(
      v.view(start_offset=6, end_offset=v.length() - 1),
    )
    let args = split_css_args(inner)
    if args.length() != 3 {
      return None
    }
    let min_px = parse_css_value_to_px(args[0], ctx)
    let val_px = parse_css_value_to_px(args[1], ctx)
    let max_px = parse_css_value_to_px(args[2], ctx)
    match (min_px, val_px, max_px) {
      (Some(min_v), Some(val_v), Some(max_v)) =>
        // clamp(min, val, max) == max(min, min(val, max))
        return Some(@types.apply_math_op(Clamp, [min_v, val_v, max_v]))
      _ => return None
    }
  }

  // Parse simple dimension value
  let dim = resolve_dimension(v.to_owned(), ctx)
  match dim {
    Length(px) => Some(px)
    Percent(_) => None // Cannot simplify percentages
    Calc(_, _) => None // Mixed calc needs a layout basis
    MathFn(_, _) => None // min/max/clamp need a layout basis
    Auto => None
    MinContent => None
    MaxContent => None
    FitContent(_) => None
  }
}

///|
/// Split CSS function arguments by comma (handling nested parentheses)
fn split_css_args(input : String) -> Array[String] {
  let result : Array[String] = []
  let mut current = StringBuilder::new()
  let mut paren_depth = 0
  for i = 0; i < input.length(); i = i + 1 {
    let c = input[i].to_int().unsafe_to_char()
    if c == '(' {
      paren_depth += 1
      current.write_char(c)
    } else if c == ')' {
      paren_depth -= 1
      current.write_char(c)
    } else if c == ',' && paren_depth == 0 {
      let s = current.to_string().trim().to_owned()
      if !s.is_empty() {
        result.push(s)
      }
      current = StringBuilder::new()
    } else {
      current.write_char(c)
    }
  }
  let s = current.to_string().trim().to_owned()
  if !s.is_empty() {
    result.push(s)
  }
  result
}

///|
/// Parse a simple calc expression (handles + - * / with px values)
fn is_calc_signed_number_start(
  expr : String,
  index : Int,
  token_start : Int,
) -> Bool {
  if index != token_start || index + 1 >= expr.length() {
    return false
  }
  let sign = expr[index].to_int().unsafe_to_char()
  if sign != '+' && sign != '-' {
    return false
  }
  let next = expr[index + 1].to_int().unsafe_to_char()
  (next >= '0' && next <= '9') || next == '.'
}

///|
fn parse_simple_calc_expr(expr : String, ctx : ComputeContext) -> Double? {
  let mut result : Double = 0.0
  let mut current_op : Char = '+'
  let mut i = 0
  let mut token_start = 0
  while i <= expr.length() {
    let c = if i < expr.length() {
      expr[i].to_int().unsafe_to_char()
    } else {
      ' '
    }
    let signed_number_start = if i < expr.length() {
      is_calc_signed_number_start(expr, i, token_start)
    } else {
      false
    }
    if (c == '+' || c == '-' || c == '*' || c == '/' || i == expr.length()) &&
      !signed_number_start {
      if i > token_start {
        let token = expr.unsafe_substring(start=token_start, end=i).trim()
        if !token.is_empty() {
          match parse_css_value_to_px(token.to_owned(), ctx) {
            Some(val) =>
              match current_op {
                '+' => result = result + val
                '-' => result = result - val
                '*' => result = result * val
                '/' => result = result / val
                _ => ()
              }
            None => {
              // Try parsing as unitless number for * and /
              let n = @string.parse_double(token.to_owned()) catch {
                _ => return None
              }
              match current_op {
                '*' => result = result * n
                '/' => result = result / n
                '+' | '-' =>
                  // Unitless number for + or - is invalid unless 0
                  if n != 0.0 {
                    return None
                  }
                _ => ()
              }
            }
          }
        }
      }
      if i < expr.length() {
        current_op = c
      }
      token_start = i + 1
    }
    i = i + 1
  }
  Some(result)
}

///|
/// Reduce a single min()/max()/clamp() argument to a linear (px, percent_ratio)
/// form. Returns None for intrinsic/auto values that cannot be reduced.
fn math_arg_lp(arg : String, ctx : ComputeContext) -> (Double, Double)? {
  // A bare unitless number is only a valid length argument when it is 0; reject
  // non-zero unitless numbers so the result matches the parser layer.
  let trimmed = arg.trim().to_owned()
  if is_pure_number(trimmed) {
    let n = @string.parse_double(trimmed) catch { _ => return None }
    return if n == 0.0 { Some((0.0, 0.0)) } else { None }
  }
  match resolve_dimension(arg, ctx) {
    Length(px) => Some((px, 0.0))
    Percent(p) => Some((0.0, p))
    Calc(px, pct) => Some((px, pct))
    _ => None
  }
}

///|
/// Collapse a linear (px, percent_ratio) form back to the most specific
/// Dimension. Mirrors parse_calc_string's pure-vs-mixed classification.
fn lp_to_dimension(px : Double, pct : Double) -> @types.Dimension {
  if pct.abs() < 0.0001 {
    Length(px)
  } else if px.abs() < 0.0001 {
    Percent(pct)
  } else {
    Calc(px, pct)
  }
}

///|
/// Parse min(), max(), clamp() CSS functions.
///
/// Each argument is reduced to a linear (px, percent_ratio) form so that
/// percentage arguments are preserved instead of collapsing to Auto
/// (WPT css/css-values/calc-in-max.html).
/// - single argument: returned as-is (Length/Percent/Calc).
/// - all pure-px arguments: compared by px -> Length.
/// - all pure-percent arguments: the containing-block basis is positive, so
///   ordering by ratio matches ordering by resolved length -> Percent.
/// - mixed px + percent arguments cannot be ordered without a layout basis and
///   are carried as a MathFn dimension, resolved at layout time.
fn parse_css_math_function(
  expr : String,
  ctx : ComputeContext,
) -> @types.Dimension? {
  let v = expr.trim()
  let (op, prefix_len) = if v.has_prefix("min(") {
    (@types.MathOp::Min, 4)
  } else if v.has_prefix("max(") {
    (Max, 4)
  } else if v.has_prefix("clamp(") {
    (Clamp, 6)
  } else {
    return None
  }
  if !v.has_suffix(")") {
    return None
  }
  let inner = view_to_string(
    v.view(start_offset=prefix_len, end_offset=v.length() - 1),
  )
  let raw_args = split_css_args(inner)
  if raw_args.is_empty() {
    return None
  }
  if op == Clamp && raw_args.length() != 3 {
    return None
  }
  let lps : Array[(Double, Double)] = []
  for arg in raw_args {
    match math_arg_lp(arg, ctx) {
      Some(lp) => lps.push(lp)
      None => return None
    }
  }
  // Single min()/max() argument resolves to that argument verbatim.
  if lps.length() == 1 {
    let (px, pct) = lps[0]
    return Some(lp_to_dimension(px, pct))
  }
  let mut all_px = true
  let mut all_pct = true
  for lp in lps {
    if lp.1 != 0.0 {
      all_px = false
    }
    if lp.0 != 0.0 {
      all_pct = false
    }
  }
  if all_px {
    Some(Length(@types.apply_math_op(op, lps.map(fn(lp) { lp.0 }))))
  } else if all_pct {
    Some(Percent(@types.apply_math_op(op, lps.map(fn(lp) { lp.1 }))))
  } else {
    // Mixed length + percentage: defer to layout via MathFn.
    Some(MathFn(op, lps))
  }
}

///|
/// Internal calc() value: either a dimensionless number or a length/percentage
/// linear form (`px` plus `pct` in percentage points, e.g. 50.0 for 50%).
priv struct CalcVal {
  px : Double
  pct : Double
  num : Double
  is_num : Bool
}

///|
fn calc_num(n : Double) -> CalcVal {
  { px: 0.0, pct: 0.0, num: n, is_num: true }
}

///|
fn calc_lp(px : Double, pct : Double) -> CalcVal {
  { px, pct, num: 0.0, is_num: false }
}

///|
/// Tokens for the calc() expression grammar.
priv enum CalcTok {
  CNum(Double, String)
  COp(Char)
  CLP
  CRP
  CFun(String)
  CComma
}

///|
fn calc_char_at(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
/// Tokenize a calc() inner expression. `+`/`-` are treated as binary operators
/// unless an operand is expected (start, after another operator, after `(` or
/// `,`), in which case they are the sign of the following number.
fn calc_tokenize(s : String) -> Array[CalcTok]? {
  let toks : Array[CalcTok] = []
  let n = s.length()
  let mut i = 0
  let mut expect_operand = true
  while i < n {
    let c = calc_char_at(s, i)
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      i = i + 1
      continue
    }
    if c == '(' {
      toks.push(CLP)
      expect_operand = true
      i = i + 1
      continue
    }
    if c == ')' {
      toks.push(CRP)
      expect_operand = false
      i = i + 1
      continue
    }
    if c == ',' {
      toks.push(CComma)
      expect_operand = true
      i = i + 1
      continue
    }
    if c == '*' || c == '/' {
      toks.push(COp(c))
      expect_operand = true
      i = i + 1
      continue
    }
    let is_sign = c == '+' || c == '-'
    if is_sign && !expect_operand {
      toks.push(COp(c))
      expect_operand = true
      i = i + 1
      continue
    }
    let is_digit = c >= '0' && c <= '9'
    if is_digit || c == '.' || (is_sign && expect_operand) {
      let start = i
      if is_sign {
        i = i + 1
      }
      while i < n {
        let d = calc_char_at(s, i)
        if (d >= '0' && d <= '9') || d == '.' {
          i = i + 1
        } else {
          break
        }
      }
      if i < n {
        let e = calc_char_at(s, i)
        if e == 'e' || e == 'E' {
          // Only an exponent if `e` is followed by [+-]?digit; otherwise the
          // `e` begins a unit (e.g. the "em"/"ex" in "20em", "2ex").
          let mut j = i + 1
          if j < n {
            let sgn = calc_char_at(s, j)
            if sgn == '+' || sgn == '-' {
              j = j + 1
            }
          }
          if j < n && calc_char_at(s, j) >= '0' && calc_char_at(s, j) <= '9' {
            i = j + 1
            while i < n {
              let d = calc_char_at(s, i)
              if d >= '0' && d <= '9' {
                i = i + 1
              } else {
                break
              }
            }
          }
        }
      }
      let num_str = s.unsafe_substring(start~, end=i)
      let value = @string.parse_double(num_str) catch { _ => return None }
      let ustart = i
      while i < n {
        let d = calc_char_at(s, i)
        if (d >= 'a' && d <= 'z') || (d >= 'A' && d <= 'Z') || d == '%' {
          i = i + 1
        } else {
          break
        }
      }
      let unit = s.unsafe_substring(start=ustart, end=i).to_lower()
      toks.push(CNum(value, unit))
      expect_operand = false
      continue
    }
    if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
      let start = i
      while i < n {
        let d = calc_char_at(s, i)
        if (d >= 'a' && d <= 'z') || (d >= 'A' && d <= 'Z') {
          i = i + 1
        } else {
          break
        }
      }
      let name = s.unsafe_substring(start~, end=i).to_lower()
      toks.push(CFun(name))
      expect_operand = true
      continue
    }
    return None
  }
  Some(toks)
}

///|
/// Resolve a numeric token with its unit into a CalcVal.
fn calc_unit_value(
  value : Double,
  unit : String,
  ctx : ComputeContext,
) -> CalcVal? {
  if unit == "" {
    return Some(calc_num(value))
  }
  if unit == "%" {
    return Some(calc_lp(0.0, value))
  }
  match resolve_dimension("\{value}\{unit}", ctx) {
    Length(px) => Some(calc_lp(px, 0.0))
    Percent(p) => Some(calc_lp(0.0, p * 100.0))
    _ => None
  }
}

///|
/// Resolve a CalcVal to pixels for min()/max()/clamp() comparisons, resolving
/// percentages against a width reference.
fn calc_to_px(cv : CalcVal, ctx : ComputeContext) -> Double {
  if cv.is_num {
    cv.num
  } else {
    cv.px + cv.pct / 100.0 * mixed_calc_width_reference(ctx)
  }
}

///|
fn calc_add(a : CalcVal, b : CalcVal, sign : Double) -> CalcVal? {
  if a.is_num && b.is_num {
    Some(calc_num(a.num + sign * b.num))
  } else if !a.is_num && !b.is_num {
    Some(calc_lp(a.px + sign * b.px, a.pct + sign * b.pct))
  } else {
    None
  }
}

///|
fn calc_mul(a : CalcVal, b : CalcVal) -> CalcVal? {
  if a.is_num && b.is_num {
    Some(calc_num(a.num * b.num))
  } else if a.is_num {
    Some(calc_lp(b.px * a.num, b.pct * a.num))
  } else if b.is_num {
    Some(calc_lp(a.px * b.num, a.pct * b.num))
  } else {
    None
  }
}

///|
fn calc_div(a : CalcVal, b : CalcVal) -> CalcVal? {
  if !b.is_num || b.num == 0.0 {
    return None
  }
  if a.is_num {
    Some(calc_num(a.num / b.num))
  } else {
    Some(calc_lp(a.px / b.num, a.pct / b.num))
  }
}

///|
/// primary := number | '(' sum ')' | fn '(' sum (',' sum)* ')'
fn calc_parse_primary(
  toks : Array[CalcTok],
  pos : Int,
  ctx : ComputeContext,
) -> (CalcVal, Int)? {
  if pos >= toks.length() {
    return None
  }
  match toks[pos] {
    CNum(v, unit) =>
      match calc_unit_value(v, unit, ctx) {
        Some(cv) => Some((cv, pos + 1))
        None => None
      }
    CLP =>
      match calc_parse_sum(toks, pos + 1, ctx) {
        Some((v, p2)) =>
          if p2 < toks.length() &&
            (match toks[p2] {
              CRP => true
              _ => false
            }) {
            Some((v, p2 + 1))
          } else {
            None
          }
        None => None
      }
    CFun(name) => {
      if pos + 1 >= toks.length() {
        return None
      }
      match toks[pos + 1] {
        CLP => ()
        _ => return None
      }
      let args : Array[CalcVal] = []
      let mut p = pos + 2
      let mut closed = false
      while !closed {
        match calc_parse_sum(toks, p, ctx) {
          Some((a, np)) => {
            args.push(a)
            if np >= toks.length() {
              return None
            }
            match toks[np] {
              CComma => p = np + 1
              CRP => {
                p = np + 1
                closed = true
              }
              _ => return None
            }
          }
          None => return None
        }
      }
      match name {
        "calc" => if args.length() == 1 { Some((args[0], p)) } else { None }
        "min" => {
          if args.is_empty() {
            return None
          }
          let mut m = calc_to_px(args[0], ctx)
          for k = 1; k < args.length(); k = k + 1 {
            let x = calc_to_px(args[k], ctx)
            if x < m {
              m = x
            }
          }
          Some((calc_lp(m, 0.0), p))
        }
        "max" => {
          if args.is_empty() {
            return None
          }
          let mut m = calc_to_px(args[0], ctx)
          for k = 1; k < args.length(); k = k + 1 {
            let x = calc_to_px(args[k], ctx)
            if x > m {
              m = x
            }
          }
          Some((calc_lp(m, 0.0), p))
        }
        "clamp" => {
          if args.length() != 3 {
            return None
          }
          let lo = calc_to_px(args[0], ctx)
          let mid = calc_to_px(args[1], ctx)
          let hi = calc_to_px(args[2], ctx)
          let mut r = mid
          if r < lo {
            r = lo
          }
          if r > hi {
            r = hi
          }
          Some((calc_lp(r, 0.0), p))
        }
        _ => None
      }
    }
    _ => None
  }
}

///|
/// product := primary (('*' | '/') primary)*
fn calc_parse_product(
  toks : Array[CalcTok],
  pos : Int,
  ctx : ComputeContext,
) -> (CalcVal, Int)? {
  match calc_parse_primary(toks, pos, ctx) {
    Some((first, p1)) => {
      let mut acc = first
      let mut p = p1
      let mut stop = false
      while !stop && p < toks.length() {
        let op = match toks[p] {
          COp('*') => '*'
          COp('/') => '/'
          _ => ' '
        }
        if op == ' ' {
          stop = true
        } else {
          match calc_parse_primary(toks, p + 1, ctx) {
            Some((rhs, p2)) => {
              let combined = if op == '*' {
                calc_mul(acc, rhs)
              } else {
                calc_div(acc, rhs)
              }
              match combined {
                Some(v) => {
                  acc = v
                  p = p2
                }
                None => return None
              }
            }
            None => return None
          }
        }
      }
      Some((acc, p))
    }
    None => None
  }
}

///|
/// sum := product (('+' | '-') product)*
fn calc_parse_sum(
  toks : Array[CalcTok],
  pos : Int,
  ctx : ComputeContext,
) -> (CalcVal, Int)? {
  match calc_parse_product(toks, pos, ctx) {
    Some((first, p1)) => {
      let mut acc = first
      let mut p = p1
      let mut stop = false
      while !stop && p < toks.length() {
        let sign = match toks[p] {
          COp('+') => 1.0
          COp('-') => -1.0
          _ => 0.0
        }
        if sign == 0.0 {
          stop = true
        } else {
          match calc_parse_product(toks, p + 1, ctx) {
            Some((rhs, p2)) =>
              match calc_add(acc, rhs, sign) {
                Some(v) => {
                  acc = v
                  p = p2
                }
                None => return None
              }
            None => return None
          }
        }
      }
      Some((acc, p))
    }
    None => None
  }
}

///|
/// Precedence-aware calc() evaluator. Returns (px, percent_ratio) or None if
/// the expression is malformed or not fully understood (callers then fall back
/// to the legacy left-to-right evaluator).
fn eval_calc(expr : String, ctx : ComputeContext) -> (Double, Double)? {
  let v = expr.trim()
  if !v.has_prefix("calc(") || !v.has_suffix(")") {
    return None
  }
  let inner = view_to_string(v.view(start_offset=5, end_offset=v.length() - 1))
  let toks = match calc_tokenize(inner) {
    Some(t) => t
    None => return None
  }
  if toks.is_empty() {
    return None
  }
  match calc_parse_sum(toks, 0, ctx) {
    Some((result, p)) =>
      // Trailing tokens or a bare (dimensionless) result is a parse failure.
      if p != toks.length() || result.is_num {
        None
      } else {
        Some((result.px, result.pct / 100.0))
      }
    None => None
  }
}

///|
/// Parse calc() terms and return (length_px, percent_ratio); percent_ratio is
/// 0.5 for 50%. Delegates to the precedence-aware recursive-descent evaluator.
/// Returns None for malformed or semantically invalid calc() (e.g. a bare
/// number, length × length, or division by zero), so the property falls back to
/// its initial value rather than a silently wrong length.
fn parse_calc_terms(expr : String, ctx : ComputeContext) -> (Double, Double)? {
  eval_calc(expr, ctx)
}

///|
/// Extract first percentage token from calc() expression as ratio.
/// Used as a fallback when mixed calc contains multiplicative terms.
fn extract_first_percent_ratio(expr : String) -> Double? {
  let mut i = 0
  while i < expr.length() {
    if expr[i].to_int().unsafe_to_char() == '%' {
      let mut start = i
      while start > 0 {
        let c = expr[start - 1].to_int().unsafe_to_char()
        if (c >= '0' && c <= '9') || c == '.' {
          start = start - 1
          continue
        }
        if c == '+' || c == '-' {
          start = start - 1
        }
        break
      }
      let num = expr.unsafe_substring(start~, end=i).trim()
      if !num.is_empty() {
        let n = @string.parse_double(num.to_owned()) catch { _ => return None }
        return Some(n / 100.0)
      }
    }
    i = i + 1
  }
  None
}

///|
/// Parse a calc() expression from a string and try to simplify it
/// Returns Some(dimension) if simplification is possible, None otherwise
fn parse_calc_string(expr : String, ctx : ComputeContext) -> @types.Dimension? {
  match parse_calc_terms(expr, ctx) {
    Some((result_px, result_percent)) =>
      if result_percent.abs() < 0.0001 {
        Some(Length(result_px))
      } else if result_px.abs() < 0.0001 {
        Some(Percent(result_percent))
      } else {
        Some(Calc(result_px, result_percent))
      }
    None => None
  }
}

///|
/// Choose a width reference for mixed calc() fallback.
/// Prefer parent's definite width when available; otherwise use viewport width.
fn mixed_calc_width_reference(ctx : ComputeContext) -> Double {
  match ctx.parent_style {
    Some(parent) =>
      match parent.width {
        Length(w) => w
        Percent(p) => ctx.viewport_width * p
        _ => ctx.viewport_width
      }
    None => ctx.viewport_width
  }
}

///|
/// Fallback for mixed calc() on properties that need concrete dimensions.
/// For expressions like calc(50% - 10px), resolve using a width reference.
fn resolve_dimension_with_calc_percent_fallback(
  value : String,
  ctx : ComputeContext,
) -> @types.Dimension {
  let dim = resolve_dimension(value, ctx)
  match dim {
    Auto =>
      if value.trim().has_prefix("calc(") {
        match parse_calc_terms(value, ctx) {
          Some((length_px, percent_ratio)) =>
            if percent_ratio.abs() >= 0.0001 {
              let percent_for_resolution = if value.contains("*") ||
                value.contains("/") {
                match extract_first_percent_ratio(value) {
                  Some(p) => p
                  None => percent_ratio
                }
              } else {
                percent_ratio
              }
              if length_px.abs() >= 0.0001 {
                // Preserve mixed calc() losslessly (px + percent) so layout
                // can resolve it against the correct containing-block basis,
                // e.g. table column widths, as required by CSS Values.
                Calc(length_px, percent_for_resolution)
              } else {
                let basis = mixed_calc_width_reference(ctx)
                Length(basis * percent_for_resolution + length_px)
              }
            } else if length_px.abs() >= 0.0001 {
              Length(length_px)
            } else {
              Length(0.0)
            }
          None => dim
        }
      } else {
        dim
      }
    _ => dim
  }
}

///|
/// Compatibility fallback for mixed calc() in min-size properties.
/// keep current Dimension model and pick axis-specific term when mixed.
fn resolve_dimension_with_mixed_calc_fallback(
  property : String,
  value : String,
  ctx : ComputeContext,
) -> @types.Dimension {
  let dim = resolve_dimension(value, ctx)
  match dim {
    Auto =>
      if value.trim().has_prefix("calc(") {
        match parse_calc_terms(value, ctx) {
          Some((length_px, percent_ratio)) =>
            if length_px.abs() >= 0.0001 && percent_ratio.abs() >= 0.0001 {
              // Preserve mixed calc() losslessly; resolved at layout time
              // against the property's containing-block basis.
              ignore(property)
              Calc(length_px, percent_ratio)
            } else {
              dim
            }
          None => dim
        }
      } else {
        dim
      }
    _ => dim
  }
}

///|
/// Resolve custom properties in an arbitrary CSS property value.
///
/// Returns `None` when the value contains malformed `var()` syntax, refers to
/// a missing property without a fallback, or reaches a custom-property cycle.
pub fn resolve_custom_property_value(
  value : String,
  custom_properties : Map[String, String],
) -> String? {
  resolve_custom_property_value_inner(value, custom_properties, [], 0)
}

///|
fn resolve_custom_property_value_inner(
  value : String,
  custom_properties : Map[String, String],
  stack : Array[String],
  depth : Int,
) -> String? {
  if depth > 32 {
    return None
  }
  let start = match value.find("var(") {
    Some(start) => start
    None => return Some(value)
  }
  let open = start + 3
  let mut close = -1
  let mut paren_depth = 0
  for i in open..<value.length() {
    let c = value[i].to_int().unsafe_to_char()
    if c == '(' {
      paren_depth += 1
    } else if c == ')' {
      paren_depth -= 1
      if paren_depth == 0 {
        close = i
        break
      }
    }
  }
  if close < 0 {
    return None
  }
  let inner = view_to_string(
    value.view(start_offset=open + 1, end_offset=close),
  )
  let mut comma = -1
  paren_depth = 0
  for i in 0..<inner.length() {
    let c = inner[i].to_int().unsafe_to_char()
    if c == '(' {
      paren_depth += 1
    } else if c == ')' {
      paren_depth -= 1
    } else if c == ',' && paren_depth == 0 {
      comma = i
      break
    }
  }
  let name = view_to_string(
      inner.view(end_offset=if comma < 0 { inner.length() } else { comma }),
    )
    .trim()
    .to_owned()
  if !starts_with(name, "--") {
    return None
  }
  let fallback = if comma < 0 {
    None
  } else {
    Some(view_to_string(inner.view(start_offset=comma + 1)).trim().to_owned())
  }
  let replacement = if stack.contains(name) {
    match fallback {
      Some(fallback) =>
        resolve_custom_property_value_inner(
          fallback,
          custom_properties,
          stack,
          depth + 1,
        )
      None => None
    }
  } else {
    match custom_properties.get(name) {
      Some(custom_value) => {
        let next_stack = stack.copy()
        next_stack.push(name)
        match
          resolve_custom_property_value_inner(
            custom_value,
            custom_properties,
            next_stack,
            depth + 1,
          ) {
          Some(value) => Some(value)
          None =>
            match fallback {
              Some(fallback) =>
                resolve_custom_property_value_inner(
                  fallback,
                  custom_properties,
                  stack,
                  depth + 1,
                )
              None => None
            }
        }
      }
      None =>
        match fallback {
          Some(fallback) =>
            resolve_custom_property_value_inner(
              fallback,
              custom_properties,
              stack,
              depth + 1,
            )
          None => None
        }
    }
  }
  match replacement {
    Some(replacement) => {
      let before = view_to_string(value.view(end_offset=start))
      let after = view_to_string(value.view(start_offset=close + 1))
      resolve_custom_property_value_inner(
        before + replacement + after,
        custom_properties,
        stack,
        depth + 1,
      )
    }
    None => None
  }
}

///|
fn resolve_all_vars(value : String, ctx : ComputeContext) -> String {
  match resolve_custom_property_value(value, ctx.custom_properties) {
    Some(value) => value
    None => ""
  }
}

///|
fn strip_css_ascii_whitespace(value : String) -> String {
  let sb = StringBuilder::new()
  for c in value.iter() {
    if !is_css_ascii_whitespace(c) {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn is_css_ascii_whitespace(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u000C'
}

///|
fn is_css_ident_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_'
}

///|
fn css_math_function_prefix_len(value : String, index : Int) -> Int {
  if index > 0 {
    let prev = value[index - 1].to_int().unsafe_to_char()
    if is_css_ident_char(prev) {
      return 0
    }
  }
  let tail = view_to_string(value.view(start_offset=index))
  if tail.has_prefix("calc(") {
    5
  } else if tail.has_prefix("min(") {
    4
  } else if tail.has_prefix("max(") {
    4
  } else if tail.has_prefix("clamp(") {
    6
  } else {
    0
  }
}

///|
fn find_matching_function_end(value : String, index : Int) -> Int {
  let mut depth = 0
  let mut i = index
  while i < value.length() {
    let c = value[i].to_int().unsafe_to_char()
    if c == '(' {
      depth = depth + 1
    } else if c == ')' {
      depth = depth - 1
      if depth == 0 {
        return i
      }
    }
    i = i + 1
  }
  -1
}

///|
fn dimension_to_grid_token(dim : @types.Dimension) -> String? {
  match dim {
    Length(v) => Some(v.to_string() + "px")
    Percent(p) => Some((p * 100.0).to_string() + "%")
    _ => None
  }
}

///|
fn normalize_grid_template_math_functions(
  value : String,
  ctx : ComputeContext,
) -> String {
  let out = StringBuilder::new()
  let mut i = 0
  while i < value.length() {
    let prefix_len = css_math_function_prefix_len(value, i)
    if prefix_len > 0 {
      let end = find_matching_function_end(value, i + prefix_len - 1)
      if end > i {
        let expr = view_to_string(
          value.view(start_offset=i, end_offset=end + 1),
        )
        match dimension_to_grid_token(resolve_dimension(expr, ctx)) {
          Some(token) => {
            out.write_string(token)
            i = end + 1
            continue
          }
          None => ()
        }
      }
    }
    out.write_char(value[i].to_int().unsafe_to_char())
    i = i + 1
  }
  out.to_string()
}

///|
/// Resolve dimension with relative unit conversion

///|
/// Split a "<number><unit>" string into its numeric value and unit. Returns
/// None when there is no leading number. `e`/`E` only begins an exponent when
/// followed by [+-]?digit, so unit strings like "em"/"ex" are not mis-scanned.
fn split_dimension(v : String) -> (Double, String)? {
  let n = v.length()
  if n == 0 {
    return None
  }
  let mut i = 0
  let c0 = v[0].to_int().unsafe_to_char()
  if c0 == '+' || c0 == '-' {
    i = i + 1
  }
  let digits_start = i
  while i < n {
    let c = v[i].to_int().unsafe_to_char()
    if (c >= '0' && c <= '9') || c == '.' {
      i = i + 1
    } else {
      break
    }
  }
  if i < n {
    let e = v[i].to_int().unsafe_to_char()
    if e == 'e' || e == 'E' {
      let mut j = i + 1
      if j < n {
        let s = v[j].to_int().unsafe_to_char()
        if s == '+' || s == '-' {
          j = j + 1
        }
      }
      if j < n &&
        v[j].to_int().unsafe_to_char() >= '0' &&
        v[j].to_int().unsafe_to_char() <= '9' {
        i = j + 1
        while i < n {
          let d = v[i].to_int().unsafe_to_char()
          if d >= '0' && d <= '9' {
            i = i + 1
          } else {
            break
          }
        }
      }
    }
  }
  if i == digits_start {
    return None
  }
  let num = @string.parse_double(v.unsafe_substring(start=0, end=i)) catch {
    _ => return None
  }
  Some((num, v.unsafe_substring(start=i, end=n)))
}

///|
fn resolve_dimension(value : String, ctx : ComputeContext) -> @types.Dimension {
  // First resolve any var() functions
  let raw_v = resolve_all_vars(value, ctx).trim()
  // CSS units and keywords are ASCII case-insensitive. var() names are already
  // resolved above, so lowercasing what remains (a number+unit or a keyword) is
  // safe for the matching below.
  let v = strip_css_ascii_whitespace(raw_v.to_owned()).to_lower()
  if v == "auto" || v == "none" {
    return Auto
  }

  // Handle intrinsic sizing keywords
  if v == "min-content" {
    return MinContent
  }
  if v == "max-content" {
    return MaxContent
  }
  if v == "fit-content" {
    // fit-content without argument is equivalent to fit-content(max-content)
    return FitContent(1.0e10)
  }

  // Handle calc() expressions
  if view_starts_with(raw_v, "calc(") {
    match parse_calc_string(raw_v.to_owned(), ctx) {
      Some(dim) => return dim
      None => return Auto // Fallback for complex calc
    }
  }

  // Handle min(), max(), clamp() CSS math functions
  if view_starts_with(raw_v, "min(") ||
    view_starts_with(raw_v, "max(") ||
    view_starts_with(raw_v, "clamp(") {
    match parse_css_math_function(raw_v.to_owned(), ctx) {
      Some(dim) => return dim
      None => return Auto // Fallback for complex expressions
    }
  }

  // Extract the unit once and dispatch by equality. The string suffix tests
  // this replaces cost ~190ns each; for the common px/% values the old cascade
  // ran 20+ of them before falling through. ch/ex keep the historical 0.5em
  // approximation for generic fonts.
  match split_dimension(v) {
    Some((n, unit)) => {
      let resolved : @types.Dimension? = match unit {
        "px" => Some(Length(n))
        "%" => Some(Percent(n / 100.0))
        "rem" => Some(Length(n * ctx.root_font_size))
        "em" => Some(Length(n * ctx.font_size))
        "vw" | "dvw" | "svw" | "lvw" | "vi" =>
          Some(Length(n * ctx.viewport_width / 100.0))
        "vh" | "dvh" | "svh" | "lvh" | "vb" =>
          Some(Length(n * ctx.viewport_height / 100.0))
        "vmin" => {
          let base = if ctx.viewport_width < ctx.viewport_height {
            ctx.viewport_width
          } else {
            ctx.viewport_height
          }
          Some(Length(n * base / 100.0))
        }
        "vmax" => {
          let base = if ctx.viewport_width > ctx.viewport_height {
            ctx.viewport_width
          } else {
            ctx.viewport_height
          }
          Some(Length(n * base / 100.0))
        }
        "ch" => Some(Length(n * ctx.font_size * ch_unit_ratio(ctx)))
        "ex" => Some(Length(n * ctx.font_size * 0.5))
        "pt" => Some(Length(n * 96.0 / 72.0))
        "pc" => Some(Length(n * 16.0))
        "in" => Some(Length(n * 96.0))
        "cm" => Some(Length(n * 96.0 / 2.54))
        "mm" => Some(Length(n * 96.0 / 25.4))
        "q" => Some(Length(n * 96.0 / 101.6))
        _ => None
      }
      match resolved {
        Some(d) => return d
        None => ()
      }
    }
    None => ()
  }

  // Fall back for unitless, fit-content(...) and unknown units.
  parse_dimension(v.to_string())
}

///|
/// Check if a string is a pure number (no units)
fn is_pure_number(s : String) -> Bool {
  let v = s.trim()
  if v.is_empty() {
    return false
  }
  // Try to parse as double - will fail if it has units
  let _ = @string.parse_double(v.to_owned()) catch { _ => return false }
  // Make sure it doesn't have any unit suffixes that parse_double might accept
  for i = 0; i < v.length(); i = i + 1 {
    let c = v[i]
    if !(c == '0' ||
      c == '1' ||
      c == '2' ||
      c == '3' ||
      c == '4' ||
      c == '5' ||
      c == '6' ||
      c == '7' ||
      c == '8' ||
      c == '9' ||
      c == '.' ||
      c == '-' ||
      c == '+') {
      return false
    }
  }
  true
}
