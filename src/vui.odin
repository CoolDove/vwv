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
Vec4 :: dgl.Vec4


VuiWidgetHandle :: #type hla.HollowArrayHandle(VuiWidget)

VuiContext :: struct {
	frameid : u64,
	hot : u64,
	hot_old : u64,
	hot_priority : u64,

	delta_s : f64,
	current_layout : ^VuiLayout,

	states : map[u64]VuiWidgetHandle,
	_state_pool : hla.HollowArray(VuiWidget),

	widget_stack : [dynamic]VuiWidgetHandle,

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

_vui_state :: proc(id: u64) -> (VuiWidgetHandle, ^VuiWidget) {
	s, ok := ctx.states[id] 
	if !ok {
		ctx.states[id] = hla.hla_append(&ctx._state_pool, VuiWidget{})
		s = ctx.states[id]
	}
	wjt := hla.hla_get_pointer(s)
	wjt.basic.frameid = ctx.frameid
	return s, wjt
}

_vui_ctx :: proc() -> ^VuiContext {
	return &ctx
}

vui_init :: proc() {
	ctx._state_pool = hla.hla_make(VuiWidget, 256)
	ctx.states = make(map[u64]hla.HollowArrayHandle(VuiWidget))
	tbro_init(&ctx._temp_tbro, font_default, 28)
	ctx.widget_stack = make([dynamic]VuiWidgetHandle, 16)
}
vui_release :: proc() {
	tbro_release(&ctx._temp_tbro)
	delete(ctx.states)
	delete(ctx.widget_stack)
	hla.hla_delete(&ctx._state_pool)
}

vui_begin :: proc(delta_s: f64, rect: Rect) {
	ctx.frameid += 1
	ctx.delta_s = delta_s
	ctx.hot = 0
	ctx.hot_priority = 0

	clear(&ctx.widget_stack)
}
vui_end :: proc() {
	for k, v in ctx.states {
		wjt := _vuibd_helper_get_pointer_from_handle(v)
		if wjt.basic.frameid != ctx.frameid {
			delete_key(&ctx.states, k)
			hla.hla_remove(v)
		}
	}
	ctx.hot_old = ctx.hot
}

VuiWidget :: struct {
	basic : VuiWidget_Basic,

	clickable : VuiWidget_Clickable,

	update_custom           : VuiWidget_UpdateCustom,

	draw_rect               : VuiWidget_DrawRect,
	draw_rect_hot           : VuiWidget_DrawRectHot,
	draw_rect_hot_animation : VuiWidget_DrawRectHotAnimation,
	draw_rect_active        : VuiWidget_DrawRectActive,
	draw_text               : VuiWidget_DrawText,
	draw_custom             : VuiWidget_DrawCustom,

	layout : VuiWidget_LayoutContainer,
}

VuiWidget_Basic :: struct {
	// keep between frames
	id, frameid : u64,
	priority : u64,
	ready : bool,
	rect, baked_rect : Rect,

	// reset
	children_count : int,
	using _tree : struct {
		parent, child, next, last : VuiWidgetHandle,
	},
	interact : VuiInteract,
}
VuiWidget_Clickable :: struct {
	enable : bool,
}
VuiWidget_UpdateCustom :: struct {
	enable : bool,
	update : proc(w: VuiWidgetHandle),
	data : [8*8]u8,
}

VuiWidget_DrawRect :: struct {
	enable : bool,
	color : Color,
	round : f64,
	round_segment : int,
}
VuiWidget_DrawRectHot :: struct {
	enable : bool,
	color : Color,
}
VuiWidget_DrawRectHotAnimation :: struct {
	enable : bool,
	duration, time : f64,
}
VuiWidget_DrawRectActive :: struct {
	enable : bool,
	color : Color,
}

VuiWidget_DrawText :: struct {
	enable : bool,
	size : f64,
	text : string,
	color : Color,
}
VuiWidget_DrawCustom :: struct {
	enable : bool,
	draw : proc(state: VuiWidgetHandle),
	data : rawptr,
}

VuiWidget_LayoutContainer :: struct {
	enable : bool,
	direction : VuiLayoutDirection,
	spacing : f32,
	padding : Vec4, // left, top, right, bottom

	_used_space : f32,
	_fit_elem_count : int,
}
VuiLayoutDirection :: enum {
	Vertical, Horizontal
}

VuiInteract :: struct {
	pressed : bool,
	pressed_outside : bool,
	clicked : bool,
	clicked_outside : bool,
	_require_size : Vec2,
}

@(private="file")
_peek_state :: #force_inline proc() -> (VuiWidgetHandle, ^VuiWidget) {
	if len(ctx.widget_stack) == 0 do return {}, nil
	handle := ctx.widget_stack[len(ctx.widget_stack)-1]
	return handle, hla.hla_get_pointer(handle)
}

