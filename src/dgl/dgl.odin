package dgl

import gl "vendor:OpenGL"

import "core:log"
import "core:math"
import "core:math/linalg"


init :: proc() {
	release_handler = make([dynamic]proc())
}

@private
release_handler : [dynamic]proc()

release :: proc() {
	#reverse for rh in release_handler do rh()
	delete(release_handler)
}

set_vertex_format :: proc(format: VertexFormat) {
	channels :u32= 0
	offset :u32= 0
	stride :u32= 0
	for i in 0..<VERTEX_MAX_CHANNEL do stride += cast(u32)format[i]

	for i in 0..<VERTEX_MAX_CHANNEL {
		c := format[i]
		if c == 0 do continue
		gl.EnableVertexAttribArray(channels)
		gl.VertexAttribPointer(channels, cast(i32)c, gl.FLOAT, false, cast(i32)(stride * size_of(f32)), cast(uintptr)offset*size_of(f32))
		channels += 1
		offset += cast(u32)c
	}
}

// A VertexArrayObject should be binded before these `set_vertex_format` things.
set_vertex_format_PCU :: proc(shader: u32) {
	location_position := gl.GetAttribLocation(shader, "position")
	location_color	  := gl.GetAttribLocation(shader, "color")
	location_uv		  := gl.GetAttribLocation(shader, "uv")

	P, C, U :u32 = cast(u32)location_position, cast(u32)location_color, cast(u32)location_uv
	stride :i32= size_of(VertexPCU)

	if location_position != -1 {
		gl.EnableVertexAttribArray(P)
		gl.VertexAttribPointer(P, 3, gl.FLOAT, false, stride, 0)
	}
	if location_color != -1 {
		gl.EnableVertexAttribArray(C)
		gl.VertexAttribPointer(C, 4, gl.FLOAT, false, stride, 3 * size_of(f32))
	}
	if location_uv != -1 {
		gl.EnableVertexAttribArray(U)
		gl.VertexAttribPointer(U, 2, gl.FLOAT, false, stride, 7 * size_of(f32))
	}
}
set_vertex_format_PCNU :: proc(shader: u32) {
	location_position := gl.GetAttribLocation(shader, "position")
	location_color	  := gl.GetAttribLocation(shader, "color")
	location_normal   := gl.GetAttribLocation(shader, "normal")
	location_uv		  := gl.GetAttribLocation(shader, "uv")

	// assert(location_position != -1 && location_color != -1 && location_normal != -1 && location_uv != -1, 
	//	   "DGL Set Vertex Format: attributes in shader doesnt support format `PCNU`")

	P, C, N, U :u32 = cast(u32)location_position, cast(u32)location_color, cast(u32)location_normal, cast(u32)location_uv

	gl.EnableVertexAttribArray(P)
	gl.EnableVertexAttribArray(C)
	gl.EnableVertexAttribArray(N)
	gl.EnableVertexAttribArray(U)

	stride :i32= size_of(VertexPCNU)
	gl.VertexAttribPointer(P, 3, gl.FLOAT, false, stride, 0)
	gl.VertexAttribPointer(C, 4, gl.FLOAT, false, stride, 3 * size_of(f32))
	gl.VertexAttribPointer(N, 3, gl.FLOAT, false, stride, 7 * size_of(f32))
	gl.VertexAttribPointer(U, 2, gl.FLOAT, false, stride, 10 * size_of(f32))
}

Vec2 :: linalg.Vector2f32
Vec3 :: linalg.Vector3f32
Vec4 :: linalg.Vector4f32
Rect :: struct {
	x,y, w,h : f32
}

Vec2i :: distinct [2]i32
Vec3i :: distinct [3]i32
Vec4i :: distinct [4]i32

Color4u8 :: distinct [4]u8

