package main

import "base:runtime"
import "core:strings"
import "core:unicode/utf8"
import "core:mem"
import "core:fmt"

TextEdit :: struct {
	buffer : ^GapBuffer,
	selection : [2]TextCursor,// begin, end
}

TextCursor :: int

textedit_begin :: proc(ed: ^TextEdit, buffer: ^GapBuffer, cursor:TextCursor= 0) {
	ed.buffer = buffer
	ed.selection = {cursor,cursor}
}
textedit_end :: proc(ed: ^TextEdit) {
	ed.buffer = nil
	ed.selection = {}
}

textedit_move :: proc(using ed: ^TextEdit, offset: int) {// bytes
	selection.y = selection.x
	to := clamp(selection.x + offset, 0, gapbuffer_len(buffer))
	selection = {to, to}
}
textedit_move_to :: proc(using ed: ^TextEdit, to: int) {// bytes
	if to < 0 || to > gapbuffer_len(ed.buffer) do return
	selection = {to, to}
}

textedit_insert :: proc(using ed: ^TextEdit, str: string) {
	gapbuffer_insert_string(ed.buffer, selection.x, str)
	selection.x += len(str)
	selection.y = selection.x
}

textedit_remove :: proc(using ed: ^TextEdit, offset: int) {// bytes
	selection.y = selection.x
	length := gapbuffer_len(ed.buffer)
	offset := offset
	if offset > 0 do offset = min(length-selection.x, offset)
	else if offset < 0 do offset = -min(selection.x, abs(offset))
	if offset == 0 do return
	gapbuffer_remove_bytes(ed.buffer, selection.x, offset)
	if offset < 0 do selection = {selection.x + offset, selection.x + offset}
}

textedit_find_previous_rune :: proc(using ed: ^TextEdit, cursor: int) -> (rune, int) {
	cursor := cursor-1
	r, size := gapbuffer_get_previous_rune(ed.buffer, cursor)
	if size == 0 do return utf8.RUNE_ERROR, -1
	return r, cursor+1-size
}
textedit_find_next_rune :: proc(using ed: ^TextEdit, cursor: int) -> (rune, int) {
	r, size := gapbuffer_get_current_rune(ed.buffer, cursor)
	if size == 0 do return utf8.RUNE_ERROR, -1
	return r, cursor+size
}
textedit_find_previous_word_head :: proc(using ed: ^TextEdit, cursor: int) -> int {
	cursor := cursor
	mode := 0
	for true {
		if r, pos := textedit_find_previous_rune(ed, cursor); pos > 0 {
			is_sp := strings.is_separator(r)
			
			if mode == 0 {
				mode = -1 if is_sp else 1
				cursor = pos
			} else {
				if (mode == -1 && !is_sp) || (mode == 1 && is_sp) {
					return cursor
				} 
				cursor = pos
			}
		} else {
			return 0
		}
	}
	return 0
}
textedit_find_next_word_head :: proc(using ed: ^TextEdit, cursor: int) -> int {
	cursor := cursor
	is_splitter :: proc(r: rune) -> bool {
		return r == ',' || r == '_' || r == ' ' || r == '\t' || r == '\n' || r == '\''
	}
	mode := 0
	for true {
		if r, pos := textedit_find_next_rune(ed, cursor); pos > 0 {
			is_sp := strings.is_separator(r)
			
			if mode == 0 {
				mode = -1 if is_sp else 1
				cursor = pos
			} else {
				if (mode == -1 && !is_sp) || (mode == 1 && is_sp) {
					return cursor
				} 
				cursor = pos
			}
		} else {
			return gapbuffer_len(ed.buffer)
		}
	}
	return gapbuffer_len(ed.buffer)
}

// ** gap buffer

// Modified from: [https://github.com/jon-lipstate/pico/blob/master/gap_buffer/gap_buffer.odin]

GapBuffer :: struct {
	buf : []u8,
	gap_begin, gap_end : TextCursor,
	allocator: runtime.Allocator,
}

BufferPosition :: int

gapbuffer_init :: proc(b: ^GapBuffer, gap: int, allocator:=context.allocator) {
	context.allocator = allocator
	b.allocator = allocator
	b.buf = make([]u8, gap)
	b.gap_end = gap
}
gapbuffer_release :: proc(b: ^GapBuffer) {
	delete(b.buf)
}

gapbuffer_len :: proc(b: ^GapBuffer) -> int {
	gap := b.gap_end - b.gap_begin
	return len(b.buf) - gap
}
gapbuffer_len_gap :: #force_inline proc(b: ^GapBuffer) -> int {
	return b.gap_end - b.gap_begin
}
gapbuffer_len_buffer :: #force_inline proc(b: ^GapBuffer) -> int {
	return len(b.buf)
}

// Gets strings that point into the left and right sides of the gap. Note that this is neither thread, or even operation safe.
// Strings need to be immediately cloned or operated on prior to editing the buffer again.
gapbuffer_get_strings :: proc(b: ^GapBuffer) -> (left: string, right: string) {
	left = string(b.buf[:b.gap_begin])
	right = string(b.buf[b.gap_end:])
	return
}
gapbuffer_get_left :: #force_inline proc(b: ^GapBuffer) -> string {
    if b.gap_begin == 0 do return ""
	return string(b.buf[:b.gap_begin])
}
gapbuffer_get_right :: #force_inline proc(b: ^GapBuffer) -> string {
    if b.gap_end > gapbuffer_len_buffer(b)-1 do return ""
	return string(b.buf[b.gap_end:])
}
gapbuffer_get_string :: proc(b: ^GapBuffer, allocator:= context.allocator) -> string {
    context.allocator = allocator
    left, right := gapbuffer_get_strings(b)
    using strings
    sb : Builder
    builder_init_len_cap(&sb, 0, len(left)+len(right))
    write_string(&sb, left)
    write_string(&sb, right)
    return to_string(sb)
}

