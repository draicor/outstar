#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2023, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && (varint[8] & 0x80 != 0):
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		var value = 0
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			for i in range(index, count + index):
				spb.put_u8(bytes[i])
			spb.seek(0)
			value = spb.get_float()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			for i in range(index, count + index):
				spb.put_u8(bytes[i])
			spb.seek(0)
			value = spb.get_double()
		else:
			for i in range(index + count - 1, index - 1, -1):
				value |= (bytes[i] & 0xFF)
				if i != index:
					value <<= 8
		return value

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		for i in range(varint_bytes.size() - 1, -1, -1):
			value |= varint_bytes[i] & 0x7F
			if i != 0:
				value <<= 7
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var result : PackedByteArray = PackedByteArray()
		for i in range(index, bytes.size()):
			result.append(bytes[i])
			if !(bytes[i] & 0x80):
				break
		return result

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func skip_unknown_field(bytes : PackedByteArray, offset : int, type : int) -> int:
		if type == PB_TYPE.VARINT:
			return offset + isolate_varint(bytes, offset).size()
		if type == PB_TYPE.FIX64:
			return offset + 8
		if type == PB_TYPE.LENGTHDEL:
			var length_bytes : PackedByteArray = isolate_varint(bytes, offset)
			var length : int = unpack_varint(length_bytes)
			return offset + length_bytes.size() + length
		if type == PB_TYPE.FIX32:
			return offset + 4
		return PB_ERR.UNDEFINED_STATE

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = PackedByteArray()
							for i in range(offset, inner_size + offset):
								str_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = PackedByteArray()
							for i in range(offset, inner_size + offset):
								val_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
				else:
					var res : int = skip_unknown_field(bytes, offset, tt.type)
					if res > 0:
						offset = res
						if offset == limit:
							return offset
						elif offset > limit:
							return PB_ERR.PACKAGE_SIZE_MISMATCH
					elif res < 0:
						return res
					else:
						break							
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