CYAN	   :Color4u8: {0, 255, 255, 255}
MAGENTA    :Color4u8: {255, 0, 255, 255}
YELLOW	   :Color4u8: {255, 255, 0, 255}
RED		   :Color4u8: {255, 0, 0, 255}
GREEN	   :Color4u8: {0, 255, 0, 255}
BLUE	   :Color4u8: {0, 0, 255, 255}
BLACK	   :Color4u8: {0, 0, 0, 255}
WHITE	   :Color4u8: {255, 255, 255, 255}
GRAY	   :Color4u8: {169, 169, 169, 255}
DARK_GRAY  :Color4u8: {64, 64, 64, 255}
LIGHT_GRAY :Color4u8: {211, 211, 211, 255}
ORANGE	   :Color4u8: {255, 165, 0, 255}
PURPLE	   :Color4u8: {128, 0, 128, 255}
BROWN	   :Color4u8: {139, 69, 19, 255}
PINK	   :Color4u8: {255, 192, 203, 255}

vec_i2f :: proc {
	vec_i2f_2,
	vec_i2f_3,
	vec_i2f_4,
}
vec_f2i :: proc {
	vec_f2i_2,
	vec_f2i_3,
	vec_f2i_4,
}

vec_i2f_2 :: #force_inline proc "contextless" (input: Vec2i) -> Vec2 {
	return { cast(f32)input.x, cast(f32)input.y }
}
vec_i2f_3 :: #force_inline proc "contextless" (input: Vec3i) -> Vec3 {
	return { cast(f32)input.x, cast(f32)input.y, cast(f32)input.z }
}
vec_i2f_4 :: #force_inline proc "contextless" (input: Vec4i) -> Vec4 {
	return { cast(f32)input.x, cast(f32)input.y, cast(f32)input.z, cast(f32)input.w }
}

vec_f2i_2 :: #force_inline proc "contextless" (input: Vec2, method: RoundingMethod = .Floor) -> Vec2i {
	switch method {
	case .Floor: return { cast(i32)input.x, cast(i32)input.y }
	case .Ceil: return { cast(i32)math.ceil(input.x), cast(i32)math.ceil(input.y) }
	case .Nearest: return { cast(i32)math.round(input.x), cast(i32)math.round(input.y) }
	}
	return {}
}
vec_f2i_3 :: #force_inline proc "contextless" (input: Vec3, method: RoundingMethod = .Floor) -> Vec3i {
	switch method {
	case .Floor: return { cast(i32)input.x, cast(i32)input.y, cast(i32)input.z }
	case .Ceil: return { cast(i32)math.ceil(input.x), cast(i32)math.ceil(input.y), cast(i32)math.ceil(input.z)}
	case .Nearest: return { cast(i32)math.round(input.x), cast(i32)math.round(input.y), cast(i32)math.round(input.z) }
	}
	return {}
}
vec_f2i_4 :: #force_inline proc "contextless" (input: Vec4, method: RoundingMethod = .Floor) -> Vec4i {
	switch method {
	case .Floor: return { cast(i32)input.x, cast(i32)input.y, cast(i32)input.z, cast(i32)input.w, }
	case .Ceil: return { cast(i32)math.ceil(input.x), cast(i32)math.ceil(input.y), cast(i32)math.ceil(input.z), cast(i32)math.ceil(input.w)}
	case .Nearest: return { cast(i32)math.round(input.x), cast(i32)math.round(input.y), cast(i32)math.round(input.z), cast(i32)math.round(input.w) }
	}
	return {}
}
RoundingMethod :: enum {
	Floor, Ceil, Nearest,
}

col_u2f :: proc(color : Color4u8) -> Vec4 {
	return {(cast(f32)color.x)/255.0, (cast(f32)color.y)/255.0, (cast(f32)color.z)/255.0, (cast(f32)color.w)/255.0}
}
col_f2u :: proc(color : Vec4) -> Color4u8 {
	return {cast(u8)(color.x*255.0), cast(u8)(color.y*255.0), cast(u8)(color.z*255.0), cast(u8)(color.w*255.0)}
}
col_i2u :: proc(color: u32) -> Color4u8 {
	return transmute(Color4u8)color
}
col_i2f :: proc(color: u32) -> Vec4 {
	return col_u2f(transmute(Color4u8)color)
}

VertexPCU :: struct {
	position : Vec3,
	color	 : Vec4,
	uv		 : Vec2,
}

VertexPCNU :: struct {
	position : Vec3,
	color	 : Vec4,
	normal	 : Vec3,
	uv		 : Vec2,
}
