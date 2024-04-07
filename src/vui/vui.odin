package vui

import "core:fmt"
import "core:sort"
import "core:strings"
import "core:strconv"
import "core:math"

import sdl "vendor:sdl2"
import "../dude/dude"
import dd "../dude/dude/core"
import "../dude/dude/imdraw"
import "../dude/dude/input"
import "../dude/dude/render"


ID :: distinct i64
Vec2 :: dd.Vec2
Rect :: dd.Rect

VuiContext :: struct {
    hot, active : ID,
    state : [128]u8,
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

get_state :: proc(ctx: ^VuiContext, s: $T) -> ^T {
    return auto_cast raw_data(ctx.state)
}
set_state :: proc(ctx: ^VuiContext, s: $T) {
    ptr := cast(^T)raw_data(ctx.state)
    ptr^ = s
}


button :: proc(using ctx: ^VuiContext, id: ID, text: string, rect: dd.Rect) -> bool {
    inrect := _is_in_rect(input.get_mouse_position(), rect)
    result := false
    if active == id {
        if input.get_mouse_button_up(.Left) {
            active = 0
            result = true
        }
    } else {
        if hot == id {
            if inrect {
                if input.get_mouse_button_down(.Left) {
                    active = id
                }
            } else {
                if !inrect do hot = 0
            }
        } else {
            if inrect && active == 0 {
                hot = id
            }
        }
    }
    COL_NORMAL :dd.Color32: {200,200,200, 255}
    COL_HOT :dd.Color32: {222,222,222, 255}
    COL_ACTIVE :dd.Color32: {255,255,255, 255}
    col := COL_NORMAL
    if hot == id do col = COL_HOT
    if active == id do col = COL_ACTIVE

    imdraw.quad(pass, {rect.x,rect.y}, {rect.w,rect.h}, col, order = 42000)
    imdraw.quad(pass, {rect.x,rect.y}+{4,4}, {rect.w,rect.h}, {2,2,2,128}, order = 42000-1)
    size :f32= 32
    imdraw.text(pass, font, text, {rect.x,rect.y+size}, size, {0,0,0,1}, order = 42001)
    return result
}

@private
_is_in_rect :: proc(p: Vec2, r: Rect) -> bool {
    return !(p.x<r.x || p.y<r.y || p.x>r.x+r.w || p.y>r.y+r.h)
}

get_id         :: proc{get_id_string, get_id_bytes, get_id_rawptr, get_id_uintptr}
get_id_string  :: #force_inline proc(str: string) -> ID { return get_id_bytes(transmute([]byte) str) }
get_id_rawptr  :: #force_inline proc(data: rawptr, size: int) -> ID { return get_id_bytes(([^]u8)(data)[:size])  }
get_id_uintptr :: #force_inline proc(ptr: uintptr) -> ID { 
	ptr := ptr
	return get_id_bytes(([^]u8)(&ptr)[:size_of(ptr)])  
}
get_id_bytes   :: proc(bytes: []byte) -> ID {
	/* 32bit fnv-1a hash */
	HASH_INITIAL :: 2166136261
	hash :: proc(hash: ^ID, data: []byte) {
		size := len(data)
		cptr := ([^]u8)(raw_data(data))
		for ; size > 0; size -= 1 {
			hash^ = ID(u32(hash^) ~ u32(cptr[0])) * 16777619
			cptr = cptr[1:]
		}
	}
	res : ID
	hash(&res, bytes)
	return res
}