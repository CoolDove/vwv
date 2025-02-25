package main

import "core:math/linalg"
import "core:strings"
import "core:math"
import "core:log"
import "dgl"
import "tween"

VuiContext :: struct {
	hovering, active : int,
	delta_s : f64,
	states : map[u64]VuiState,
}

VuiState :: struct {
	_space : [64]u8,
}

@(private="file")
ctx : VuiContext

_vui_state :: proc(id: u64, $T: typeid) -> ^T {
	s, ok := &ctx.states[id] 
	if !ok {
		ctx.states[id] = {}
		s = &ctx.states[id]
	}
	return cast(^T)s
}

_vui_ctx :: proc() -> ^VuiContext {
	return &ctx
}

vui_init :: proc() {
	ctx.states = make(map[u64]VuiState)
}
vui_release :: proc() {
	delete(ctx.states)
}

vui_begin :: proc(delta_s: f64) {
	ctx.delta_s = delta_s
}
vui_end :: proc() {
	// do nothing now
}

vui_button :: proc(id: u64, rect: dgl.Rect, text: string) -> bool {
	state := _vui_state(id, struct { hover_time:f64, clicked_flash:f64 })
	hovering := false
	hovering = rect_in(rect, input.mouse_position)

	state.hover_time += ctx.delta_s if hovering else -ctx.delta_s
	state.hover_time = math.clamp(state.hover_time, 0, 0.2)

	clicked := hovering && is_button_pressed(.Left)
	if clicked {
		state.clicked_flash = 0.2
	} else {
		if state.clicked_flash > 0 {
			state.clicked_flash -= ctx.delta_s
		}
	}

	color_normal := dgl.col_u2f({195,75,75,   255})
	color_hover  := dgl.col_u2f({215,105,95,  255})
	color_flash  := dgl.col_u2f({245,235,235, 255})

	hovert :f32= cast(f32)(math.min(state.hover_time, 0.2)/0.2)
	hovert = tween.ease_inoutsine(hovert)
	color := hovert*(color_hover-color_normal) + color_normal
	if state.clicked_flash > 0 do color = cast(f32)(state.clicked_flash/0.2)*(color_flash-color) + color
	draw_rect(rect, dgl.col_f2u(color))

	text_color := dgl.col_u2f({218,218,218, 255})
	clickt := math.clamp(cast(f32)(state.clicked_flash/0.2), 0,1)
	if state.clicked_flash > 0 do text_color = clickt*(color_normal-color) + color
	draw_text(font_default, text, {rect.x, rect.y+rect.h*0.5-11-3*hovert-3*clickt}, 22, dgl.col_f2u(text_color))
	return clicked
}

vui_draggable_button :: proc(id: u64, rect: dgl.Rect, text: string) {
	state := _vui_state(id, struct {
		hover_time:f64,
		dragging:bool,
		// In dragging mode, this represents the offset from mouse pos to the anchor.
		// In nondragging mode, this is the current rect anchor.
		drag_offset:dgl.Vec2 
	})
	input_rect := rect
	rect := rect
	hovering := false
	if state.dragging {
		hovering = true
		rect.x = input.mouse_position.x-state.drag_offset.x
		rect.y = input.mouse_position.y-state.drag_offset.y

		if is_button_released(.Left) {
			if state.dragging {
				state.dragging = false
				state.drag_offset = {rect.x, rect.y}
			}
		}
	} else {
		if state.drag_offset != {} { // drag recovering
			topos := rect_position(input_rect)
			state.drag_offset = 40 * cast(f32)ctx.delta_s * (topos - state.drag_offset) + state.drag_offset
			if linalg.distance(topos, state.drag_offset) < 2 {
				state.drag_offset = {}
			} else {
				rect.x = state.drag_offset.x
				rect.y = state.drag_offset.y
			}
		}
		hovering = rect_in(rect, input.mouse_position)
		if hovering && is_button_pressed(.Left) {
			// start dragging
			state.dragging = true
			state.drag_offset = input.mouse_position - {rect.x, rect.y}
		}
	}

	state.hover_time += ctx.delta_s if hovering else -ctx.delta_s
	state.hover_time = math.clamp(state.hover_time, 0, 0.2)

	if is_button_released(.Left) {
		if state.dragging {
			state.dragging = false
			state.drag_offset = {rect.x, rect.y}
		}
	}

	color_normal := dgl.col_u2f({195,75,75,   255})
	color_hover  := dgl.col_u2f({215,105,95,  255})
	color_flash  := dgl.col_u2f({245,235,235, 255})

	hovert :f32= cast(f32)(math.min(state.hover_time, 0.2)/0.2)
	hovert = tween.ease_inoutsine(hovert)
	color := hovert*(color_hover-color_normal) + color_normal

	draw_rect(rect, dgl.col_f2u(color))
	text_color := dgl.col_u2f({218,218,218, 255})
	draw_text(font_default, text, {rect.x, rect.y+rect.h*0.5-11-3*hovert}, 22, dgl.col_f2u(text_color))
}
