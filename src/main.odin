package main

import "core:time"
import "core:os"
import "core:fmt"
import "core:unicode/utf8"
import "core:log"
import "core:reflect"
import "core:strings"
import "core:math/linalg"
import "core:math"

import sdl "vendor:sdl2"
import ma "vendor:miniaudio"

import "dude"
import "dude/dpac"
import "dude/dgl"
import mui "dude/microui"
import hla "dude/collections/hollow_array"

REPAC_ASSETS :: false

pass_main : dude.RenderPass

TheTool :: struct {
    mesh_grid : dgl.Mesh,
    // player : dude.RObjHandle,

    // test_mesh_triangle, mesh_grid, mesh_arrow : dgl.Mesh,
    // tm_test : dgl.Mesh,

    // robj_message : dude.RObjHandle,
    // message_color : dude.Color,

    // book : []rune,
    // book_ptr : int,

    // asset_pacbuffer : []u8,

    // dialogue_size : f32,
}

@(private="file")
the_tool : TheTool

main :: proc() {
    // ** Load dpacs
    // if REPAC_ASSETS {
    //     bundle_err : dpac.BundleErr
    //     demo_game.asset_pacbuffer, bundle_err = dpac.bundle(GameAssets)
    //     if bundle_err != .None {
    //         fmt.eprintf("bundle err: {}\n", bundle_err)
    //     } else {
    //         os.write_entire_file("./GameAssets.dpac", demo_game.asset_pacbuffer)
    //     }
    // } else {
    //     demo_game.asset_pacbuffer, _ = os.read_entire_file("./GameAssets.dpac")
    // }
    // defer delete(demo_game.asset_pacbuffer)
    
	dude.init(dude.WindowInitializer{"vwv - simple tool for simple soul", {sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED}, {400,860}, {.RESIZABLE}, vwv_window_handler}, true)
    dude.dude_main(update, init, release, on_mui)
}

@(private="file")
update :: proc(game: ^dude.Game, delta: f32) {
    using dude, the_tool
    // @static time : f32 = 0
    // time += delta

    viewport := app.window.size
    pass_main.viewport = Vec4i{0,0, viewport.x, viewport.y}
    pass_main.camera.viewport = vec_i2f(viewport)

    vwv_update()

    // pass_main.camera.angle = 0.06 * math.sin(time*0.8)
    // // pass_main.camera.size = 60 + 6 * math.sin(time*1.2)

    // camera := &pass_main.camera
    // t := dude.render_pass_get_object(player)
    // move_speed :f32= 3.0
    // if get_key(.A) do t.position.x -= move_speed * delta
    // else if get_key(.D) do t.position.x += move_speed * delta
    // if get_key(.W) do t.position.y += move_speed * delta
    // else if get_key(.S) do t.position.y -= move_speed * delta
    // pass_main.camera.position = t.position
    
    // if get_key_down(.H) do dude.audio_play(&assets.sfx.hit.clip)
    // if get_key_down(.K) do dude.audio_clip_set_frame(&assets.bgm_hotel_california.clip, 0)

    // if get_key(.F) {
    //     _flip_page()
    // }

    // if !get_mui_hovering() && get_mouse_button_down(.Left)  {
    //     if demo_game.dialogue_size == 0 {
    //         dude.tween(&game.global_tweener, &demo_game.dialogue_size, 1.0, 0.3, dude.ease_outcubic)
    //     } else if demo_game.dialogue_size == 1 {
    //         dude.tween(&game.global_tweener, &demo_game.dialogue_size, 0.0, 0.3, dude.ease_outcubic)
    //     }
    // }

    // {
    //     msg := dude.render_pass_get_object(robj_message)
    //     msg.position.x = -5
    // }

    // dude.imdraw.quad(&pass_main, get_mouse_position()-{8,8}, {16,16}, texture=assets.qq.id)

    // to_screen :: proc(pos: dude.Vec2) -> dude.Vec2 {
    //     return dude.coord_world2screen(&pass_main.camera, pos)
    // }

    // imdraw.quad(&pass_main, to_screen({0,0}), {16,16}, texture=assets.qq.id, color=COL32_RED)
    // imdraw.quad(&pass_main, to_screen({5,0}), {16,16}, texture=assets.qq.id, color=COL32_GREEN)
    // imdraw.quad(&pass_main, to_screen({10,0}), {16,16}, texture=assets.qq.id, color=COL32_BLUE)
    // imdraw.quad(&pass_main, to_screen({0,5}), {16,16}, texture=assets.qq.id)
    // imdraw.quad(&pass_main, to_screen({0,10}), {16,16}, texture=assets.qq.id)

    // {// test arrow
    //     root := to_screen({0,0})
    //     forward := to_screen({0, 5}) - root
    //     right := dude.rotate_vector(forward, 90 * math.RAD_PER_DEG)
    //     imdraw.arrow(&pass_main, 
    //         root,
    //         root + forward,
    //         16.0, {200, 64, 32, 222})
    //     imdraw.arrow(&pass_main, 
    //         root,
    //         root + right,
    //         16.0, {32, 230, 20, 222})
    // }

    // if demo_game.dialogue_size > 0 {
    //     dialogue("Hello, Dove!\nThis will be a long line.", get_mouse_position(), {256, 128} * demo_game.dialogue_size, demo_game.dialogue_size)
    // }

    // for x in 0..<5 {
    //     x := cast(f32)x
    //     imdraw.text(&pass_main, dude.render.system.font_unifont, fmt.tprintf("{}", x), to_screen({x,0}), 20, order=999999)
    // }
    // for y in 0..<5 {
    //     y := cast(f32)y
    //     imdraw.text(&pass_main, dude.render.system.font_unifont, fmt.tprintf("{}", y), to_screen({0,y}), 20, order=999999)
    // }
}