class Position:
	func _init():
		var service
		
		__x = PBField.new("x", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__z = PBField.new("z", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __z
		data[__z.tag] = service
		
	var data = {}
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> int:
		return __x.value
	func clear_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_x(value : int) -> void:
		__x.value = value
	
	var __z: PBField
	func has_z() -> bool:
		if __z.value != null:
			return true
		return false
	func get_z() -> int:
		return __z.value
	func clear_z() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_z(value : int) -> void:
		__z.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PublicMessage:
	func _init():
		var service
		
		__nickname = PBField.new("nickname", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __nickname
		data[__nickname.tag] = service
		
		__text = PBField.new("text", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __text
		data[__text.tag] = service
		
	var data = {}
	
	var __nickname: PBField
	func has_nickname() -> bool:
		if __nickname.value != null:
			return true
		return false
	func get_nickname() -> String:
		return __nickname.value
	func clear_nickname() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__nickname.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_nickname(value : String) -> void:
		__nickname.value = value
	
	var __text: PBField
	func has_text() -> bool:
		if __text.value != null:
			return true
		return false
	func get_text() -> String:
		return __text.value
	func clear_text() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__text.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_text(value : String) -> void:
		__text.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Handshake:
	func _init():
		var service
		
		__version = PBField.new("version", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __version
		data[__version.tag] = service
		
	var data = {}
	
	var __version: PBField
	func has_version() -> bool:
		if __version.value != null:
			return true
		return false
	func get_version() -> String:
		return __version.value
	func clear_version() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__version.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_version(value : String) -> void:
		__version.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Heartbeat:
	func _init():
		var _service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ServerMetrics:
	func _init():
		var service
		
		__players_online = PBField.new("players_online", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __players_online
		data[__players_online.tag] = service
		
	var data = {}
	
	var __players_online: PBField
	func has_players_online() -> bool:
		if __players_online.value != null:
			return true
		return false
	func get_players_online() -> int:
		return __players_online.value
	func clear_players_online() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__players_online.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_players_online(value : int) -> void:
		__players_online.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RequestGranted:
	func _init():
		var _service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RequestDenied:
	func _init():
		var service
		
		__reason = PBField.new("reason", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __reason
		data[__reason.tag] = service
		
	var data = {}
	
	var __reason: PBField
	func has_reason() -> bool:
		if __reason.value != null:
			return true
		return false
	func get_reason() -> String:
		return __reason.value
	func clear_reason() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__reason.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_reason(value : String) -> void:
		__reason.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class LoginRequest:
	func _init():
		var service
		
		__username = PBField.new("username", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __username
		data[__username.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
	var data = {}
	
	var __username: PBField
	func has_username() -> bool:
		if __username.value != null:
			return true
		return false
	func get_username() -> String:
		return __username.value
	func clear_username() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__username.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_username(value : String) -> void:
		__username.value = value
	
	var __password: PBField
	func has_password() -> bool:
		if __password.value != null:
			return true
		return false
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RegisterRequest:
	func _init():
		var service
		
		__username = PBField.new("username", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __username
		data[__username.tag] = service
		
		__nickname = PBField.new("nickname", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __nickname
		data[__nickname.tag] = service
		
		__password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __password
		data[__password.tag] = service
		
		__gender = PBField.new("gender", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __gender
		data[__gender.tag] = service
		
	var data = {}
	
	var __username: PBField
	func has_username() -> bool:
		if __username.value != null:
			return true
		return false
	func get_username() -> String:
		return __username.value
	func clear_username() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__username.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_username(value : String) -> void:
		__username.value = value
	
	var __nickname: PBField
	func has_nickname() -> bool:
		if __nickname.value != null:
			return true
		return false
	func get_nickname() -> String:
		return __nickname.value
	func clear_nickname() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__nickname.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_nickname(value : String) -> void:
		__nickname.value = value
	
	var __password: PBField
	func has_password() -> bool:
		if __password.value != null:
			return true
		return false
	func get_password() -> String:
		return __password.value
	func clear_password() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		__password.value = value
	
	var __gender: PBField
	func has_gender() -> bool:
		if __gender.value != null:
			return true
		return false
	func get_gender() -> String:
		return __gender.value
	func clear_gender() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__gender.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_gender(value : String) -> void:
		__gender.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class LoginSuccess:
	func _init():
		var service
		
		__nickname = PBField.new("nickname", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __nickname
		data[__nickname.tag] = service
		
	var data = {}
	
	var __nickname: PBField
	func has_nickname() -> bool:
		if __nickname.value != null:
			return true
		return false
	func get_nickname() -> String:
		return __nickname.value
	func clear_nickname() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__nickname.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_nickname(value : String) -> void:
		__nickname.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class LogoutRequest:
	func _init():
		var _service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ClientEntered:
	func _init():
		var service
		
		__nickname = PBField.new("nickname", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __nickname
		data[__nickname.tag] = service
		
	var data = {}
	
	var __nickname: PBField
	func has_nickname() -> bool:
		if __nickname.value != null:
			return true
		return false
	func get_nickname() -> String:
		return __nickname.value
	func clear_nickname() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__nickname.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_nickname(value : String) -> void:
		__nickname.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ClientLeft:
	func _init():
		var service
		
		__nickname = PBField.new("nickname", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __nickname
		data[__nickname.tag] = service
		
	var data = {}
	
	var __nickname: PBField
	func has_nickname() -> bool:
		if __nickname.value != null:
			return true
		return false
	func get_nickname() -> String:
		return __nickname.value
	func clear_nickname() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__nickname.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_nickname(value : String) -> void:
		__nickname.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class JoinRegionRequest:
	func _init():
		var service
		
		__region_id = PBField.new("region_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __region_id
		data[__region_id.tag] = service
		
	var data = {}
	
	var __region_id: PBField
	func has_region_id() -> bool:
		if __region_id.value != null:
			return true
		return false
	func get_region_id() -> int:
		return __region_id.value
	func clear_region_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__region_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_region_id(value : int) -> void:
		__region_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RegionData:
	func _init():
		var service
		
		__region_id = PBField.new("region_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __region_id
		data[__region_id.tag] = service
		
		__grid_width = PBField.new("grid_width", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __grid_width
		data[__grid_width.tag] = service
		
		__grid_height = PBField.new("grid_height", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __grid_height
		data[__grid_height.tag] = service
		
	var data = {}
	
	var __region_id: PBField
	func has_region_id() -> bool:
		if __region_id.value != null:
			return true
		return false
	func get_region_id() -> int:
		return __region_id.value
	func clear_region_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__region_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_region_id(value : int) -> void:
		__region_id.value = value
	
	var __grid_width: PBField
	func has_grid_width() -> bool:
		if __grid_width.value != null:
			return true
		return false
	func get_grid_width() -> int:
		return __grid_width.value
	func clear_grid_width() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__grid_width.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_grid_width(value : int) -> void:
		__grid_width.value = value
	
	var __grid_height: PBField
	func has_grid_height() -> bool:
		if __grid_height.value != null:
			return true
		return false
	func get_grid_height() -> int:
		return __grid_height.value
	func clear_grid_height() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__grid_height.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_grid_height(value : int) -> void:
		__grid_height.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SpawnCharacter:
	func _init():
		var service
		
		__id = PBField.new("id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __id
		data[__id.tag] = service
		
		__name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __name
		data[__name.tag] = service
		
		__position = PBField.new("position", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __position
		service.func_ref = Callable(self, "new_position")
		data[__position.tag] = service
		
		__rotation_y = PBField.new("rotation_y", PB_DATA_TYPE.DOUBLE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.DOUBLE])
		service = PBServiceField.new()
		service.field = __rotation_y
		data[__rotation_y.tag] = service
		
		__gender = PBField.new("gender", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __gender
		data[__gender.tag] = service
		
		__speed = PBField.new("speed", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __speed
		data[__speed.tag] = service
		
		__health = PBField.new("health", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __health
		data[__health.tag] = service
		
		__max_health = PBField.new("max_health", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __max_health
		data[__max_health.tag] = service
		
		__current_weapon = PBField.new("current_weapon", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __current_weapon
		data[__current_weapon.tag] = service
		
		var __weapons_default: Array[WeaponSlot] = []
		__weapons = PBField.new("weapons", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 10, true, __weapons_default)
		service = PBServiceField.new()
		service.field = __weapons
		service.func_ref = Callable(self, "add_weapons")
		data[__weapons.tag] = service
		
		__is_crouching = PBField.new("is_crouching", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_crouching
		data[__is_crouching.tag] = service
		
	var data = {}
	
	var __id: PBField
	func has_id() -> bool:
		if __id.value != null:
			return true
		return false
	func get_id() -> int:
		return __id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_id(value : int) -> void:
		__id.value = value
	
	var __name: PBField
	func has_name() -> bool:
		if __name.value != null:
			return true
		return false
	func get_name() -> String:
		return __name.value
	func clear_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		__name.value = value
	
	var __position: PBField
	func has_position() -> bool:
		if __position.value != null:
			return true
		return false
	func get_position() -> Position:
		return __position.value
	func clear_position() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__position.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_position() -> Position:
		__position.value = Position.new()
		return __position.value
	
	var __rotation_y: PBField
	func has_rotation_y() -> bool:
		if __rotation_y.value != null:
			return true
		return false
	func get_rotation_y() -> float:
		return __rotation_y.value
	func clear_rotation_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__rotation_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.DOUBLE]
	func set_rotation_y(value : float) -> void:
		__rotation_y.value = value
	
	var __gender: PBField
	func has_gender() -> bool:
		if __gender.value != null:
			return true
		return false
	func get_gender() -> String:
		return __gender.value
	func clear_gender() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__gender.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_gender(value : String) -> void:
		__gender.value = value
	
	var __speed: PBField
	func has_speed() -> bool:
		if __speed.value != null:
			return true
		return false
	func get_speed() -> int:
		return __speed.value
	func clear_speed() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_speed(value : int) -> void:
		__speed.value = value
	
	var __health: PBField
	func has_health() -> bool:
		if __health.value != null:
			return true
		return false
	func get_health() -> int:
		return __health.value
	func clear_health() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__health.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_health(value : int) -> void:
		__health.value = value
	
	var __max_health: PBField
	func has_max_health() -> bool:
		if __max_health.value != null:
			return true
		return false
	func get_max_health() -> int:
		return __max_health.value
	func clear_max_health() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__max_health.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_max_health(value : int) -> void:
		__max_health.value = value
	
	var __current_weapon: PBField
	func has_current_weapon() -> bool:
		if __current_weapon.value != null:
			return true
		return false
	func get_current_weapon() -> int:
		return __current_weapon.value
	func clear_current_weapon() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__current_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_current_weapon(value : int) -> void:
		__current_weapon.value = value
	
	var __weapons: PBField
	func get_weapons() -> Array[WeaponSlot]:
		return __weapons.value
	func clear_weapons() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__weapons.value.clear()
	func add_weapons() -> WeaponSlot:
		var element = WeaponSlot.new()
		__weapons.value.append(element)
		return element
	
	var __is_crouching: PBField
	func has_is_crouching() -> bool:
		if __is_crouching.value != null:
			return true
		return false
	func get_is_crouching() -> bool:
		return __is_crouching.value
	func clear_is_crouching() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__is_crouching.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_crouching(value : bool) -> void:
		__is_crouching.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class MoveCharacter:
	func _init():
		var service
		
		__position = PBField.new("position", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __position
		service.func_ref = Callable(self, "new_position")
		data[__position.tag] = service
		
	var data = {}
	
	var __position: PBField
	func has_position() -> bool:
		if __position.value != null:
			return true
		return false
	func get_position() -> Position:
		return __position.value
	func clear_position() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__position.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_position() -> Position:
		__position.value = Position.new()
		return __position.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RotateCharacter:
	func _init():
		var service
		
		__rotation_y = PBField.new("rotation_y", PB_DATA_TYPE.DOUBLE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.DOUBLE])
		service = PBServiceField.new()
		service.field = __rotation_y
		data[__rotation_y.tag] = service
		
	var data = {}
	
	var __rotation_y: PBField
	func has_rotation_y() -> bool:
		if __rotation_y.value != null:
			return true
		return false
	func get_rotation_y() -> float:
		return __rotation_y.value
	func clear_rotation_y() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__rotation_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.DOUBLE]
	func set_rotation_y(value : float) -> void:
		__rotation_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Destination:
	func _init():
		var service
		
		__x = PBField.new("x", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__z = PBField.new("z", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __z
		data[__z.tag] = service
		
	var data = {}
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> int:
		return __x.value
	func clear_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_x(value : int) -> void:
		__x.value = value
	
	var __z: PBField
	func has_z() -> bool:
		if __z.value != null:
			return true
		return false
	func get_z() -> int:
		return __z.value
	func clear_z() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_z(value : int) -> void:
		__z.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class UpdateSpeed:
	func _init():
		var service
		
		__speed = PBField.new("speed", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __speed
		data[__speed.tag] = service
		
	var data = {}
	
	var __speed: PBField
	func has_speed() -> bool:
		if __speed.value != null:
			return true
		return false
	func get_speed() -> int:
		return __speed.value
	func clear_speed() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_speed(value : int) -> void:
		__speed.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ChatBubble:
	func _init():
		var service
		
		__is_active = PBField.new("is_active", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_active
		data[__is_active.tag] = service
		
	var data = {}
	
	var __is_active: PBField
	func has_is_active() -> bool:
		if __is_active.value != null:
			return true
		return false
	func get_is_active() -> bool:
		return __is_active.value
	func clear_is_active() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__is_active.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_active(value : bool) -> void:
		__is_active.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SwitchWeapon:
	func _init():
		var service
		
		__slot = PBField.new("slot", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __slot
		data[__slot.tag] = service
		
	var data = {}
	
	var __slot: PBField
	func has_slot() -> bool:
		if __slot.value != null:
			return true
		return false
	func get_slot() -> int:
		return __slot.value
	func clear_slot() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__slot.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_slot(value : int) -> void:
		__slot.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class WeaponSlot:
	func _init():
		var service
		
		__slot_index = PBField.new("slot_index", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __slot_index
		data[__slot_index.tag] = service
		
		__weapon_name = PBField.new("weapon_name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __weapon_name
		data[__weapon_name.tag] = service
		
		__weapon_type = PBField.new("weapon_type", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __weapon_type
		data[__weapon_type.tag] = service
		
		__display_name = PBField.new("display_name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __display_name
		data[__display_name.tag] = service
		
		__ammo = PBField.new("ammo", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __ammo
		data[__ammo.tag] = service
		
		__fire_mode = PBField.new("fire_mode", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __fire_mode
		data[__fire_mode.tag] = service
		
	var data = {}
	
	var __slot_index: PBField
	func has_slot_index() -> bool:
		if __slot_index.value != null:
			return true
		return false
	func get_slot_index() -> int:
		return __slot_index.value
	func clear_slot_index() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__slot_index.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_slot_index(value : int) -> void:
		__slot_index.value = value
	
	var __weapon_name: PBField
	func has_weapon_name() -> bool:
		if __weapon_name.value != null:
			return true
		return false
	func get_weapon_name() -> String:
		return __weapon_name.value
	func clear_weapon_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__weapon_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_weapon_name(value : String) -> void:
		__weapon_name.value = value
	
	var __weapon_type: PBField
	func has_weapon_type() -> bool:
		if __weapon_type.value != null:
			return true
		return false
	func get_weapon_type() -> String:
		return __weapon_type.value
	func clear_weapon_type() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__weapon_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_weapon_type(value : String) -> void:
		__weapon_type.value = value
	
	var __display_name: PBField
	func has_display_name() -> bool:
		if __display_name.value != null:
			return true
		return false
	func get_display_name() -> String:
		return __display_name.value
	func clear_display_name() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__display_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_display_name(value : String) -> void:
		__display_name.value = value
	
	var __ammo: PBField
	func has_ammo() -> bool:
		if __ammo.value != null:
			return true
		return false
	func get_ammo() -> int:
		return __ammo.value
	func clear_ammo() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__ammo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_ammo(value : int) -> void:
		__ammo.value = value
	
	var __fire_mode: PBField
	func has_fire_mode() -> bool:
		if __fire_mode.value != null:
			return true
		return false
	func get_fire_mode() -> int:
		return __fire_mode.value
	func clear_fire_mode() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_fire_mode(value : int) -> void:
		__fire_mode.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ReloadWeapon:
	func _init():
		var service
		
		__slot = PBField.new("slot", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __slot
		data[__slot.tag] = service
		
		__amount = PBField.new("amount", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __amount
		data[__amount.tag] = service
		
	var data = {}
	
	var __slot: PBField
	func has_slot() -> bool:
		if __slot.value != null:
			return true
		return false
	func get_slot() -> int:
		return __slot.value
	func clear_slot() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__slot.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_slot(value : int) -> void:
		__slot.value = value
	
	var __amount: PBField
	func has_amount() -> bool:
		if __amount.value != null:
			return true
		return false
	func get_amount() -> int:
		return __amount.value
	func clear_amount() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__amount.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_amount(value : int) -> void:
		__amount.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RaiseWeapon:
	func _init():
		var _service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class LowerWeapon:
	func _init():
		var _service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class FireWeapon:
	func _init():
		var service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__z = PBField.new("z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __z
		data[__z.tag] = service
		
		__rotation_y = PBField.new("rotation_y", PB_DATA_TYPE.DOUBLE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.DOUBLE])
		service = PBServiceField.new()
		service.field = __rotation_y
		data[__rotation_y.tag] = service
		
	var data = {}
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	var __z: PBField
	func has_z() -> bool:
		if __z.value != null:
			return true
		return false
	func get_z() -> float:
		return __z.value
	func clear_z() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_z(value : float) -> void:
		__z.value = value
	
	var __rotation_y: PBField
	func has_rotation_y() -> bool:
		if __rotation_y.value != null:
			return true
		return false
	func get_rotation_y() -> float:
		return __rotation_y.value
	func clear_rotation_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__rotation_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.DOUBLE]
	func set_rotation_y(value : float) -> void:
		__rotation_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ToggleFireMode:
	func _init():
		var _service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class StartFiringWeapon:
	func _init():
		var service
		
		__rotation_y = PBField.new("rotation_y", PB_DATA_TYPE.DOUBLE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.DOUBLE])
		service = PBServiceField.new()
		service.field = __rotation_y
		data[__rotation_y.tag] = service
		
		__ammo = PBField.new("ammo", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __ammo
		data[__ammo.tag] = service
		
	var data = {}
	
	var __rotation_y: PBField
	func has_rotation_y() -> bool:
		if __rotation_y.value != null:
			return true
		return false
	func get_rotation_y() -> float:
		return __rotation_y.value
	func clear_rotation_y() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__rotation_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.DOUBLE]
	func set_rotation_y(value : float) -> void:
		__rotation_y.value = value
	
	var __ammo: PBField
	func has_ammo() -> bool:
		if __ammo.value != null:
			return true
		return false
	func get_ammo() -> int:
		return __ammo.value
	func clear_ammo() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__ammo.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_ammo(value : int) -> void:
		__ammo.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class StopFiringWeapon:
	func _init():
		var service
		
		__rotation_y = PBField.new("rotation_y", PB_DATA_TYPE.DOUBLE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.DOUBLE])
		service = PBServiceField.new()
		service.field = __rotation_y
		data[__rotation_y.tag] = service
		
		__shots_fired = PBField.new("shots_fired", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __shots_fired
		data[__shots_fired.tag] = service
		
	var data = {}
	
	var __rotation_y: PBField
	func has_rotation_y() -> bool:
		if __rotation_y.value != null:
			return true
		return false
	func get_rotation_y() -> float:
		return __rotation_y.value
	func clear_rotation_y() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__rotation_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.DOUBLE]
	func set_rotation_y(value : float) -> void:
		__rotation_y.value = value
	
	var __shots_fired: PBField
	func has_shots_fired() -> bool:
		if __shots_fired.value != null:
			return true
		return false
	func get_shots_fired() -> int:
		return __shots_fired.value
	func clear_shots_fired() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__shots_fired.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_shots_fired(value : int) -> void:
		__shots_fired.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ReportPlayerDamage:
	func _init():
		var service
		
		__target_id = PBField.new("target_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __target_id
		data[__target_id.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__z = PBField.new("z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __z
		data[__z.tag] = service
		
		__is_critical = PBField.new("is_critical", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_critical
		data[__is_critical.tag] = service
		
	var data = {}
	
	var __target_id: PBField
	func has_target_id() -> bool:
		if __target_id.value != null:
			return true
		return false
	func get_target_id() -> int:
		return __target_id.value
	func clear_target_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__target_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_target_id(value : int) -> void:
		__target_id.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	var __z: PBField
	func has_z() -> bool:
		if __z.value != null:
			return true
		return false
	func get_z() -> float:
		return __z.value
	func clear_z() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_z(value : float) -> void:
		__z.value = value
	
	var __is_critical: PBField
	func has_is_critical() -> bool:
		if __is_critical.value != null:
			return true
		return false
	func get_is_critical() -> bool:
		return __is_critical.value
	func clear_is_critical() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__is_critical.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_critical(value : bool) -> void:
		__is_critical.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ApplyPlayerDamage:
	func _init():
		var service
		
		__attacker_id = PBField.new("attacker_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __attacker_id
		data[__attacker_id.tag] = service
		
		__target_id = PBField.new("target_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __target_id
		data[__target_id.tag] = service
		
		__damage = PBField.new("damage", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __damage
		data[__damage.tag] = service
		
		__damage_type = PBField.new("damage_type", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __damage_type
		data[__damage_type.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__z = PBField.new("z", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __z
		data[__z.tag] = service
		
	var data = {}
	
	var __attacker_id: PBField
	func has_attacker_id() -> bool:
		if __attacker_id.value != null:
			return true
		return false
	func get_attacker_id() -> int:
		return __attacker_id.value
	func clear_attacker_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__attacker_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_attacker_id(value : int) -> void:
		__attacker_id.value = value
	
	var __target_id: PBField
	func has_target_id() -> bool:
		if __target_id.value != null:
			return true
		return false
	func get_target_id() -> int:
		return __target_id.value
	func clear_target_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__target_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_target_id(value : int) -> void:
		__target_id.value = value
	
	var __damage: PBField
	func has_damage() -> bool:
		if __damage.value != null:
			return true
		return false
	func get_damage() -> int:
		return __damage.value
	func clear_damage() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_damage(value : int) -> void:
		__damage.value = value
	
	var __damage_type: PBField
	func has_damage_type() -> bool:
		if __damage_type.value != null:
			return true
		return false
	func get_damage_type() -> String:
		return __damage_type.value
	func clear_damage_type() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__damage_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_damage_type(value : String) -> void:
		__damage_type.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	var __z: PBField
	func has_z() -> bool:
		if __z.value != null:
			return true
		return false
	func get_z() -> float:
		return __z.value
	func clear_z() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_z(value : float) -> void:
		__z.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PlayerDied:
	func _init():
		var service
		
		__attacker_id = PBField.new("attacker_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __attacker_id
		data[__attacker_id.tag] = service
		
		__target_id = PBField.new("target_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __target_id
		data[__target_id.tag] = service
		
	var data = {}
	
	var __attacker_id: PBField
	func has_attacker_id() -> bool:
		if __attacker_id.value != null:
			return true
		return false
	func get_attacker_id() -> int:
		return __attacker_id.value
	func clear_attacker_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__attacker_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_attacker_id(value : int) -> void:
		__attacker_id.value = value
	
	var __target_id: PBField
	func has_target_id() -> bool:
		if __target_id.value != null:
			return true
		return false
	func get_target_id() -> int:
		return __target_id.value
	func clear_target_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__target_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_target_id(value : int) -> void:
		__target_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RespawnRequest:
	func _init():
		var service
		
		__region_id = PBField.new("region_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __region_id
		data[__region_id.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__z = PBField.new("z", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __z
		data[__z.tag] = service
		
	var data = {}
	
	var __region_id: PBField
	func has_region_id() -> bool:
		if __region_id.value != null:
			return true
		return false
	func get_region_id() -> int:
		return __region_id.value
	func clear_region_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__region_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_region_id(value : int) -> void:
		__region_id.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> int:
		return __x.value
	func clear_x() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_x(value : int) -> void:
		__x.value = value
	
	var __z: PBField
	func has_z() -> bool:
		if __z.value != null:
			return true
		return false
	func get_z() -> int:
		return __z.value
	func clear_z() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__z.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_z(value : int) -> void:
		__z.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class CrouchCharacter:
	func _init():
		var service
		
		__is_crouching = PBField.new("is_crouching", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __is_crouching
		data[__is_crouching.tag] = service
		
	var data = {}
	
	var __is_crouching: PBField
	func has_is_crouching() -> bool:
		if __is_crouching.value != null:
			return true
		return false
	func get_is_crouching() -> bool:
		return __is_crouching.value
	func clear_is_crouching() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__is_crouching.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_is_crouching(value : bool) -> void:
		__is_crouching.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Packet:
	func _init():
		var service
		
		__sender_id = PBField.new("sender_id", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __sender_id
		data[__sender_id.tag] = service
		
		__public_message = PBField.new("public_message", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __public_message
		service.func_ref = Callable(self, "new_public_message")
		data[__public_message.tag] = service
		
		__handshake = PBField.new("handshake", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __handshake
		service.func_ref = Callable(self, "new_handshake")
		data[__handshake.tag] = service
		
		__heartbeat = PBField.new("heartbeat", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __heartbeat
		service.func_ref = Callable(self, "new_heartbeat")
		data[__heartbeat.tag] = service
		
		__server_metrics = PBField.new("server_metrics", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __server_metrics
		service.func_ref = Callable(self, "new_server_metrics")
		data[__server_metrics.tag] = service
		
		__request_granted = PBField.new("request_granted", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __request_granted
		service.func_ref = Callable(self, "new_request_granted")
		data[__request_granted.tag] = service
		
		__request_denied = PBField.new("request_denied", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __request_denied
		service.func_ref = Callable(self, "new_request_denied")
		data[__request_denied.tag] = service
		
		__login_request = PBField.new("login_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __login_request
		service.func_ref = Callable(self, "new_login_request")
		data[__login_request.tag] = service
		
		__register_request = PBField.new("register_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __register_request
		service.func_ref = Callable(self, "new_register_request")
		data[__register_request.tag] = service
		
		__login_success = PBField.new("login_success", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __login_success
		service.func_ref = Callable(self, "new_login_success")
		data[__login_success.tag] = service
		
		__logout_request = PBField.new("logout_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __logout_request
		service.func_ref = Callable(self, "new_logout_request")
		data[__logout_request.tag] = service
		
		__client_entered = PBField.new("client_entered", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __client_entered
		service.func_ref = Callable(self, "new_client_entered")
		data[__client_entered.tag] = service
		
		__client_left = PBField.new("client_left", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __client_left
		service.func_ref = Callable(self, "new_client_left")
		data[__client_left.tag] = service
		
		__join_region_request = PBField.new("join_region_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __join_region_request
		service.func_ref = Callable(self, "new_join_region_request")
		data[__join_region_request.tag] = service
		
		__region_data = PBField.new("region_data", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 15, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __region_data
		service.func_ref = Callable(self, "new_region_data")
		data[__region_data.tag] = service
		
		__spawn_character = PBField.new("spawn_character", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 16, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __spawn_character
		service.func_ref = Callable(self, "new_spawn_character")
		data[__spawn_character.tag] = service
		
		__move_character = PBField.new("move_character", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 17, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __move_character
		service.func_ref = Callable(self, "new_move_character")
		data[__move_character.tag] = service
		
		__rotate_character = PBField.new("rotate_character", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 18, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __rotate_character
		service.func_ref = Callable(self, "new_rotate_character")
		data[__rotate_character.tag] = service
		
		__destination = PBField.new("destination", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 19, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __destination
		service.func_ref = Callable(self, "new_destination")
		data[__destination.tag] = service
		
		__update_speed = PBField.new("update_speed", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 20, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __update_speed
		service.func_ref = Callable(self, "new_update_speed")
		data[__update_speed.tag] = service
		
		__chat_bubble = PBField.new("chat_bubble", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 21, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __chat_bubble
		service.func_ref = Callable(self, "new_chat_bubble")
		data[__chat_bubble.tag] = service
		
		__switch_weapon = PBField.new("switch_weapon", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 22, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __switch_weapon
		service.func_ref = Callable(self, "new_switch_weapon")
		data[__switch_weapon.tag] = service
		
		__reload_weapon = PBField.new("reload_weapon", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 23, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __reload_weapon
		service.func_ref = Callable(self, "new_reload_weapon")
		data[__reload_weapon.tag] = service
		
		__raise_weapon = PBField.new("raise_weapon", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 24, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __raise_weapon
		service.func_ref = Callable(self, "new_raise_weapon")
		data[__raise_weapon.tag] = service
		
		__lower_weapon = PBField.new("lower_weapon", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 25, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __lower_weapon
		service.func_ref = Callable(self, "new_lower_weapon")
		data[__lower_weapon.tag] = service
		
		__fire_weapon = PBField.new("fire_weapon", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 26, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __fire_weapon
		service.func_ref = Callable(self, "new_fire_weapon")
		data[__fire_weapon.tag] = service
		
		__toggle_fire_mode = PBField.new("toggle_fire_mode", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 27, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __toggle_fire_mode
		service.func_ref = Callable(self, "new_toggle_fire_mode")
		data[__toggle_fire_mode.tag] = service
		
		__start_firing_weapon = PBField.new("start_firing_weapon", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 28, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __start_firing_weapon
		service.func_ref = Callable(self, "new_start_firing_weapon")
		data[__start_firing_weapon.tag] = service
		
		__stop_firing_weapon = PBField.new("stop_firing_weapon", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 29, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __stop_firing_weapon
		service.func_ref = Callable(self, "new_stop_firing_weapon")
		data[__stop_firing_weapon.tag] = service
		
		__report_player_damage = PBField.new("report_player_damage", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 30, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __report_player_damage
		service.func_ref = Callable(self, "new_report_player_damage")
		data[__report_player_damage.tag] = service
		
		__apply_player_damage = PBField.new("apply_player_damage", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 31, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __apply_player_damage
		service.func_ref = Callable(self, "new_apply_player_damage")
		data[__apply_player_damage.tag] = service
		
		__player_died = PBField.new("player_died", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 32, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __player_died
		service.func_ref = Callable(self, "new_player_died")
		data[__player_died.tag] = service
		
		__respawn_request = PBField.new("respawn_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 33, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __respawn_request
		service.func_ref = Callable(self, "new_respawn_request")
		data[__respawn_request.tag] = service
		
		__crouch_character = PBField.new("crouch_character", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 34, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __crouch_character
		service.func_ref = Callable(self, "new_crouch_character")
		data[__crouch_character.tag] = service
		
	var data = {}
	
	var __sender_id: PBField
	func has_sender_id() -> bool:
		if __sender_id.value != null:
			return true
		return false
	func get_sender_id() -> int:
		return __sender_id.value
	func clear_sender_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__sender_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_sender_id(value : int) -> void:
		__sender_id.value = value
	
	var __public_message: PBField
	func has_public_message() -> bool:
		if __public_message.value != null:
			return true
		return false
	func get_public_message() -> PublicMessage:
		return __public_message.value
	func clear_public_message() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_public_message() -> PublicMessage:
		data[2].state = PB_SERVICE_STATE.FILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__public_message.value = PublicMessage.new()
		return __public_message.value
	
	var __handshake: PBField
	func has_handshake() -> bool:
		if __handshake.value != null:
			return true
		return false
	func get_handshake() -> Handshake:
		return __handshake.value
	func clear_handshake() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_handshake() -> Handshake:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		data[3].state = PB_SERVICE_STATE.FILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = Handshake.new()
		return __handshake.value
	
	var __heartbeat: PBField
	func has_heartbeat() -> bool:
		if __heartbeat.value != null:
			return true
		return false
	func get_heartbeat() -> Heartbeat:
		return __heartbeat.value
	func clear_heartbeat() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_heartbeat() -> Heartbeat:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		data[4].state = PB_SERVICE_STATE.FILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = Heartbeat.new()
		return __heartbeat.value
	
	var __server_metrics: PBField
	func has_server_metrics() -> bool:
		if __server_metrics.value != null:
			return true
		return false
	func get_server_metrics() -> ServerMetrics:
		return __server_metrics.value
	func clear_server_metrics() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_server_metrics() -> ServerMetrics:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = ServerMetrics.new()
		return __server_metrics.value
	
	var __request_granted: PBField
	func has_request_granted() -> bool:
		if __request_granted.value != null:
			return true
		return false
	func get_request_granted() -> RequestGranted:
		return __request_granted.value
	func clear_request_granted() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_request_granted() -> RequestGranted:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		data[6].state = PB_SERVICE_STATE.FILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = RequestGranted.new()
		return __request_granted.value
	
	var __request_denied: PBField
	func has_request_denied() -> bool:
		if __request_denied.value != null:
			return true
		return false
	func get_request_denied() -> RequestDenied:
		return __request_denied.value
	func clear_request_denied() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_request_denied() -> RequestDenied:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		data[7].state = PB_SERVICE_STATE.FILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = RequestDenied.new()
		return __request_denied.value
	
	var __login_request: PBField
	func has_login_request() -> bool:
		if __login_request.value != null:
			return true
		return false
	func get_login_request() -> LoginRequest:
		return __login_request.value
	func clear_login_request() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_login_request() -> LoginRequest:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		data[8].state = PB_SERVICE_STATE.FILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = LoginRequest.new()
		return __login_request.value
	
	var __register_request: PBField
	func has_register_request() -> bool:
		if __register_request.value != null:
			return true
		return false
	func get_register_request() -> RegisterRequest:
		return __register_request.value
	func clear_register_request() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_register_request() -> RegisterRequest:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		data[9].state = PB_SERVICE_STATE.FILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = RegisterRequest.new()
		return __register_request.value
	
	var __login_success: PBField
	func has_login_success() -> bool:
		if __login_success.value != null:
			return true
		return false
	func get_login_success() -> LoginSuccess:
		return __login_success.value
	func clear_login_success() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_login_success() -> LoginSuccess:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		data[10].state = PB_SERVICE_STATE.FILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = LoginSuccess.new()
		return __login_success.value
	
	var __logout_request: PBField
	func has_logout_request() -> bool:
		if __logout_request.value != null:
			return true
		return false
	func get_logout_request() -> LogoutRequest:
		return __logout_request.value
	func clear_logout_request() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_logout_request() -> LogoutRequest:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		data[11].state = PB_SERVICE_STATE.FILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = LogoutRequest.new()
		return __logout_request.value
	
	var __client_entered: PBField
	func has_client_entered() -> bool:
		if __client_entered.value != null:
			return true
		return false
	func get_client_entered() -> ClientEntered:
		return __client_entered.value
	func clear_client_entered() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_client_entered() -> ClientEntered:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		data[12].state = PB_SERVICE_STATE.FILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = ClientEntered.new()
		return __client_entered.value
	
	var __client_left: PBField
	func has_client_left() -> bool:
		if __client_left.value != null:
			return true
		return false
	func get_client_left() -> ClientLeft:
		return __client_left.value
	func clear_client_left() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_client_left() -> ClientLeft:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		data[13].state = PB_SERVICE_STATE.FILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = ClientLeft.new()
		return __client_left.value
	
	var __join_region_request: PBField
	func has_join_region_request() -> bool:
		if __join_region_request.value != null:
			return true
		return false
	func get_join_region_request() -> JoinRegionRequest:
		return __join_region_request.value
	func clear_join_region_request() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_join_region_request() -> JoinRegionRequest:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		data[14].state = PB_SERVICE_STATE.FILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = JoinRegionRequest.new()
		return __join_region_request.value
	
	var __region_data: PBField
	func has_region_data() -> bool:
		if __region_data.value != null:
			return true
		return false
	func get_region_data() -> RegionData:
		return __region_data.value
	func clear_region_data() -> void:
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_region_data() -> RegionData:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		data[15].state = PB_SERVICE_STATE.FILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = RegionData.new()
		return __region_data.value
	
	var __spawn_character: PBField
	func has_spawn_character() -> bool:
		if __spawn_character.value != null:
			return true
		return false
	func get_spawn_character() -> SpawnCharacter:
		return __spawn_character.value
	func clear_spawn_character() -> void:
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_spawn_character() -> SpawnCharacter:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		data[16].state = PB_SERVICE_STATE.FILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = SpawnCharacter.new()
		return __spawn_character.value
	
	var __move_character: PBField
	func has_move_character() -> bool:
		if __move_character.value != null:
			return true
		return false
	func get_move_character() -> MoveCharacter:
		return __move_character.value
	func clear_move_character() -> void:
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_move_character() -> MoveCharacter:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		data[17].state = PB_SERVICE_STATE.FILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = MoveCharacter.new()
		return __move_character.value
	
	var __rotate_character: PBField
	func has_rotate_character() -> bool:
		if __rotate_character.value != null:
			return true
		return false
	func get_rotate_character() -> RotateCharacter:
		return __rotate_character.value
	func clear_rotate_character() -> void:
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_rotate_character() -> RotateCharacter:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		data[18].state = PB_SERVICE_STATE.FILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = RotateCharacter.new()
		return __rotate_character.value
	
	var __destination: PBField
	func has_destination() -> bool:
		if __destination.value != null:
			return true
		return false
	func get_destination() -> Destination:
		return __destination.value
	func clear_destination() -> void:
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_destination() -> Destination:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		data[19].state = PB_SERVICE_STATE.FILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = Destination.new()
		return __destination.value
	
	var __update_speed: PBField
	func has_update_speed() -> bool:
		if __update_speed.value != null:
			return true
		return false
	func get_update_speed() -> UpdateSpeed:
		return __update_speed.value
	func clear_update_speed() -> void:
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_update_speed() -> UpdateSpeed:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		data[20].state = PB_SERVICE_STATE.FILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = UpdateSpeed.new()
		return __update_speed.value
	
	var __chat_bubble: PBField
	func has_chat_bubble() -> bool:
		if __chat_bubble.value != null:
			return true
		return false
	func get_chat_bubble() -> ChatBubble:
		return __chat_bubble.value
	func clear_chat_bubble() -> void:
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_chat_bubble() -> ChatBubble:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		data[21].state = PB_SERVICE_STATE.FILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = ChatBubble.new()
		return __chat_bubble.value
	
	var __switch_weapon: PBField
	func has_switch_weapon() -> bool:
		if __switch_weapon.value != null:
			return true
		return false
	func get_switch_weapon() -> SwitchWeapon:
		return __switch_weapon.value
	func clear_switch_weapon() -> void:
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_switch_weapon() -> SwitchWeapon:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		data[22].state = PB_SERVICE_STATE.FILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = SwitchWeapon.new()
		return __switch_weapon.value
	
	var __reload_weapon: PBField
	func has_reload_weapon() -> bool:
		if __reload_weapon.value != null:
			return true
		return false
	func get_reload_weapon() -> ReloadWeapon:
		return __reload_weapon.value
	func clear_reload_weapon() -> void:
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_reload_weapon() -> ReloadWeapon:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		data[23].state = PB_SERVICE_STATE.FILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = ReloadWeapon.new()
		return __reload_weapon.value
	
	var __raise_weapon: PBField
	func has_raise_weapon() -> bool:
		if __raise_weapon.value != null:
			return true
		return false
	func get_raise_weapon() -> RaiseWeapon:
		return __raise_weapon.value
	func clear_raise_weapon() -> void:
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_raise_weapon() -> RaiseWeapon:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		data[24].state = PB_SERVICE_STATE.FILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = RaiseWeapon.new()
		return __raise_weapon.value
	
	var __lower_weapon: PBField
	func has_lower_weapon() -> bool:
		if __lower_weapon.value != null:
			return true
		return false
	func get_lower_weapon() -> LowerWeapon:
		return __lower_weapon.value
	func clear_lower_weapon() -> void:
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_lower_weapon() -> LowerWeapon:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		data[25].state = PB_SERVICE_STATE.FILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = LowerWeapon.new()
		return __lower_weapon.value
	
	var __fire_weapon: PBField
	func has_fire_weapon() -> bool:
		if __fire_weapon.value != null:
			return true
		return false
	func get_fire_weapon() -> FireWeapon:
		return __fire_weapon.value
	func clear_fire_weapon() -> void:
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_fire_weapon() -> FireWeapon:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		data[26].state = PB_SERVICE_STATE.FILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = FireWeapon.new()
		return __fire_weapon.value
	
	var __toggle_fire_mode: PBField
	func has_toggle_fire_mode() -> bool:
		if __toggle_fire_mode.value != null:
			return true
		return false
	func get_toggle_fire_mode() -> ToggleFireMode:
		return __toggle_fire_mode.value
	func clear_toggle_fire_mode() -> void:
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_toggle_fire_mode() -> ToggleFireMode:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		data[27].state = PB_SERVICE_STATE.FILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = ToggleFireMode.new()
		return __toggle_fire_mode.value
	
	var __start_firing_weapon: PBField
	func has_start_firing_weapon() -> bool:
		if __start_firing_weapon.value != null:
			return true
		return false
	func get_start_firing_weapon() -> StartFiringWeapon:
		return __start_firing_weapon.value
	func clear_start_firing_weapon() -> void:
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_start_firing_weapon() -> StartFiringWeapon:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		data[28].state = PB_SERVICE_STATE.FILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = StartFiringWeapon.new()
		return __start_firing_weapon.value
	
	var __stop_firing_weapon: PBField
	func has_stop_firing_weapon() -> bool:
		if __stop_firing_weapon.value != null:
			return true
		return false
	func get_stop_firing_weapon() -> StopFiringWeapon:
		return __stop_firing_weapon.value
	func clear_stop_firing_weapon() -> void:
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_stop_firing_weapon() -> StopFiringWeapon:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		data[29].state = PB_SERVICE_STATE.FILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = StopFiringWeapon.new()
		return __stop_firing_weapon.value
	
	var __report_player_damage: PBField
	func has_report_player_damage() -> bool:
		if __report_player_damage.value != null:
			return true
		return false
	func get_report_player_damage() -> ReportPlayerDamage:
		return __report_player_damage.value
	func clear_report_player_damage() -> void:
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_report_player_damage() -> ReportPlayerDamage:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		data[30].state = PB_SERVICE_STATE.FILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = ReportPlayerDamage.new()
		return __report_player_damage.value
	
	var __apply_player_damage: PBField
	func has_apply_player_damage() -> bool:
		if __apply_player_damage.value != null:
			return true
		return false
	func get_apply_player_damage() -> ApplyPlayerDamage:
		return __apply_player_damage.value
	func clear_apply_player_damage() -> void:
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_apply_player_damage() -> ApplyPlayerDamage:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		data[31].state = PB_SERVICE_STATE.FILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = ApplyPlayerDamage.new()
		return __apply_player_damage.value
	
	var __player_died: PBField
	func has_player_died() -> bool:
		if __player_died.value != null:
			return true
		return false
	func get_player_died() -> PlayerDied:
		return __player_died.value
	func clear_player_died() -> void:
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_player_died() -> PlayerDied:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		data[32].state = PB_SERVICE_STATE.FILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = PlayerDied.new()
		return __player_died.value
	
	var __respawn_request: PBField
	func has_respawn_request() -> bool:
		if __respawn_request.value != null:
			return true
		return false
	func get_respawn_request() -> RespawnRequest:
		return __respawn_request.value
	func clear_respawn_request() -> void:
		data[33].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_respawn_request() -> RespawnRequest:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		data[33].state = PB_SERVICE_STATE.FILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = RespawnRequest.new()
		return __respawn_request.value
	
	var __crouch_character: PBField
	func has_crouch_character() -> bool:
		if __crouch_character.value != null:
			return true
		return false
	func get_crouch_character() -> CrouchCharacter:
		return __crouch_character.value
	func clear_crouch_character() -> void:
		data[34].state = PB_SERVICE_STATE.UNFILLED
		__crouch_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_crouch_character() -> CrouchCharacter:
		__public_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__handshake.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__heartbeat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__server_metrics.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__request_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__request_denied.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__login_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		__logout_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		__client_entered.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		__client_left.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		__join_region_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		__region_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		__spawn_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		__move_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		__rotate_character.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		__destination.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		__update_speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		__chat_bubble.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		__switch_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		__reload_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		__raise_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		__lower_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		__fire_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		__toggle_fire_mode.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		__start_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		__stop_firing_weapon.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		__report_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		__apply_player_damage.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		__player_died.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		__respawn_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		data[34].state = PB_SERVICE_STATE.FILLED
		__crouch_character.value = CrouchCharacter.new()
		return __crouch_character.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################
