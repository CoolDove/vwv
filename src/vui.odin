package main

import "core:math/linalg"
import "core:strings"
import "core:math"
import "core:log"
import "dgl"
import "tween"
import hla "collections/hollow_array"

Color :: dgl.Color4u8
Rect :: dgl.Rect
Vec2 :: dgl.Vec2

VuiContext :: struct {
	hot, active : u64,
	delta_s : f64,
	current_layout : ^VuiLayout,
	// states : map[u64]VuiState,
	states : map[u64]hla.HollowArrayHandle(VuiWidget),
	_state_pool : hla.HollowArray(VuiWidget),

	widget_stack : [dynamic]u64,

	_temp_tbro : TextBro,
}

VuiLayout :: struct {
	// Set these functions if you want to create a custom layout type.
	_push : proc(layout: ^VuiLayout, width, height: f32, process : VuiLayoutElemProcessor, data: rawptr), // called when layout_push
	_process : proc(layout: ^VuiLayout), // called before drawing in layout_end

	rect : Rect,
	next : Vec2,
	elems : [dynamic]VuiLayoutElem,
}


VuiLayoutElemProcessor :: #type proc(rect: Rect, data: rawptr)

VuiLayoutElem :: struct {
	process : VuiLayoutElemProcessor,
	rect : Rect,
	data : rawptr,
}


VuiState :: VuiWidget

@(private="file")
ctx : VuiContext

@(private="file")
_builtin_layout_vertical : VuiLayout={
	_push = proc(layout: ^VuiLayout, width, height: f32, process : VuiLayoutElemProcessor, data: rawptr) {
		rect :Rect= {layout.next.x, layout.next.y, width, height}
		append(&layout.elems, VuiLayoutElem{ process, rect, data })
		layout.next.y += height
	},
	_process = proc(layout: ^VuiLayout) {
		// TODO:
	},
}

_vui_state :: proc(id: u64) -> ^VuiWidget {
	s, ok := ctx.states[id] 
	if !ok {
		ctx.states[id] = hla.hla_append(&ctx._state_pool, VuiWidget{})
		s = ctx.states[id]
	}
	return hla.hla_get_pointer(s)
}
// _vui_state :: proc(id: u64, $T: typeid) -> ^T {
// 	s, ok := &ctx.states[id] 
// 	if !ok {
// 		ctx.states[id] = hla.hla_append(&ctx._state_pool, VuiWidget{})
// 		s = &ctx.states[id]
// 	}
// 	return cast(^T)s
// }

_vui_ctx :: proc() -> ^VuiContext {
	return &ctx
}

vui_init :: proc() {
	ctx._state_pool = hla.hla_make(VuiWidget, 256)
	ctx.states = make(map[u64]hla.HollowArrayHandle(VuiWidget))
	tbro_init(&ctx._temp_tbro, font_default, 28)
	ctx.widget_stack = make([dynamic]u64, 16)
}
vui_release :: proc() {
	tbro_release(&ctx._temp_tbro)
	delete(ctx.states)
	delete(ctx.widget_stack)
	hla.hla_delete(&ctx._state_pool)
}

vui_begin :: proc(delta_s: f64, rect: Rect) {
	ctx.delta_s = delta_s
	ctx.hot = 0
	clear(&ctx.widget_stack)
	_vuibd_begin(1, rect)
}
vui_end :: proc() {
	_vuibd_end()
}

VuiWidget :: struct {
	basic : VuiWidget_Basic,

	clickable : VuiWidget_Clickable,

	draw_rect : VuiWidget_DrawRect,
	draw_text : VuiWidget_DrawText,
	draw_custom : VuiWidget_DrawCustom,

	layout : VuiWidget_LayoutContainer,
}

VuiWidget_Basic :: struct {
	id : u64,
	rect : Rect,

	widget_draw : proc(id: u64, interact: VuiInteract),
	children : [dynamic]u64,
	interact : VuiInteract,
}
VuiWidget_Clickable :: struct {
	enable : bool,
}
VuiWidget_DrawRect :: struct {
	enable : bool,
	color : Color,
	round : f64,
	round_segment : int,
}
VuiWidget_DrawText :: struct {
	enable : bool,
	size : f64,
	text : string,
	color : Color,
}
VuiWidget_DrawCustom :: struct {
	enable : bool,
	drawer : proc(state: ^VuiWidget, data: rawptr),
	data : rawptr,
}

VuiWidget_LayoutContainer :: struct {
	enable : bool,
	direction : VuiLayoutDirection,
	next : Vec2,
	padding : f64,
}
VuiLayoutDirection :: enum {
	Vertical, Horizontal
}

VuiInteract :: struct {
	clicked : bool,
	_require_size : Vec2,
}

@(private="file")
_peek_state :: #force_inline proc() -> ^VuiWidget {
	if len(ctx.widget_stack) == 0 do return nil
	return _vui_state(ctx.widget_stack[len(ctx.widget_stack)-1])
}

