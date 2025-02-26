package main

import "core:log"
import "core:strings"
import "core:unicode/utf8"
import "core:mem"
import win32 "core:sys/windows"

Input :: struct {
	mouse_position : [2]f32,
	buttons_prev, buttons : [5]bool,
	keys_prev, keys : [256]bool,
	wheel_delta : f32,


	// text input stuff
	ime_text_buffer_raw : [128]u16,
	ime_text_buffer : [128]u8,
	ime_composed : string,

	text_input_on : bool,
	_input_text_buffer : [128]rune,
	_handled_input_text : []rune,
}

input : Input

Win32Msg :: struct {
	hwnd: win32.HWND,
	msg: win32.UINT,
	wparam: win32.WPARAM,
	lparam: win32.LPARAM,
}

// put in the win32 wndproc before any other one taking the msg
input_process_win32_wndproc :: proc(msg: Win32Msg) {
	switch(msg.msg) {
	case win32.WM_MOUSEMOVE:
		x := cast(f32)transmute(i16)win32.LOWORD(msg.lparam);
		y := cast(f32)transmute(i16)win32.HIWORD(msg.lparam);
		input.mouse_position = {x,y}
	case win32.WM_LBUTTONDOWN:
		input.buttons[MouseButton.Left] = true
	case win32.WM_LBUTTONUP:
		input.buttons[MouseButton.Left] = false
	case win32.WM_RBUTTONDOWN:
		input.buttons[MouseButton.Right] = true
	case win32.WM_RBUTTONUP:
		input.buttons[MouseButton.Right] = false
	case win32.WM_MOUSEWHEEL:
		input.wheel_delta = cast(f32)win32.GET_WHEEL_DELTA_WPARAM(msg.wparam)/cast(f32)win32.WHEEL_DELTA
	case win32.WM_KEYDOWN:
		if msg.wparam < 256 do input.keys[msg.wparam] = true
	case win32.WM_KEYUP:
		if msg.wparam < 256 do input.keys[msg.wparam] = false
	case win32.WM_CHAR:
		r := cast(rune)msg.wparam
		if input.text_input_on && r > 31 {
			length := len(input._handled_input_text)
			input._input_text_buffer[length] = r
			input._handled_input_text = input._input_text_buffer[:length+1]
		}
	case win32.WM_IME_COMPOSITION: // used to handle compositing text
		// if (msg.lparam & GCS_RESULTSTR) > 0 {
		// 	buffer := input.ime_text_buffer_raw
		// 	himc := ImmGetContext(hwnd); defer ImmReleaseContext(hwnd, himc)
		// 	size := ImmGetCompositionStringW(himc, GCS_RESULTSTR, nil, 0)
		// 	ImmGetCompositionStringW(himc, GCS_RESULTSTR, raw_data(buffer[:]), auto_cast size)
		// 	coded, _ := win32.utf16_to_utf8(buffer[:size], context.temp_allocator)
		// 	mem.copy(raw_data(input.ime_text_buffer[:]), raw_data(coded), len(coded))
		// 	input.ime_composed = cast(string)input.ime_text_buffer[:len(coded)]
		// 	log.debugf("composed: {}", input.ime_composed)
		// }
	}
}
// put this at the most bottom in the update function
input_process_post_update :: proc() {
	for btn, idx in input.buttons {
		input.buttons_prev[idx] = btn
	}
	for key, idx in input.keys {
		input.keys_prev[idx] = key
	}
	input.wheel_delta = 0
}

MouseButton :: enum {
	Left, Right, Middle,
}

get_input_text :: proc(allocator:= context.allocator) -> string {
	context.allocator = allocator
	defer input._handled_input_text = {}
	return utf8.runes_to_string(input._handled_input_text)
}
toggle_text_input :: proc(on: bool) {
	input.text_input_on = on
	if on {
		input._handled_input_text = {}
	}
}