// dialogue :: proc(message : string, anchor, size: dude.Vec2, alpha:f32) {
//     padding :dude.Vec2= {64,64}
//     size := linalg.max(padding, size)
//     t := cast(f32)dude.game.time_total
//     t = (math.sin(t * 2) + 1) * 0.5
//     t = t * 0.8 + 0.2
//     using dude.imdraw
//     quad_9slice(&pass_main, anchor+{4-2*t,4-2*t}, size, size-padding, {0.5,0.5}, 
//         color={0,0,0,cast(u8)(128*alpha)}, texture=assets.bg9slice.id, order=100)
//     quad_9slice(&pass_main, anchor, size, size-padding, {0.5,0.5}, 
//         texture=assets.bg9slice.id, order=101, color={255,255,255, cast(u8)(alpha*255.0)})
//     msg := message[:cast(int)(alpha*cast(f32)len(message))]
//     fontsize :f32= 32 * alpha
//     font := assets.font_inkfree.font
//     text(&pass_main, font, msg, anchor + {16,37}, fontsize, {0.1, 0.1, 0.1, 0.4*dude.ease_outcubic(alpha)}, region=size-{40,0}, order=102)
//     text(&pass_main, font, msg, anchor + {15,36}, fontsize, {0.2, 0.2, 0.2, dude.ease_outcubic(alpha)}, region=size-{40,0}, order=103)
// }

@(private="file")
init :: proc(game: ^dude.Game) {
    using the_tool
    append(&game.render_pass, &pass_main)

    {// ** Build meshes.
        // using dgl
        // mb := dude.render.get_temp_mesh_builder()
        
        // mesh_builder_reset(mb, VERTEX_FORMAT_P2U2C4)
        // dude.mesher_line_grid_lp2u2c4(mb, 20, 1.0, {0.18,0.14,0.13, 1}, 5, {0.1,0.04,0.09, 1})
        // mesh_grid = mesh_builder_create(mb^, true) // Because the mesh is a lines mesh.

        // texture_set_filter(assets.bg9slice.id, .Nearest, .Nearest)
    }

    using dude
    // Pass initialization
    wndx, wndy := app.window.size.x, app.window.size.y
    render_pass_init(&pass_main, {0,0, wndx, wndy})
    pass_main.clear.color = {.2,.2,.2, 1}
    pass_main.clear.mask = {.Color,.Depth,.Stencil}
    blend := &pass_main.blend.(dgl.GlStateBlendSimp)
    blend.enable = true

    // render_pass_add_object(&pass_main, RObjMesh{mesh=mesh_grid, mode=.Lines}, order=-9999, vertex_color_on=true)

    vwv_init()

}

@(private="file")
release :: proc(game: ^dude.Game) {
    vwv_release()
    // dpac.release(&assets, type_info_of(GameAssets))
    
    // delete(demo_game.book)
    // dgl.mesh_delete(&demo_game.tm_test)

    using dude, the_tool
	// dgl.mesh_delete(&test_mesh_triangle)
	dgl.mesh_delete(&mesh_grid)

    render_pass_release(&pass_main)
}

@(private="file")
on_mui :: proc(ctx: ^mui.Context) {
    // if mui.window(ctx, "Hello, mui", {50,50, 300, 400}, {.NO_CLOSE}) {
        // t := dude.render_pass_get_object(demo_game.player)

        // mui.slider(ctx, &pass_main.camera.size, 10, 100, 1, "cam size: %.2f")

        // mui.text(ctx, fmt.tprintf("player position: {}", t.position))
        // mui.text(ctx, fmt.tprintf("screen space root: {}", pass_main.camera.position))
        // if .ACTIVE in mui.treenode(ctx, "Treenode") {
        //     using dude
        //     @static box := false
        //     mui.layout_row(ctx, {256}, 256)
        //     muix.image(ctx, dude.render.system.fontstash_data.atlas, col_i2u(0xffffffff))
        // }
        
        // if .ACTIVE in mui.treenode(ctx, "Tween") {
        //     iterator : hla.HollowArrayIterator
        //     for tween in hla.hla_ite(&dude.game.global_tweener.tweens, &iterator) {
        //         interp := tween.time/tween.duration
        //         container := mui.get_current_container(ctx)
        //         mui.layout_row(ctx, {60, -1}, 12)
        //         mui.label(ctx, fmt.tprintf("dimen: {}", tween.dimension))
        //         v :f32= tween.time/tween.duration
        //         mui.slider(ctx, &v, 0, 1, 0.1)
        //     }
        // }
    // }
}