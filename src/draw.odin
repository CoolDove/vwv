package main


import la "core:math/linalg"
import "core:math/linalg/glsl"
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
	_builtin_texture_white = dgl.texture_create_with_color(1,1, {255,255,255,255})
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
	dgl.state_set_blend(dgl.GlStateBlendSimp { true, .FUNC_ADD, .SRC_ALPHA, .ONE_MINUS_SRC_ALPHA })
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
	dgl.mesh_builder_add_indices(&_state.mesh, 0+offset,1+offset,2+offset)
	dgl.mesh_builder_add_indices(&_state.mesh, 0+offset,2+offset,3+offset)
	_end()
}

draw_texture_uv :: proc(texture: dgl.Texture, src, dst: dgl.Rect, origin: dgl.Vec2={0,0}, angle_rad: f32=0, tint: dgl.Color4u8={255,255,255,255}) {
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