_vuibd_helper_get_current :: _peek_state
_vuibd_helper_get_pointer_from_handle :: proc(h: VuiWidgetHandle) -> ^VuiWidget {
	return hla.hla_get_pointer(h)
}

_vuibd_begin :: proc(id: u64, rect: Rect) {
	h, state := _vui_state(id)
	state.basic.rect = rect
	state.basic.children_count = 0
	if state.basic.ready {
		state.basic._tree = {}
		state.basic.interact = {}
	} else {
		state.basic.id = id
	}

	state.clickable.enable               = false
	state.update_custom.enable           = false

	state.draw_rect.enable               = false
	state.draw_text.enable               = false
	state.draw_rect_hot.enable           = false
	state.draw_rect_hot_animation.enable = false
	state.draw_rect_active.enable        = false
	state.draw_custom.enable             = false

	state.layout.enable                  = false

	if parenth, parent := _peek_state(); parent != nil {
		__widget_append_child(parenth, h)

		if layout:= &parent.layout; layout.enable {
			layout_size := rect_size(parent.basic.rect)
			using state.basic
			switch layout.direction {
			case .Vertical:
				if rect.w < 0 && layout_size.x > 0 do rect.w = layout_size.x - layout.padding.x - layout.padding.z
				if rect.h < 0 do layout._fit_elem_count += 1
				else do layout._used_space += auto_cast rect.h
			case .Horizontal:
				if rect.h < 0 && layout_size.y > 0 do rect.h = layout_size.y - layout.padding.y - layout.padding.w
				if rect.w < 0 do layout._fit_elem_count += 1
				else do layout._used_space += auto_cast rect.w
			}
		}
	}

	append(&ctx.widget_stack, h)
}
_vuibd_end :: proc() -> VuiInteract {
	state := pop(&ctx.widget_stack)
	return _vui_widget(state)
}

@(deferred_none=_vuibd_end)
_vuibd_element_scoped :: proc(id: u64, rect: Rect) -> bool {
	_vuibd_begin(id, rect)
	return true
}

_vuibd_draw_rect :: proc(color: Color, round := 0.0, seg: int=2) -> ^VuiWidget_DrawRect {
	_, state := _peek_state()
	state.draw_rect.enable = true
	state.draw_rect.color = color
	state.draw_rect.round = round
	state.draw_rect.round_segment = seg
	return &state.draw_rect
}
_vuibd_draw_rect_hot :: proc(color: Color) -> ^VuiWidget_DrawRectHot {
	_, state := _peek_state()
	state.draw_rect_hot.enable = true
	state.draw_rect_hot.color = color
	return &state.draw_rect_hot
}
_vuibd_draw_rect_hot_animation :: proc(duration: f64) {
	_, state := _peek_state()
	state.draw_rect_hot_animation.enable = true
	state.draw_rect_hot_animation.duration = duration
}
_vuibd_draw_rect_active :: proc(color: Color) {
	_, state := _peek_state()
	state.draw_rect_active.enable = true
	state.draw_rect_active.color = color
}
_vuibd_draw_text :: proc(color: Color, text: string, size: f64) {
	_, state := _peek_state()
	draw := &state.draw_text
	draw.enable = true
	draw.color = color
	draw.size = size
	draw.text = text
}
_vuibd_draw_custom :: proc(draw: proc(w: VuiWidgetHandle), data: rawptr) {
	stateh, state := _peek_state()
	state.draw_custom = { true, draw, data }
}

