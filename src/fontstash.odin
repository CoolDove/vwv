package main

import "core:log"
import "vendor:fontstash"
import "dgl"

// implementation of fontstash using dgl

FontstashCtx :: struct {
	fs : fontstash.FontContext,
	atlas : dgl.Texture
}
fsctx : FontstashCtx

fontstash_init :: proc() {
	size := 32
	fontstash.Init(&fsctx.fs, size, size, .TOPLEFT)
	atlas := dgl.texture_create_empty(cast(i32)size, cast(i32)size, .RGBA)
	fsctx.atlas = atlas
	// img := rl.GenImageColor(cast(i32)size, cast(i32)size, {0,0,0,0}); defer rl.UnloadImage(img)
	// fsctx.atlas = rl.LoadTextureFromImage(img)

	// TODO: improve fontstash update
	fsctx.fs.userData = &fsctx
	fsctx.fs.callbackResize = proc(data: rawptr, w, h: int) {
		ctx := cast(^FontstashCtx)data
		fs := &ctx.fs
		// improve this
		buffer := make([]u8, fs.width * fs.height * 4, context.temp_allocator)
		for i in 0..<fs.width * fs.height {
			p := fs.textureData[i]
			buffer[4*i] = 255
			buffer[4*i+1] = 255
			buffer[4*i+2] = 255
			buffer[4*i+3] = p
		}
		// img := rl.Image {raw_data(buffer), auto_cast fs.width, auto_cast fs.height, 1, .UNCOMPRESSED_R8G8B8A8}
		// img := rl.GenImageColor(auto_cast fs.width, auto_cast fs.height, {0,0,0,0})
		// defer rl.UnloadImage(img)
		// ctx.atlas = rl.LoadTextureFromImage(img)
		// img := rl.Image {raw_data(buffer), auto_cast fs.width, auto_cast fs.height, 1, .UNCOMPRESSED_R8G8B8A8}
		dgl.texture_update(fsctx.atlas.id, auto_cast fs.width, auto_cast fs.height, buffer, .RGBA)
		fsctx.atlas.size.x = auto_cast fs.width
		fsctx.atlas.size.y = auto_cast fs.height
		log.debugf("resize atlas! {}\n", fsctx.atlas)
	}
	fsctx.fs.callbackUpdate = proc(data: rawptr, dirty_rect: [4]f32, texture_data: rawptr) {
		ctx := cast(^FontstashCtx)data
		fs := &ctx.fs
		// improve this
		buffer := make([]u8, fs.width * fs.height * 4); defer delete(buffer)
		for i in 0..<fs.width * fs.height {
			p := fs.textureData[i]
			buffer[4*i] = 255
			buffer[4*i+1] = 255
			buffer[4*i+2] = 255
			buffer[4*i+3] = p
		}
		// img := rl.Image {raw_data(buffer), auto_cast fs.width, auto_cast fs.height, 1, .UNCOMPRESSED_R8G8B8A8}
		dgl.texture_update(fsctx.atlas.id, auto_cast fs.width, auto_cast fs.height, buffer, .RGBA)
		log.debugf("update atlas! {}, rect: {}-({})", fsctx.atlas.id, dirty_rect, len(fs.textureData))
	}
}
fontstash_release :: proc() {
	// rl.UnloadTexture(fsctx.atlas)
	dgl.texture_destroy(fsctx.atlas)
	fontstash.Destroy(&fsctx.fs)
}

