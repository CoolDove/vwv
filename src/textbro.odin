package main

import "dgl"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:unicode/utf8"
import "vendor:fontstash"


/* TODO
- Handle multiple lines.
- Handle iterate back.
- Implement some basic styles.
*/

TextBro :: struct {
	fontid : int,
	size : f64,
	overflow_width : f64,
	elems : [dynamic]TextBroElem,
}

TextBroElem :: struct {
	quad_dst, quad_src : dgl.Rect,
	color : dgl.Color4u8,
	next : dgl.Vec2,
}

tbro_init :: proc(tbro: ^TextBro, fontid: int, size: f64, overflow_width := -1.0, allocator:= context.allocator) {
	context.allocator = allocator
	tbro.elems = make([dynamic]TextBroElem)
	tbro.fontid = fontid
	tbro.size = size
	tbro.overflow_width = overflow_width
}
tbro_release :: proc(tbro: ^TextBro) {
	delete(tbro.elems)
}

tbro_length :: proc(tbro: ^TextBro) -> int {
	return len(tbro.elems)
}
tbro_last :: proc(tbro: ^TextBro) -> ^TextBroElem {
	if len(tbro.elems) == 0 do return nil
	return &tbro.elems[len(tbro.elems)-1]
}

tbro_write_string :: proc(tbro: ^TextBro, text: string, color: dgl.Color4u8) -> int {
	if text == "" do return tbro_length(tbro)
	size := cast(f32)tbro.size
	fontid := tbro.fontid

	fs := &fsctx.fs
	fontstash.BeginState(fs)
	fontstash.ClearState(fs)
	fontstash.SetSize(fs, size)
	fontstash.SetSpacing(fs, 1)
	fontstash.SetBlur(fs, 0)
	fontstash.SetAlignHorizontal(fs, .LEFT)
	fontstash.SetAlignVertical(fs, .BASELINE)
	fontstash.SetFont(fs, fontid)

	iter := fontstash.TextIterInit(fs, 0, 0, text)
	if last := tbro_last(tbro); last != nil {
		iter.nextx = last.next.x
		iter.nexty = last.next.y
	} else {
		iter.nexty += size
	}
	prev_iter := iter
	q: fontstash.Quad
	for fontstash.TextIterNext(fs, &iter, &q) {
		if iter.previousGlyphIndex == -1 { // can not retrieve glyph?
			iter = prev_iter
			fontstash.TextIterNext(fs, &iter, &q) // try again
			if iter.previousGlyphIndex == -1 {
				break
			}
		}
		prev_iter = iter
		newline := iter.codepoint == '\n'

		overflow := (tbro.overflow_width > 0 && (iter.nextx + (q.x1-q.x0)) > cast(f32)tbro.overflow_width)
		if newline || overflow {
			iter.nextx = 0
			iter.nexty += size
		}
		w, h := cast(f32)fsctx.atlas.size.x, cast(f32)fsctx.atlas.size.y
		if !newline {
			using q
			// draw_texture_ex(fsctx.atlas, {s0*w, t0*h, (s1-s0)*w, (t1-t0)*h}, {x0+position.x, y0+position.y, x1-x0, y1-y0}, {0,0}, 0, color)
			append(&tbro.elems, TextBroElem {
				quad_src = {s0*w, t0*h, (s1-s0)*w, (t1-t0)*h},
				quad_dst = {x0, y0, x1-x0, y1-y0},
				color = color,
				next = {iter.nextx, iter.nexty},
			})
		}
	}
	fontstash.EndState(fs)
	return tbro_length(tbro)
}
