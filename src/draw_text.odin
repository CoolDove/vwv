package main

import "core:fmt"
import "core:strings"
import "core:math/linalg"
import "vendor:fontstash"

import "./dgl"

draw_text :: proc(fontid: int, text: string, position: dgl.Vec2, size: f32, color: dgl.Color4u8, overflow_width := 0.0) -> f32 {
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
	iter.nexty += size
	prev_iter := iter
	q: fontstash.Quad
	height : f32
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

		overflow := (overflow_width > 0 && (iter.nextx + (q.x1-q.x0)) > cast(f32)overflow_width)
		if newline || overflow {
			iter.nextx = 0
			iter.nexty += size
			height += size
		}
		w, h := cast(f32)fsctx.atlas.size.x, cast(f32)fsctx.atlas.size.y
		if !newline {
			using q
			// rl.DrawTexturePro(fsctx.atlas, {s0*w, t0*h, (s1-s0)*w, (t1-t0)*h}, {x0+position.x, y0+position.y, x1-x0, y1-y0}, {0,0}, 0, color)
			draw_texture_ex(fsctx.atlas, {s0*w, t0*h, (s1-s0)*w, (t1-t0)*h}, {x0+position.x, y0+position.y, x1-x0, y1-y0}, {0,0}, 0, color)
		}
	}
	fontstash.EndState(fs)
	return height
}
