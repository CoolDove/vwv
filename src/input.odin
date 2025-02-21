package main

import win32 "core:sys/windows"

Input :: struct {
	mouse_position : [2]f32,
	buttons_prev, buttons : [5]bool,
	keys_prev, keys : [256]bool,
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
	case win32.WM_KEYDOWN:
		if msg.wparam < 256 do input.keys[msg.wparam] = true
	case win32.WM_KEYUP:
		if msg.wparam < 256 do input.keys[msg.wparam] = false
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
}

MouseButton :: enum {
	Left, Right, Middle,
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

	F1  = 0x70,
	F2  = 0x71,
	F3  = 0x72,
	F4  = 0x73,
	F5  = 0x74,
	F6  = 0x75,
	F7  = 0x76,
	F8  = 0x77,
	F9  = 0x78,
	F10 = 0x79,
	F11 = 0x7A,
	F12 = 0x7B,
}
