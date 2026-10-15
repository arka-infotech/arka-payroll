/// PostgreSQL decimals often arrive as JSON strings.
num parseApiNum(dynamic value, {num fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? fallback;
}
