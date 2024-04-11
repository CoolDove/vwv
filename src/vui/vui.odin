package vui

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

VuiContext :: struct {
    hot, active, dragging : ID,
    state : [STATE_MAX_SIZE]u8,
    dirty : bool,
    // ** implementation
    pass : ^render.Pass,
    // ** temporary style things
    font : dude.DynamicFont,
}

init :: proc(ctx: ^VuiContext, pass: ^render.Pass, font: dude.DynamicFont) {
    ctx.pass = pass
    ctx.font = font
}
release :: proc(ctx: ^VuiContext) {
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