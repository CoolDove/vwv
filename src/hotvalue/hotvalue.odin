package hotvalue

import "base:runtime"
import "core:os"
import "core:strconv"
import "core:log"
import "core:fmt"
import "core:strings"

HotValues :: struct {
	using _table : ^_Table,
	path : string,
	source : string,
	fixed : bool,
	pairs : map[string]Maybe(Value),
	keys : [dynamic]string,
	allocator : runtime.Allocator,
}

Value :: union {
	i64,
	f64,
	[2]f64,
	[2]i64,

	[3]f64,
	[3]i64,

	[4]f64,
	[4]i64,

	string,
}

_Table :: struct {
	f32 : proc(hotv: ^HotValues, key: string) -> f32,
	f64 : proc(hotv: ^HotValues, key: string) -> f64,

	u8  : proc(hotv: ^HotValues, key: string) -> u8,
	i32 : proc(hotv: ^HotValues, key: string) -> i32,
	i64 : proc(hotv: ^HotValues, key: string) -> i64,
}

@private
_table :_Table= {
	f64 = proc(hotv: ^HotValues, key: string) -> f64 {
		value := getvalue(hotv, key)
		if value == nil do return 0
		#partial switch v in value.(Value) {
		case f64: return v
		case i64: return auto_cast v
		}
		return 0
	},
	f32 = proc(hotv: ^HotValues, key: string) -> f32 {
		return cast(f32)hotv->f64(key)
	},
	i64 = proc(hotv: ^HotValues, key: string) -> i64 {
		value := getvalue(hotv, key)
		if value == nil do return 0
		#partial switch v in value.(Value) {
		case f64: return auto_cast v
		case i64: return auto_cast v
		}
		return 0
	},
	i32 = proc(hotv: ^HotValues, key: string) -> i32 {
		return cast(i32)hotv->i64(key)
	},
	u8  = proc(hotv: ^HotValues, key: string) -> u8 {
		return cast(u8)hotv->i64(key)
	},
}

init :: proc(path: string, allocator:= context.allocator) -> HotValues {
	context.allocator = allocator
	hotv : HotValues
	hotv._table = &_table
	hotv.path = path
	hotv.pairs = make(map[string]Maybe(Value), allocator)
	hotv.keys = make([dynamic]string)
	hotv.allocator = context.allocator
	_read_file(&hotv)
	_parse(&hotv)
	return hotv
}

release :: proc(hotv: ^HotValues) {
	context.allocator = hotv.allocator
	if hotv.source != "" do delete(hotv.source)
	delete(hotv.pairs)
	for k in hotv.keys do delete(k)
	delete(hotv.keys)
	hotv^ = {}
}

update :: proc(hotv: ^HotValues) {
	context.allocator = hotv.allocator
	_read_file(hotv)
	_parse(hotv)
}

getvalue :: proc(hotv: ^HotValues, key: string) -> Maybe(Value) {
	if v, ok := hotv.pairs[key]; ok {
		return v
	} else {
		_insert(hotv, key, nil)
		// _write_back(hotv)
		return nil
	}
}

@private
_insert :: proc(hotv: ^HotValues, key: string, value: Maybe(Value)) {
	context.allocator = hotv.allocator
	key := strings.clone(key)
	append(&hotv.keys, key)
	map_insert(&hotv.pairs, key, value)
}

@private
_read_file :: proc(hotv: ^HotValues) {
	if hotv.source != "" {
		delete(hotv.source)
		hotv.source = ""
	}
	if !os.exists(hotv.path) {
		os.write_entire_file(hotv.path, {})
	}
	data, ok := os.read_entire_file(hotv.path)
	if ok do hotv.source = cast(string)data
	clear(&hotv.pairs)
	for k in hotv.keys do delete(k)
	clear(&hotv.keys)
}
// @private // TODO: get a better way
// _write_back :: proc(hotv: ^HotValues) {
// 	sb : strings.Builder
// 	strings.builder_init(&sb, context.temp_allocator)
// 	defer strings.builder_destroy(&sb)
// 	for key in hotv.keys {
// 		value := hotv.pairs[key]
// 		strings.write_string(&sb, key)
// 		if value != nil {
// 			strings.write_rune(&sb, ' ')
// 			strings.write_string(&sb, fmt.tprintf("{}", value))
// 		}
// 		strings.write_rune(&sb, '\n')
// 	}
// 	os.write_entire_file(hotv.path, transmute([]u8)strings.to_string(sb))
// }

@private
_parse :: proc(hotv: ^HotValues) {
	src := hotv.source
	for line in strings.split_lines_iterator(&src) {
		l := line
		_remove_white_space(&l)
		key := _parse_key(&l)
		_remove_white_space(&l)
		value := _parse_value(&l)
		_remove_white_space(&l)
		if key == "" do continue
		_insert(hotv, key, value)
	}
}

@private
_parse_key :: proc(src: ^string) -> string {
	for b, i in src {
		if b != '\t' && b != ' ' do continue
		result := src[:i]
		src^ = src[i:]
		return result
	}
	result := src^
	src^ = ""
	return result
}
@private
_parse_value :: proc(src: ^string) -> Maybe(Value) {
	value : Value
	ok : bool
	if value, ok = _parse_value_f64(src); ok {
		return value
	} else if value, ok = _parse_value_i64(src); ok {
		return value
	}
	return nil
}
@private
_parse_value_f64 :: proc(src: ^string) -> (value: f64, ok: bool) {
	n : int
	value, ok = strconv.parse_f64(src^, &n)
	if ok do src^ = src[n:]
	return
}
@private
_parse_value_i64 :: proc(src: ^string) -> (value: i64, ok: bool) {
	n : int
	value, ok = strconv.parse_i64(src^, &n)
	if ok do src^ = src[n:]
	return
}

@private
_remove_white_space :: proc(src: ^string) {
	for b, i in src {
		if b == '\n' || b == '\t' || b == ' ' do continue
		src^ = src[i:]
		return
	}
}