is_button_down :: proc(btn: MouseButton) -> bool {
	return input.buttons[btn]
}
is_button_up :: proc(btn: MouseButton) -> bool {
	return !input.buttons[btn]
}
is_button_released :: proc(btn: MouseButton) -> bool {
	return input.buttons_prev[btn] && !input.buttons[btn]
}
is_button_pressed :: proc(btn: MouseButton) -> bool {
	return !input.buttons_prev[btn] && input.buttons[btn]
}

is_key_down :: proc(key: KeyboardKey) -> bool {
	return input.keys[key]
}
is_key_up :: proc(key: KeyboardKey) -> bool {
	return !input.keys[key]
}
is_key_released :: proc(key: KeyboardKey) -> bool {
	return input.keys_prev[key] && !input.keys[key]
}
is_key_pressed :: proc(key: KeyboardKey) -> bool {
	return !input.keys_prev[key] && input.keys[key]
}

KeyboardKey :: enum(u8) {
	A   = 'A',
	B   = 'B',
	C   = 'C',
	D   = 'D',
	E   = 'E',
	F   = 'F',
	G   = 'G',
	H   = 'H',
	I   = 'I',
	J   = 'J',
	K   = 'K',
	L   = 'L',
	M   = 'M',
	N   = 'N',
	O   = 'O',
	P   = 'P',
	Q   = 'Q',
	R   = 'R',
	S   = 'S',
	T   = 'T',
	U   = 'U',
	V   = 'V',
	W   = 'W',
	X   = 'X',
	Y   = 'Y',
	Z   = 'Z',

	F1  = win32.VK_F1,
	F2  = win32.VK_F2,
	F3  = win32.VK_F3,
	F4  = win32.VK_F4,
	F5  = win32.VK_F5,
	F6  = win32.VK_F6,
	F7  = win32.VK_F7,
	F8  = win32.VK_F8,
	F9  = win32.VK_F9,
	F10 = win32.VK_F10,
	F11 = win32.VK_F11,
	F12 = win32.VK_F12,

	Delete = win32.VK_DELETE,
	Back   = win32.VK_BACK,
	Tab    = win32.VK_TAB,
	Enter  = win32.VK_RETURN,
	Escape = win32.VK_ESCAPE,

	End    = win32.VK_END,
	Home   = win32.VK_HOME,

	Left   = win32.VK_LEFT,
	Up     = win32.VK_UP,
	Right  = win32.VK_RIGHT,
	Down   = win32.VK_DOWN,
}

// IMM32 binding
foreign import imm32 "system:Imm32.lib"

HIMC :: win32.DWORD

@(default_calling_convention="system")
foreign imm32 {
	ImmGetCompositionStringW :: proc(unnamedParam1: HIMC, unnamedParam2: win32.DWORD, lpBuf: win32.LPVOID, dwBufLen: win32.DWORD,) -> win32.LONG ---
	ImmGetContext :: proc(unnamedParam1: win32.HWND) -> HIMC ---
	ImmReleaseContext :: proc(unnamedParam1: win32.HWND, unnamedParam2: HIMC) -> win32.BOOL ---
}

// parameter of ImmGetCompositionString
GCS_COMPREADSTR :: 0x0001
GCS_COMPREADATTR :: 0x0002
GCS_COMPREADCLAUSE :: 0x0004
GCS_COMPSTR :: 0x0008
GCS_COMPATTR :: 0x0010
GCS_COMPCLAUSE :: 0x0020
GCS_CURSORPOS :: 0x0080
GCS_DELTASTART :: 0x0100
GCS_RESULTREADSTR :: 0x0200
GCS_RESULTREADCLAUSE :: 0x0400
GCS_RESULTSTR :: 0x0800
GCS_RESULTCLAUSE :: 0x1000

// style bit flags for WM_IME_COMPOSITION
CS_INSERTCHAR :: 0x2000
CS_NOMOVECARET :: 0x4000