gapbuffer_get_byte :: proc(using b: ^GapBuffer, point: BufferPosition) -> (byte, bool) #optional_ok {
	if point < 0 || point >= gapbuffer_len(b) do return 0,false
	if point < gap_begin {
		return buf[point], true
	} else {
		return buf[point+gapbuffer_len_gap(b)], true
	}
}

// Look backwards to find a rune. Return the rune and its length in bytes. -1 indicates a bad rune at
//	the point.
gapbuffer_get_current_rune :: proc(b: ^GapBuffer, point: BufferPosition) -> (rune, int) {
	if point < 0 || point >= gapbuffer_len(b) do return utf8.RUNE_ERROR, 0
	bytes : [4]u8
	length : int
	for i in 0..<min(4, gapbuffer_len(b)-point) {
		bytes[i] = gapbuffer_get_byte(b, point+i)
		length = i+1
	}
	return utf8.decode_rune_in_bytes(bytes[:length])
}
gapbuffer_get_previous_rune :: proc(b: ^GapBuffer, point: BufferPosition) -> (rune, int) {
	if point < 0 || point >= gapbuffer_len(b) do return utf8.RUNE_ERROR, 0
	bytes : [4]u8
	length :int= min(4, point+1)
	for i in 0..<length {
		bytes[3-i] = gapbuffer_get_byte(b, point-i)
	}
	return utf8.decode_last_rune_in_bytes(bytes[4-length:])
}

// Cursors are clamped [0,n) where n is the filled count of the buffer.
gapbuffer_shift_gap :: proc(b: ^GapBuffer, to: BufferPosition) {
	gap_len := b.gap_end - b.gap_begin
	to := clamp(to, 0, len(b.buf) - gap_len)
	if to == b.gap_begin {return}

	if b.gap_begin < to {
		// Gap is before the to:
		//   v~~~~v
		//[12]           [3456789abc]
		//--------|------------------ Gap is BEFORE to
		//[123456]           [789abc]
		delta := to - b.gap_begin
		mem.copy(&b.buf[b.gap_begin], &b.buf[b.gap_end], delta)
		b.gap_begin += delta
		b.gap_end += delta
	} else if b.gap_begin > to {
		// Gap is after the to
		//   v~~~v
		//[123456]           [789abc]
		//---|----------------------- Gap is AFTER to
		//[12]           [3456789abc]
		delta := b.gap_begin - to
		mem.copy(&b.buf[b.gap_end - delta], &b.buf[b.gap_begin - delta], delta)
		b.gap_begin -= delta
		b.gap_end -= delta
	}
}
// Verifies the buffer can hold the needed write. Resizes the array if not. By default doubles array size.
gapbuffer_require_gap :: proc(b: ^GapBuffer, required: int) {
	gap_len := b.gap_end - b.gap_begin
	if gap_len < required {
		gapbuffer_shift_gap(b, len(b.buf) - gap_len)
		req_buf_size := required + len(b.buf) - gap_len
		new_buf := make([]u8, 2 * req_buf_size, b.allocator)
		copy_slice(new_buf, b.buf[:b.gap_end])
		delete(b.buf)
		b.buf = new_buf
		b.gap_end = len(b.buf)
		// fmt.printf("gapbuffer resized to {}\n", len(b.buf))
	}
}
// Moves the gap to the cursor, then moves the gap pointer beyond count, effectively deleting it.  
// Note: Do not rely on the gap being 0, remove will leave as-is values behind in the gap  
// WARNING: Does not protect for unicode at present, simply deletes bytes
gapbuffer_remove_bytes :: proc(b: ^GapBuffer, cursor: BufferPosition, count: int) {
	del := abs(count)
	eff_cursor := cursor
	if count < 0 {eff_cursor = max(0, eff_cursor - del)}
	gapbuffer_shift_gap(b, eff_cursor)
	b.gap_end = min(b.gap_end + del, len(b.buf))
}

gapbuffer_clear :: proc(b: ^GapBuffer) {
	b.gap_begin = 0
	b.gap_end = len(b.buf)
}

gapbuffer_insert_byte :: proc(b: ^GapBuffer, cursor: BufferPosition, char: u8) {
	gapbuffer_require_gap(b, 1)
	gapbuffer_shift_gap(b, cursor)
	b.buf[b.gap_begin] = char
	b.gap_begin += 1
}
gapbuffer_insert_bytes :: proc(b: ^GapBuffer, cursor: BufferPosition, bytes: []u8) {
	gapbuffer_require_gap(b, len(bytes))
	gapbuffer_shift_gap(b, cursor)
	copy_slice(b.buf[b.gap_begin:b.gap_end], bytes)
	b.gap_begin += len(bytes)
}

gapbuffer_insert_rune :: proc(b: ^GapBuffer, cursor: BufferPosition, r: rune) {
	bytes, length := utf8.encode_rune(r)
	gapbuffer_insert_bytes(b, cursor, bytes[:length])
}
gapbuffer_insert_string :: #force_inline proc(b: ^GapBuffer, cursor: BufferPosition, str: string) {
	gapbuffer_insert_bytes(b, cursor, transmute([]u8)str)
}
