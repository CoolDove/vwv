package vui

import "core:runtime"
import "core:fmt"
import "core:sort"
import "core:strings"
import "core:strconv"
import "core:math"

import "../dude/dude"
import dd "../dude/dude/core"
import "../dude/dude/imdraw"
import "../dude/dude/input"
import "../dude/dude/render"


ID :: distinct i64
@private
Vec2 :: dd.Vec2
@private
Rect :: dd.Rect

@private
STATE_MAX_SIZE :: 128
@private
STACK_OBJ_MAX_SIZE :: 128

// NOTE: How to handle hot and active
// If a control is active, it should set hot = 0 when moved out and set hot = id when inside.
// If a control is active or nobody is active, the control can set itself to be hot. If a control is
//	hot, it can set the hot = 0.


VuiContext :: struct {
    hot, active, dragging : ID,
	hot_order : i32,
    state : [STATE_MAX_SIZE]u8,
    dirty : bool,
    // ** implementation
    pass : ^render.Pass,
	stacks : [dynamic]VuiStack,
    // ** temporary style things
    font : dude.DynamicFont,
}

VuiStack :: struct {
	obj : [STACK_OBJ_MAX_SIZE]u8, // the data
	rects : [dynamic]Rect,
	allocator : runtime.Allocator,
}

init :: proc(ctx: ^VuiContext, pass: ^render.Pass, font: dude.DynamicFont) {
    ctx.pass = pass
    ctx.font = font
	ctx.stacks = make([dynamic]VuiStack)
}
release :: proc(ctx: ^VuiContext) {
	delete(ctx.stacks)
}

get_state :: proc(ctx: ^VuiContext, $T: typeid) -> ^T {
	assert(size_of(T) < STATE_MAX_SIZE, "VUI: Too large as a vui state object.")
    return auto_cast raw_data(ctx.state[:])
}
set_state :: proc(ctx: ^VuiContext, s: $T) {
	assert(size_of(T) < STATE_MAX_SIZE, "VUI: Too large as a vui state object.")
	ptr := cast(^T)raw_data(ctx.state[:])
	ptr^ = s
}

push_stack :: proc(ctx: ^VuiContext, allocator:=context.allocator) {
	push_stack_with(ctx, cast(int)0)
}
push_stack_with :: proc(ctx: ^VuiContext, obj: $T, allocator:=context.allocator) {
	assert(size_of(T) < STACK_OBJ_MAX_SIZE, "VUI: Too large as a vui stack object.")
	context.allocator = allocator
	append(&ctx.stacks, VuiStack{})
	stack := &ctx.stacks[len(ctx.stacks)-1]
	stack.allocator = allocator
	sobj := cast(^T)&stack.obj[0]
	sobj ^= obj
}
peek_stack :: proc(ctx: ^VuiContext) -> ^VuiStack {
	stack, _ := peek_stack_with(ctx, int)
	return stack
}

peek_stack_with :: proc(ctx: ^VuiContext, $T: typeid) -> (^VuiStack, ^T) {
	assert(len(ctx.stacks) > 0, "VUI: There's no stack for you to peek.")
	stack := &ctx.stacks[len(ctx.stacks)-1]
	t := cast(^T)(&stack.obj[0])
	return stack, t
}

pop_stack :: proc(ctx: ^VuiContext, forget_the_memories:=false/*If you allcated the stack on a temporary allocator*/) {
	assert(len(ctx.stacks) > 0, "VUI: There's no stack for you to pop.")
	stack := peek_stack(ctx)
	if !forget_the_memories do delete(stack.rects)
	pop(&ctx.stacks)
}

// When you use begin_elem(), and end_elem(), you call push_stack() when begin and pop_stach() when end.
// Any single-call elem can push_rect() to the current ctx, you can then iterate the rects in end_elem()
//	to exclude child rects when check if in rect.
push_rect :: proc(ctx: ^VuiContext, r: Rect) -> bool {
	// assert(len(ctx.stacks) > 0, "VUI: There's no stack for you to push the rect.")
	if len(ctx.stacks) == 0 do return false
	stack := peek_stack(ctx)
	context.allocator = stack.allocator
	if len(stack.rects) == 0 do stack.rects = make([dynamic]Rect)
	append(&stack.rects, r)
	return true
}

_handle_hot :: proc(using ctx: ^VuiContext, inrect: bool, id: ID, order: i32) {
	if inrect {
		if order >= hot_order do hot, hot_order = id, order
	} else if hot == id {
		hot, hot_order = 0, 0
	}
}

// Because this is a very simple immediate ui system, so if you got an element, when it's triggered,
//	causing it disapears next frame, the states won't be reset by it. So you can call this to manually
//	reset the ui system.
_reset :: proc(using ctx: ^VuiContext) {
	hot, active, hot_order = 0,0,0
}