_vuibd_clickable :: proc() {
	_, state := _peek_state()
	state.clickable.enable = true
}

_vuibd_update_custom :: proc(update: proc(w: VuiWidgetHandle)) -> rawptr {
	_, state := _peek_state()
	state.update_custom.enable = true
	state.update_custom.update = update
	return &state.update_custom.data
}

_vuibd_layout :: proc(direction: VuiLayoutDirection) -> ^VuiWidget_LayoutContainer {
	_, state := _peek_state()
	layout := &state.layout
	layout.enable = true
	layout.direction = direction
	layout._used_space = 0
	layout._fit_elem_count = 0
	return layout
}

vui_test_button :: proc(id: u64, rect: Rect, text: string) -> VuiInteract {
	_vuibd_begin(id, rect)
	_vuibd_draw_rect({140, 180, 190, 255}, 6, 3)
	_vuibd_draw_rect_hot({165, 210, 226, 255})
	_vuibd_draw_rect_hot_animation(0.3)
	_vuibd_draw_rect_active({200, 200, 210, 255})
	_vuibd_clickable()
	_vuibd_draw_text(dgl.WHITE, text, 20)
	return _vuibd_end()
}

vui_layout_begin :: proc(id: u64, rect: Rect, direction: VuiLayoutDirection, spacing: f32=0, padding: Vec4={}, color: Color={}) {
	_vuibd_begin(id, rect)
	if color != {} do _vuibd_draw_rect(color, 4, 4)
	layout := _vuibd_layout(direction)
	layout.spacing = spacing
	layout.padding = padding
}
vui_layout_end :: proc() {
	_vuibd_end()
}

@(deferred_none=vui_layout_end)
vui_layout_scoped :: proc(id: u64, rect: Rect, direction: VuiLayoutDirection, spacing: f32=0, padding: Vec4={}, color: Color={}) -> bool {
	vui_layout_begin(id, rect, direction, spacing, padding, color)
	return true
}

@(private="file")
__widget_append_child :: proc(parent, child: VuiWidgetHandle) {
	parenth := parent
	parent := hla.hla_get_pointer(parent)
	if parent.basic.child == {} {
		parent.basic.child = child
	} else {
		hla.hla_get_pointer(parent.basic.last).basic.next = child
	}
	hla.hla_get_pointer(child).basic.parent = parenth
	parent.basic.last = child
	parent.basic.children_count += 1
	chd := hla.hla_get_pointer(child)
	chd.basic.priority = parent.basic.priority + 1
}

