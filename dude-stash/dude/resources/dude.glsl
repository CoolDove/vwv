layout(std140, binding = 0) uniform Camera {
    vec2 position;
    float angle;
    float size;
    vec2 viewport;
} camera;

layout(std140, binding = 1) uniform Dude {
    float time_total;
    float padding;
} dude;

uniform vec2 transform_position;
uniform vec2 transform_scale;
uniform float transform_angle;

uniform vec4 ex;
// ** ex
// vertex_color_on : f32,
// screen_space : f32,
// padding1 : f32,
// padding2 : f32,

vec2 transform_point_local2world(vec2 point, vec2 position, vec2 scale, float angle) {
    vec2 p = point;
    p = p * scale;
    float sa = sin(angle);
    float ca = cos(angle);
    p = vec2(p.x * ca + p.y * sa, p.y * ca - p.x * sa);
    return p + vec2(1,-1)*position;
}

// This actually transform the point into ndc, this is a 2D game engine, so just be simple to deal
//  with camera projection things.
vec2 transform_point_world2camera(vec2 point) {
    vec2 p = point;
    p = p + vec2(-1,1) * camera.position;
    float sa = sin(-camera.angle);
    float ca = cos(-camera.angle);
    p = vec2(p.x * ca + p.y * sa, p.y * ca - p.x * sa);
    vec2 scale = vec2(camera.size/camera.viewport.x, camera.size/camera.viewport.y);
    p = p*scale;
    return p;
}

vec2 transform_screen2ndc(vec2 point) {
    return (2 * (point/camera.viewport) - vec2(1,1));// * vec2(1,-1);
}

// Transform as world point if ex.y is 0, as screen point if ex.y is 1.
vec2 transform_point(vec2 point) {
    vec2 wpos = transform_point_local2world(point, transform_position, transform_scale, transform_angle);
    wpos = transform_point_world2camera(wpos);

    vec2 spos = transform_screen2ndc(point);
    return mix(wpos, spos, ex.y);
}

vec2 transform_unit_quad_as_sprite(vec2 point, vec2 anchor, vec2 size) {
    return (point - anchor) * size;
}