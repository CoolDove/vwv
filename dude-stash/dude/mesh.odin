package dude


import "dgl"
import "core:math/linalg"
import "core:math"


// anchor: x: [0,1], y: [0,1]
mesher_quad_p2u2 :: proc(mb: ^dgl.MeshBuilder, size, anchor: Vec2, offset:Vec2={0,0}, uv_min:Vec2={0,0},uv_max:Vec2={1,1}) {
    assert(mb.vertex_format == dgl.VERTEX_FORMAT_P2U2, "Mesher: Only P2U2 format is supported.")
    idx := cast(u32)len(mb.vertices)/4
    min := -anchor * size + offset
    max := (1-anchor) * size + offset
    dgl.mesh_builder_add_vertices(mb, 
        {v4={min.x,min.y, uv_min.x, uv_min.y}},
        {v4={max.x,min.y, uv_max.x, uv_min.y}},
        {v4={min.x,max.y, uv_min.x, uv_max.y}},
        {v4={max.x,max.y, uv_max.x, uv_max.y}},
    )
    dgl.mesh_builder_add_indices(mb, idx+0,idx+1,idx+2, idx+1,idx+3,idx+2)
}

mesher_quad_p2u2c4 :: proc(mb: ^dgl.MeshBuilder, size, anchor: Vec2, offset:Vec2={0,0}, uv_min:Vec2={0,0},uv_max:Vec2={1,1}, 
/**/colors: [4]Color= {}, 
/**/transform:linalg.Matrix3f32=1) {
    assert(mb.vertex_format == dgl.VERTEX_FORMAT_P2U2C4, "Mesher: Only P2U2C4 format is supported.")
    idx := cast(u32)len(mb.vertices)/8
    min := -anchor * size + offset
    max := (1-anchor) * size + offset
	a :Vec3= {min.x,min.y, 1}
	b :Vec3= {max.x,min.y, 1}
	c :Vec3= {min.x,max.y, 1}
	d :Vec3= {max.x,max.y, 1}
	a,b,c,d = transform*a, transform*b, transform*c, transform*d
    dgl.mesh_builder_add_vertices(mb, 
        {v8={a.x,a.y, uv_min.x, uv_min.y, colors[0].r, colors[0].g, colors[0].b, colors[0].a}},
        {v8={b.x,b.y, uv_max.x, uv_min.y, colors[1].r, colors[1].g, colors[1].b, colors[1].a}},
        {v8={c.x,c.y, uv_min.x, uv_max.y, colors[2].r, colors[2].g, colors[2].b, colors[2].a}},
        {v8={d.x,d.y, uv_max.x, uv_max.y, colors[3].r, colors[3].g, colors[3].b, colors[3].a}},
    )
    dgl.mesh_builder_add_indices(mb, idx+0,idx+1,idx+2, idx+1,idx+3,idx+2)
}

mesher_line_grid_lp2u2c4 :: proc(mb: ^dgl.MeshBuilder, half_size:int, unit: f32, color: Color, subcell_size := 0, color_b := Color{1,0,1,1}) {
    assert(mb.vertex_format == dgl.VERTEX_FORMAT_P2U2C4, "Mesher: Only P2U2C4 format is supported.")
    // You should reset mesh builder before this
    size := 2 * half_size
    min := -cast(f32)half_size * unit;
    max := cast(f32)half_size * unit;

    col : Color
    for i in 0..=size {
        x := min + cast(f32)i * unit
        col = color_b if subcell_size != 0 && i % subcell_size == 0 else color
        dgl.mesh_builder_add_vertices(mb, 
            {v8={x,min, 0,0, col.r,col.g,col.b,col.a}},
            {v8={x,max, 0,0, col.r,col.g,col.b,col.a}})
    }
    for i in 0..=size {
        y := min + cast(f32)i * unit
        col = color_b if subcell_size != 0 && i % subcell_size == 0 else color
        dgl.mesh_builder_add_vertices(mb, 
            {v8={min,y, 0,0, col.r,col.g,col.b,col.a}},
            {v8={max,y, 0,0, col.r,col.g,col.b,col.a}})
    }
}

mesher_arrow_p2u2c4 :: proc(mb: ^dgl.MeshBuilder, from,to: Vec2, width: f32, color: Color) {
    assert(mb.vertex_format == dgl.VERTEX_FORMAT_P2U2C4, "Mesher: Only P2U2C4 format is supported.")
    idx := cast(u32)len(mb.vertices)/8

    forward := to-from
    forwardn := linalg.normalize(forward)
    left := forward
    {
        sa :f32= math.sin_f32(90.0* math.RAD_PER_DEG)
        ca :f32= math.cos_f32(90.0* math.RAD_PER_DEG)
        left = Vec2{ forward.x * ca + forward.y * sa, forward.y * ca - forward.x * sa };
    }
    leftn := linalg.normalize(left)

    length := linalg.length(forward)
    stick_w := width * 0.2
    arrow_l := width * 1.4
    arrow_l = math.min(arrow_l, length)
    stick_l := length - arrow_l

    c := color

    pa  := from + 0.5 * stick_w * leftn
    paa := from - 0.5 * stick_w * leftn

    pb := pa + stick_l * forwardn + 0.5 * width * leftn
    pc := pa + stick_l * forwardn + 0.5 * stick_w * leftn

    pd := pa + stick_l * forwardn - 0.5 * stick_w * leftn
    pe := pa + stick_l * forwardn - 0.5 * width * leftn

    pf := pa + forward
    
    dgl.mesh_builder_add_vertices(mb, 
        {v8={pa.x,pa.y, 0,0, c.r,c.g,c.b,c.a}},
        {v8={pb.x,pb.y, 0,0, c.r,c.g,c.b,c.a}},
        {v8={pc.x,pc.y, 0,0, c.r,c.g,c.b,c.a}},
        {v8={pd.x,pd.y, 0,0, c.r,c.g,c.b,c.a}},
        {v8={pe.x,pe.y, 0,0, c.r,c.g,c.b,c.a}},
        {v8={pf.x,pf.y, 0,0, c.r,c.g,c.b,c.a}},
        {v8={paa.x,paa.y, 0,0, c.r,c.g,c.b,c.a}},
    )
    dgl.mesh_builder_add_indices(mb, 
        idx+0,idx+2,idx+3,
        idx+0,idx+3,idx+6,
        idx+1,idx+5,idx+2,
        idx+2,idx+5,idx+3,
        idx+3,idx+5,idx+4,
    )
}