_vuibd_begin :: proc(id: u64, rect: Rect) {
	state := _vui_state(id)
	state.basic = {
		id   = id,
		rect = rect,
		children = make([dynamic]u64),
	}
	state.clickable.enable = false
	state.draw_rect.enable = false
	state.draw_text.enable = false
	state.draw_custom.enable = false
	state.layout.enable = false
	append(&ctx.widget_stack, id)
}
_vuibd_end :: proc() -> VuiInteract {
	state := _vui_state(pop(&ctx.widget_stack))
	defer delete(state.basic.children)
	return _vui_widget(state)
}
_vuibd_draw_rect :: proc(color: Color) {
	state := _peek_state()
	state.draw_rect.enable = true
	state.draw_rect.color = color
}
_vuibd_draw_text :: proc(color: Color, text: string, size: f64) {
	state := _peek_state()
	draw := &state.draw_text
	draw.enable = true
	draw.color = color
	draw.size = size
	draw.text = text
}
_vuibd_clickable :: proc() {
	state := _peek_state()
	state.clickable.enable = true
}

_vuibd_layout :: proc(direction: VuiLayoutDirection) -> ^VuiWidget_LayoutContainer {
	state := _peek_state()
	layout := &state.layout
	layout.enable = true
	layout.direction = direction
	layout.next = {state.basic.rect.x, state.basic.rect.y}
	return layout
}

vui_test_button :: proc(id: u64, rect: Rect) -> VuiInteract {
	_vuibd_begin(id, rect)
	_vuibd_draw_rect(dgl.RED)
	_vuibd_clickable()
	_vuibd_draw_text(dgl.WHITE, "Hello", 20)
	return _vuibd_end()
}

vui_layout_begin :: proc(id: u64, rect: Rect, direction: VuiLayoutDirection, padding: f64) {
	_vuibd_begin(id, rect)
	_vuibd_draw_rect({0,0,0, 128})
	_vuibd_layout(direction).padding = padding
}
vui_layout_end :: proc() {
	_vuibd_end()
}

_vui_widget :: proc(state: ^VuiWidget) -> VuiInteract {
	using state.basic

	if parent := _peek_state(); parent != nil {
		append(&parent.basic.children, id)

		if layout:= &parent.layout; layout.enable {
			switch layout.direction {
			case .Vertical:
				rect.x = layout.next.x
				rect.y = layout.next.y
				layout.next.y += rect.h + cast(f32)layout.padding
			case .Horizontal:
				rect.x = layout.next.x
				rect.y = layout.next.y
				layout.next.x += rect.w + cast(f32)layout.padding
			}
		}
	}

	if state.clickable.enable {
		inrect := rect_in(state.basic.rect, input.mouse_position)
		if inrect {
			if ctx.active == 0 && ctx.hot == 0 {
				ctx.hot = id
				if is_button_pressed(.Left) {
					ctx.active = id
				}
			}
		}
		if is_button_released(.Left) && ctx.active == id {
			if inrect {
				interact.clicked = true
			}
			ctx.active = 0
		}
	}

	state.basic.widget_draw = proc(id: u64, interact: VuiInteract) {
		state := _vui_state(id)
		log.debugf("draw: {}", id)
		using state.basic
		if state.draw_rect.enable {
			using state.draw_rect
			draw_rect(rect, color)
		}
		if state.draw_text.enable {
			using state.draw_text
			tbro := &ctx._temp_tbro
			tbro_reset(tbro, font_default, size, -1)
			tbro_write_string(tbro, text, color)
			width := tbro_last(tbro).next.x
			x := 0.5*(rect.w-width) + rect.x
			y := 0.5*(rect.h-auto_cast size-4) + rect.y
			for e in tbro.elems {
				d := e.quad_dst
				draw_texture_ex(fsctx.atlas, e.quad_src, {d.x+x, d.y+y, d.w, d.h}, {0,0}, 0, e.color)
			}
		}

		for c in children {
			cstate := _vui_state(c)
			cstate.basic.widget_draw(c, cstate.basic.interact)
		}
	}
	if parent := _peek_state(); parent == nil {
		widget_draw(id, interact)
	}

	return interact
}

vui_begin_layoutv :: proc(rect: Rect) {
	vui_begin_layout(&_builtin_layout_vertical, rect)
}

vui_begin_layout :: proc(layout: ^VuiLayout, rect: Rect) {
	assert(_vui_get_layout() == nil)
	layout.rect = rect
	layout.next = {rect.x, rect.y}
	ctx.current_layout = layout
	layout.elems = make([dynamic]VuiLayoutElem)
}
vui_end_layout :: proc() {
	layout := _vui_get_layout()
	assert(layout != nil)

	for e in layout.elems {
		if e.process == nil do continue
		e.process(e.rect, e.data)
	}

	delete(layout.elems)
	ctx.current_layout = nil
}

