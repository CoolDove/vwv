package main


import la "core:math/linalg"
import "core:math/linalg/glsl"
import "core:math"
import "core:fmt"
import "dgl"


DrawState :: struct {
	mesh : dgl.MeshBuilder,
	shader : dgl.ShaderId,
	texture0 : dgl.TextureId,
	viewport : dgl.Vec4i,
}

@(private="file")
_shader_default : dgl.ShaderId
_shader_default_uniforms : struct {
	mvp : dgl.UniformLocMat4x4,
	texture0 : dgl.UniformLocTexture,
}

@(private="file")
_builtin_texture_white : dgl.TextureId // 1-pixel white texture

_state : DrawState

init_draw :: proc() {
	_shader_default = dgl.shader_load_from_sources(#load("../res/default.vert"), #load("../res/default.frag"))
	dgl.uniform_load(&_shader_default_uniforms, _shader_default)
	_builtin_texture_white = dgl.texture_create_with_color(1,1, {255,255,255,255}).id
	dgl.mesh_builder_init(&_state.mesh, dgl.VERTEX_FORMAT_P3U2C4)
}
destroy_draw :: proc() {
	dgl.shader_destroy(_shader_default)
	dgl.texture_destroy_id(_builtin_texture_white)
	dgl.mesh_builder_release(&_state.mesh)
}

begin_draw :: proc(viewport: dgl.Vec4i) {
	_state.shader = {}
	_state.texture0 = {}
	_state.viewport = viewport
	dgl.mesh_builder_clear(&_state.mesh)
}
end_draw :: proc() {
	submit_batch()
}

draw_rect :: proc(rect: dgl.Rect, color: dgl.Color4u8) {
	_begin(_shader_default, _builtin_texture_white)
	offset := cast(u32)dgl.mesh_builder_count_vertex(&_state.mesh)
	color := dgl.col_u2f(color)
	r,g,b,a := color.r,color.g,color.b,color.a
	dgl.mesh_builder_add_vertices(&_state.mesh,
		{ rect.x,rect.y,0,                0,0,  r,g,b,a },
		{ rect.x+rect.w,rect.y,0,         0,0,  r,g,b,a },
		{ rect.x+rect.w,rect.y+rect.h,0,  0,0,  r,g,b,a },
		{ rect.x,rect.y+rect.h,0,         0,0,  r,g,b,a },
	)
	dgl.mesh_builder_add_indices_with_offset(&_state.mesh, offset, 0,1,2)
	dgl.mesh_builder_add_indices_with_offset(&_state.mesh, offset, 0,2,3)
	_end()
}

draw_rect_rounded :: proc(rect: dgl.Rect, rounded: f32, segments: int, color: dgl.Color4u8, use_edge_color:= false, edge_color: dgl.Color4u8={}) {
	_begin(_shader_default, _builtin_texture_white)

	mb := &_state.mesh

	offset := cast(u32)dgl.mesh_builder_count_vertex(mb)
	colorf := dgl.col_u2f(color)
	r, g, b, a := colorf.r, colorf.g, colorf.b, colorf.a

	edge_color := edge_color
	if !use_edge_color do edge_color = color

	ecolorf := dgl.col_u2f(edge_color)
	er, eg, eb, ea := ecolorf.r, ecolorf.g, ecolorf.b, ecolorf.a

	// 四个矩形顶点
	rad := math.clamp(rounded, 0.0, math.min(rect.w, rect.h) * 0.5)
	x0, y0 := rect.x, rect.y
	x1, y1 := x0 + rect.w, y0 + rect.h

	// 添加中心矩形的四个顶点
	dgl.mesh_builder_add_vertices(mb, // 0~3
		{ x0 + rad, y0 + rad, 0,  0, 0,  r, g, b, a },
		{ x1 - rad, y0 + rad, 0,  0, 0,  r, g, b, a },
		{ x1 - rad, y1 - rad, 0,  0, 0,  r, g, b, a },
		{ x0 + rad, y1 - rad, 0,  0, 0,  r, g, b, a },
	)

	dgl.mesh_builder_add_vertices(mb, // 4~11
		{ x0 + rad, y0,       0,  0, 0,  er, eg, eb, ea },
		{ x1 - rad, y0,       0,  0, 0,  er, eg, eb, ea },
		{ x1,       y0 + rad, 0,  0, 0,  er, eg, eb, ea },
		{ x1,       y1 - rad, 0,  0, 0,  er, eg, eb, ea },
		{ x1 - rad, y1,       0,  0, 0,  er, eg, eb, ea },
		{ x0 + rad, y1,       0,  0, 0,  er, eg, eb, ea },
		{ x0,       y1 - rad, 0,  0, 0,  er, eg, eb, ea },
		{ x0,       y0 + rad, 0,  0, 0,  er, eg, eb, ea },
	)

	dgl.mesh_builder_add_indices_with_offset(mb, offset, 0,1,2)
	dgl.mesh_builder_add_indices_with_offset(mb, offset, 0,2,3)

	dgl.mesh_builder_add_indices_with_offset(mb, offset, 4,5,1,  4,1,0)
	dgl.mesh_builder_add_indices_with_offset(mb, offset, 1,6,7,  1,7,2)
	dgl.mesh_builder_add_indices_with_offset(mb, offset, 3,2,8,  3,8,9)
	dgl.mesh_builder_add_indices_with_offset(mb, offset, 11,0,3, 11,3,10)

	arc_offset := cast(u32)dgl.mesh_builder_count_vertex(mb)
	add_arc_vertices :: proc(mb: ^dgl.MeshBuilder, center, vector: dgl.Vec2, step: f32, color: dgl.Color4u8, segments: int, base_offset, icenter, ifrom, iend: int) {
		colorf := dgl.col_u2f(color)
		r, g, b, a := colorf.r, colorf.g, colorf.b, colorf.a
		segments := segments - 1
		if segments == 0 {
			dgl.mesh_builder_add_indices_with_offset(mb, auto_cast base_offset, auto_cast icenter, auto_cast ifrom, auto_cast iend)
			return
		}

		vector := la.matrix2_rotate(step*math.RAD_PER_DEG) * vector
		p := center + vector
		idx := cast(u32)dgl.mesh_builder_count_vertex(mb)-cast(u32)base_offset
		dgl.mesh_builder_add_vertices(mb, { p.x, p.y, 0,   0,0,   r,g,b,a })
		dgl.mesh_builder_add_indices_with_offset(mb, auto_cast base_offset, auto_cast icenter, auto_cast ifrom, auto_cast idx)
		add_arc_vertices(mb, center, vector, step, color, segments, base_offset, icenter, auto_cast idx, auto_cast iend)
	}

	add_arc_vertices(mb, {x1 - rad, y0 + rad}, {0,-rad}, 90.0/cast(f32)segments, edge_color, segments, cast(int)offset, 1, 5, 6)
	add_arc_vertices(mb, {x1 - rad, y1 - rad}, {rad,0},  90.0/cast(f32)segments, edge_color, segments, cast(int)offset, 2, 7, 8)
	add_arc_vertices(mb, {x0 + rad, y1 - rad}, {0,rad},  90.0/cast(f32)segments, edge_color, segments, cast(int)offset, 3, 9, 10)
	add_arc_vertices(mb, {x0 + rad, y0 + rad}, {-rad,0}, 90.0/cast(f32)segments, edge_color, segments, cast(int)offset, 0, 11, 4)

	_end()
}

draw_texture_ex :: proc(texture: dgl.Texture, src, dst: dgl.Rect, origin: dgl.Vec2={0,0}, angle_rad: f32=0, tint: dgl.Color4u8={255,255,255,255}) {
	_begin(_shader_default, texture.id)
	size := dgl.vec_i2f(texture.size)
	color := dgl.col_u2f(tint)
	r,g,b,a := color.r,color.g,color.b,color.a
	offset := cast(u32)dgl.mesh_builder_count_vertex(&_state.mesh)
	dgl.mesh_builder_add_vertices(&_state.mesh,
		{ dst.x,dst.y,0,                src.x/size.x, src.y/size.y,                  r,g,b,a },
		{ dst.x+dst.w,dst.y,0,          (src.x+src.w)/size.x, src.y/size.y,          r,g,b,a },
		{ dst.x+dst.w,dst.y+dst.h,0,    (src.x+src.w)/size.x, (src.y+src.h)/size.y,  r,g,b,a },
		{ dst.x,dst.y+dst.h,0,          src.x/size.x, (src.y+src.h)/size.y,          r,g,b,a },
	)
	dgl.mesh_builder_add_indices(&_state.mesh, 0+offset,1+offset,2+offset)
	dgl.mesh_builder_add_indices(&_state.mesh, 0+offset,2+offset,3+offset)

	_end()
}

_begin :: proc(shader: dgl.ShaderId, texture0: dgl.TextureId) {
	if !is_batchable(shader, texture0) {
		submit_batch()
	}
	_state.shader = shader
	_state.texture0 = texture0
}
_end :: proc() {
}

is_batchable :: proc(shader: dgl.ShaderId, texture0: dgl.TextureId) -> bool {
	return _state.shader == shader && _state.texture0 == texture0
}
submit_batch :: proc() {
	dgl.state_set_blend(dgl.GlStateBlendSimp { true, .FUNC_ADD, .SRC_ALPHA, .ONE_MINUS_SRC_ALPHA })
	dgl.state_set_viewport(_state.viewport)
	if _state.shader != 0 {
		if _state.shader == _shader_default {
			dgl.shader_bind(_state.shader)
			w, h := cast(f32)_state.viewport.z, cast(f32)_state.viewport.w
			mat := glsl.mat4Ortho3d(0,w, h,0, -1,1)
			dgl.uniform_set_mat4x4(_shader_default_uniforms.mvp, mat)
			dgl.uniform_set_texture(_shader_default_uniforms.texture0, _state.texture0, 0)
		} else {
			assert(false, "Shader not handled")
		}
		mesh := dgl.mesh_builder_create(_state.mesh)
		dgl.draw_mesh(mesh)
		dgl.mesh_delete(&mesh)
	}
	_state.shader = {}
	_state.texture0 = {}
	dgl.mesh_builder_clear(&_state.mesh)
}
