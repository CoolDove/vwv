package main

import "core:math/linalg"
import "core:strings"
import "dgl"

VuiState :: struct {
}

vui_button :: proc(rect: dgl.Rect, text: string) -> bool {
	hovering := false
	hovering = rect_in(rect, input.mouse_position)
	draw_rect(rect, {235,115,105, 255} if hovering else {215,95,95, 255})
	draw_text(font_default, text, {rect.x, rect.y+rect.h*0.5-11}, 22, {218,218,218, 255})
	return hovering && is_button_pressed(.Left)
}
