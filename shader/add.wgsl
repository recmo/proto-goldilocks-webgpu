@group(0)
@binding(0)
var<storage, read_write> v_indices: array<vec2<u32>>; // this is used as both input and output for convenience

fn iterations(n_base: vec2<u32>) -> vec2<u32> {
    var n: u32 = n_base[0];
    var a: vec2<u32> = vec2<u32>(0u, 0u);
    var b: vec2<u32> = vec2<u32>(1u, 0u);
    loop {
        if (n <= 1u) {
            break;
        }
        var t: vec2<u32> = a + b;
        if (t.x < a.x) {
            t.y += 1u;
        }
        if (t.y < a.y) {
            t.x -= 1u;
            if (t.x < 0xffffffffu) {
                t.y += 1u;
            }
        }
        a = b;
        b = t;
        n -= 1u;
    }
    return b;
}

@stage(compute)
@workgroup_size(1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    v_indices[global_id.x] = iterations(v_indices[global_id.x]);
}