_vui_get_layout :: proc() -> ^VuiLayout {
	return ctx.current_layout
}

_vui_layout_push :: proc(width, height: f32, process : proc(rect: Rect, data: rawptr), data: rawptr=nil) {
	layout := _vui_get_layout()
	if layout == nil do return
	layout->_push(width, height, process, data)
}

// ... as examples ...

// vui_button :: proc(id: u64, rect: Rect, text: string) -> bool {
// 	state := _vui_state(id, struct { hover_time:f64, clicked_flash:f64 })
// 	hovering := false
// 	hovering = rect_in(rect, input.mouse_position)
// 
// 	state.hover_time += ctx.delta_s if hovering else -ctx.delta_s
// 	state.hover_time = math.clamp(state.hover_time, 0, 0.2)
// 
// 	clicked := hovering && is_button_pressed(.Left)
// 	if clicked {
// 		state.clicked_flash = 0.2
// 	} else {
// 		if state.clicked_flash > 0 {
// 			state.clicked_flash -= ctx.delta_s
// 		}
// 	}
// 
// 	color_normal := dgl.col_u2f({195,75,75,   255})
// 	color_hover  := dgl.col_u2f({215,105,95,  255})
// 	color_flash  := dgl.col_u2f({245,235,235, 255})
// 
// 	hovert :f32= cast(f32)(math.min(state.hover_time, 0.2)/0.2)
// 	hovert = tween.ease_inoutsine(hovert)
// 	color := hovert*(color_hover-color_normal) + color_normal
// 	if state.clicked_flash > 0 do color = cast(f32)(state.clicked_flash/0.2)*(color_flash-color) + color
// 	draw_rect_rounded(rect, 8+hovert*4, 4, dgl.col_f2u(color))
// 
// 	text_color := dgl.col_u2f({218,218,218, 255})
// 	clickt := math.clamp(cast(f32)(state.clicked_flash/0.2), 0,1)
// 	if state.clicked_flash > 0 do text_color = clickt*(color_normal-color) + color
// 	draw_text(font_default, text, {rect.x, rect.y+rect.h*0.5-11-3*hovert-3*clickt}, 22, dgl.col_f2u(text_color))
// 	return clicked
// }
// 
// vui_draggable_button :: proc(id: u64, rect: Rect, text: string) {
// 	state := _vui_state(id, struct {
// 		hover_time:f64,
// 		dragging:bool,
// 		// In dragging mode, this represents the offset from mouse pos to the anchor.
// 		// In nondragging mode, this is the current rect anchor.
// 		drag_offset:Vec2 
// 	})
// 	input_rect := rect
// 	rect := rect
// 	hovering := false
// 	if state.dragging {
// 		hovering = true
// 		rect.x = input.mouse_position.x-state.drag_offset.x
// 		rect.y = input.mouse_position.y-state.drag_offset.y
// 
// 		if is_button_released(.Left) {
// 			if state.dragging {
// 				state.dragging = false
// 				state.drag_offset = {rect.x, rect.y}
// 			}
// 		}
// 	} else {
// 		if state.drag_offset != {} { // drag recovering
// 			topos := rect_position(input_rect)
// 			state.drag_offset = 40 * cast(f32)ctx.delta_s * (topos - state.drag_offset) + state.drag_offset
// 			if linalg.distance(topos, state.drag_offset) < 2 {
// 				state.drag_offset = {}
// 			} else {
// 				rect.x = state.drag_offset.x
// 				rect.y = state.drag_offset.y
// 			}
// 		}
// 		hovering = rect_in(rect, input.mouse_position)
// 		if hovering && is_button_pressed(.Left) {
// 			// start dragging
// 			state.dragging = true
// 			state.drag_offset = input.mouse_position - {rect.x, rect.y}
// 		}
// 	}
// 
// 	state.hover_time += ctx.delta_s if hovering else -ctx.delta_s
// 	state.hover_time = math.clamp(state.hover_time, 0, 0.2)
// 
// 	if is_button_released(.Left) {
// 		if state.dragging {
// 			state.dragging = false
// 			state.drag_offset = {rect.x, rect.y}
// 		}
// 	}
// 
// 	color_normal := dgl.col_u2f({195,75,75,   255})
// 	color_hover  := dgl.col_u2f({215,105,95,  255})
// 	color_flash  := dgl.col_u2f({245,235,235, 255})
// 
// 	hovert :f32= cast(f32)(math.min(state.hover_time, 0.2)/0.2)
// 	hovert = tween.ease_inoutsine(hovert)
// 	color := hovert*(color_hover-color_normal) + color_normal
// 
// 	draw_rect(rect, dgl.col_f2u(color))
// 	text_color := dgl.col_u2f({218,218,218, 255})
// 	draw_text(font_default, text, {rect.x, rect.y+rect.h*0.5-11-3*hovert}, 22, dgl.col_f2u(text_color))
// }
