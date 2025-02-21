package main

import win32 "core:sys/windows"

Input :: struct {
	mouse_position : [2]f32,
	buttons_prev, buttons : [5]bool,
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
	}
}
// put this at the most bottom in the update function
input_process_post_update :: proc() {
	for btn, idx in input.buttons {
		input.buttons_prev[idx] = btn
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
