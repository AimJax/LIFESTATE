class_name Uuid
extends RefCounted

## Guid equivalent for persistence. C# stores System.Guid as the canonical
## 36-character "D" form (8-4-4-4-12), so that is what we generate and accept.

const EMPTY: String = "00000000-0000-0000-0000-000000000000"


static func new_v4() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	return format_bytes(bytes)


static func format_bytes(bytes: PackedByteArray) -> String:
	return "%s-%s-%s-%s-%s" % [
		bytes.slice(0, 4).hex_encode(),
		bytes.slice(4, 6).hex_encode(),
		bytes.slice(6, 8).hex_encode(),
		bytes.slice(8, 10).hex_encode(),
		bytes.slice(10, 16).hex_encode(),
	]


static func is_empty(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return true
	var text: String = value
	return text.is_empty() or text == EMPTY or text.to_lower() == EMPTY


static func is_valid(value: Variant) -> bool:
	var text := _normalize(value)
	if text.is_empty():
		return false
	if text.length() != 32:
		return false
	return text.is_valid_hex_number(false)


## Accepts the .NET reader formats: D (36 chars), N (32), B ({...}), P ((...)).
static func _normalize(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var text: String = value.strip_edges()
	text = text.replace("{", "").replace("}", "").replace("(", "").replace(")", "")
	text = text.replace("-", "")
	return text
