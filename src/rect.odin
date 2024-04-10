package main


import dd "dude/dude/core"
import "core:fmt"
import "core:math"



@(private="file")
R :: dd.Rect
@(private="file")
V2 :: dd.Vec2

rect_in :: proc(r: R, p: V2) -> bool {
	return !(p.x<r.x || p.y<r.y || p.x>r.x+r.w || p.y>r.y+r.h)
}

rect_position :: #force_inline proc(r: R) -> V2 {
	return {r.x, r.y}
}
rect_size :: #force_inline proc(r: R) -> V2 {
	return {r.w, r.h}
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

rect_padding :: proc(r: R, left, right, top, bottom: f32, loc:=#caller_location) -> R {
	assert(left+right < r.w && top+bottom < r.h, 
		fmt.tprintf("Invalid rect operation, padding: {},{},{},{} to rect {}", left,right,top,bottom, r), 
		loc=loc)
	return {r.x+left, r.y+top, r.w-right-left, r.h-top-bottom}
}

/*
                 width
*-------------*---------*
|             |/////////|
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
|/////////|             |
*---------*-------------*
*/
rect_split_left :: proc(r: R, width: f32) -> R {
	if width > 0 do return {r.x, r.y, width, r.h}
	else if width < 0 do return {r.x-width, r.y, width, r.h}
	return {r.x, r.y, 0, r.h}
}
rect_split_bottom :: proc(r: R, height: f32) -> R {
	if height > 0 do return {r.x, r.y, r.w, height}
	else if height < 0 do return {r.x, r.y-height, r.w, height}
	return {r.x, r.y, r.w, 0}
}
rect_split_top :: proc(r: R, height: f32) -> R {
	if height > 0 do return {r.x, r.y+r.h-height, r.w, height}
	else if height < 0 do return {r.x, r.y+r.h, r.w, height}
	return {r.x, r.y+r.h, r.w, 0}
}