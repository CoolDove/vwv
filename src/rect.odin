package main

import "core:fmt"
import "core:math"

import "dgl"



@(private="file")
R :: dgl.Rect
@(private="file")
V2 :: dgl.Vec2
@(private="file")
V4 :: dgl.Vec4

rect_in :: proc(r: R, p: V2) -> bool {
	return !(p.x<r.x || p.y<r.y || p.x>r.x+r.w || p.y>r.y+r.h)
}

rect_position :: #force_inline proc(r: R) -> V2 {
	return {r.x, r.y}
}
rect_size :: #force_inline proc(r: R) -> V2 {
	return {r.w, r.h}
}
rect_position_size :: #force_inline proc(r: R) -> (V2, V2) {
	return {r.x, r.y}, {r.w, r.h}
}
rect_min :: #force_inline proc(r: R) -> V2 {
	return rect_position(r)
}
rect_max :: #force_inline proc(r: R) -> V2 {
	return rect_position(r)+rect_size(r)
}

rect_require :: proc(r: R, width:f32=0, height:f32=0, anchor:V2={0,0}) -> R {
	if width <= r.w && height <= r.h do return r
	width := max(width, r.w)
	height := max(height, r.h)
	c := rect_position(r) + anchor * rect_size(r)
	scale :V2= {width/r.w, height/r.h}
	min := c+(rect_position(r)-c) * scale
	max := c+(rect_position(r)+rect_size(r)-c) * scale
	return {min.x, min.y, max.x-min.x, max.y-min.y}
}

rect_padding :: proc(r: R, left, right, top, bottom: f32) -> R {
	return {r.x+left, r.y+top, r.w-right-left, r.h-top-bottom}
}

rect_anchor :: proc(r: R, anchor, offset: V4 /*left, top, right, bottom*/) -> R {
	new_x := r.x + anchor.x * r.w + offset.x
	new_y := r.y + anchor.y * r.h + offset.y
	new_w := r.w * (anchor.z - anchor.x) + (offset.z - offset.x)
	new_h := r.h * (anchor.w - anchor.y) + (offset.w - offset.y)
	return R{new_x, new_y, new_w, new_h}
}

/*
				 width
*-------------*---------*
|			  |/////////|
*-------------*---------*
*/
rect_split_right :: proc(r: R, width: f32) -> R {
	if width > 0 do return {r.x+r.w-width, r.y, width, r.h}
	else if width < 0 do return {r.x+r.w, r.y, width, r.h}
	return {r.x, r.y+r.w, 0, r.h}
}
/*
   width
*---------*-------------*
|/////////|				|
*---------*-------------*
*/
rect_left :: proc(r: R, width: f32) -> R {
	if width > 0 do return {r.x, r.y, width, r.h}
	else if width < 0 do return {r.x-width, r.y, width, r.h}
	return {r.x, r.y, 0, r.h}
}
rect_bottom :: proc(r: R, height: f32) -> R {
	return {r.x, r.y+r.h-height, r.w, height}
}
rect_top :: proc(r: R, height: f32) -> R {
	return {r.x, r.y, r.w, height}
}


// ***
rect_from_position_size :: proc(p,s: V2) -> R {
	return {p.x, p.y, s.x, s.y}
}