_vui_widget :: proc(state: VuiWidgetHandle) -> VuiInteract {
	stateh := state
	state := hla.hla_get_pointer(state)
	using state.basic

	if state.clickable.enable && state.basic.ready {
		inrect := rect_in(state.basic.baked_rect, input.mouse_position)

		if is_button_pressed(.Left) && ctx.hot_old == id {
			interact.clicked = true
		}

		if inrect && priority > ctx.hot_priority {
			ctx.hot = id
			ctx.hot_priority = state.basic.priority
		}
	}
	if state.update_custom.enable {
		state.update_custom.update(stateh)
	}

	_layout_widget :: proc(state: VuiWidgetHandle, pass: int) {
		stateh := state
		state := hla.hla_get_pointer(state)
		using state.basic
		// PASS A: sizes
		if pass == 0 && hla.hla_get_pointer(child) != nil {
			layout := state.layout
			p := child

			fittable_size :f32= 0.0; if state.layout.enable {
				switch state.layout.direction {
				case .Vertical: fittable_size = auto_cast state.basic.rect.h - state.layout.padding.w
				case .Horizontal: fittable_size = auto_cast state.basic.rect.w - state.layout.padding.z
				}
				fittable_size -= cast(f32)(state.basic.children_count-1)*state.layout.spacing
				fittable_size -= state.layout._used_space
				fittable_size = math.max(0, fittable_size)
			}
			container_size : Vec2
			for true {
				s := hla.hla_get_pointer(p)
				using s.basic
				if s == nil do break
				if state.layout.enable {
					switch state.layout.direction {
					case .Vertical:
						if rect.h < 0 {
							height := -rect.h
							height = math.max(height, fittable_size/cast(f32)layout._fit_elem_count)
							rect.h = height
						}
						container_size.y += rect.h + layout.spacing
						if p == state.basic.child do container_size.y -= layout.spacing
					case .Horizontal:
						if rect.w < 0 {
							width := -rect.w
							width = math.max(width, fittable_size/cast(f32)layout._fit_elem_count)
							rect.w = width
						}
						container_size.x += rect.w + layout.spacing
						if p == state.basic.child do container_size.x -= layout.spacing
					}
				}
				_layout_widget(p, 0)
				p = next
			}

			if state.layout.enable {
				switch state.layout.direction {
				case .Vertical:
					state.basic.rect.h = math.max(container_size.y+layout.padding.y+layout.padding.w, state.basic.rect.h)
				case .Horizontal:
					state.basic.rect.w = math.max(container_size.x+layout.padding.x+layout.padding.z, state.basic.rect.w)
				}
			}
		}

		// PASS B: positions
		if pass == 1 && hla.hla_get_pointer(child) != nil {
			layout := state.layout
			container_rect := state.basic.rect
			position :Vec2= rect_position(container_rect)
			if layout.enable {
				position += {layout.padding.x, layout.padding.y}
			}

			p := child
			for true {
				s := hla.hla_get_pointer(p)
				if s == nil do break
				using s.basic
				if state.layout.enable {
					switch state.layout.direction {
					case .Vertical:
						rect.x = position.x
						rect.y = position.y
						if rect.w < 0 do rect.w = state.basic.rect.w - state.layout.padding.x - state.layout.padding.z
						position += {0, rect.h + cast(f32)layout.spacing}
					case .Horizontal:
						rect.x = position.x
						rect.y = position.y
						if rect.h < 0 do rect.h = state.basic.rect.h - state.layout.padding.y - state.layout.padding.w
						position += {rect.w + cast(f32)layout.spacing, 0}
					}
				}
				_layout_widget(p, 1)
				p = next
				baked_rect = rect
			}
		}
		state.basic.ready = true
	}
	if _, parent := _peek_state(); parent == nil {
		_layout_widget(stateh, 0)
		_layout_widget(stateh, 1)
	}

	_draw_widget :: proc(state: VuiWidgetHandle) {
		stateh := state
		state := hla.hla_get_pointer(state)
		using state.basic

		if state.draw_rect.enable {
			using state.draw_rect
			c := color
			if state.draw_rect_hot.enable {
				if ctx.hot_old == id {
					if state.draw_rect_hot_animation.enable {
						anim := &state.draw_rect_hot_animation
						anim.time += ctx.delta_s
						anim.time = math.min(anim.time, anim.duration)
						t := anim.time/anim.duration
						fromc, toc := dgl.col_u2f(color), dgl.col_u2f(state.draw_rect_hot.color)
						c = dgl.col_f2u(cast(f32)t * (toc - fromc) + fromc)
					} else {
						c = state.draw_rect_hot.color
					}
				} else {
					if state.draw_rect_hot_animation.enable {
						anim := &state.draw_rect_hot_animation
						anim.time -= ctx.delta_s
						anim.time = math.max(anim.time, 0)
						t := anim.time/anim.duration
						fromc, toc := dgl.col_u2f(color), dgl.col_u2f(state.draw_rect_hot.color)
						c = dgl.col_f2u(cast(f32)t * (toc - fromc) + fromc)
					}
				}
				// if ctx.active == id {
				// 	if state.draw_rect_active.enable {
				// 		c = state.draw_rect_active.color
				// 	}
				// }
			}
			if round <= 0 {
				draw_rect(rect, c)
			} else {
				draw_rect_rounded(rect, cast(f32)round, round_segment, c)
			}
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
		if state.draw_custom.enable {
			using state.draw_custom
			draw(stateh)
		}

		// draw child tree
		if hla.hla_get_pointer(child) != nil {
			p := child
			for true {
				s := hla.hla_get_pointer(p)
				if s == nil do break
				_draw_widget(p)
				p = s.basic.next
			}
		}
	}

	if _, parent := _peek_state(); parent == nil {
		_draw_widget(stateh)
	}

	return interact
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
