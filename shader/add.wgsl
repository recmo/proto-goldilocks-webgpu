@group(0)
@binding(0)
var<storage, read_write> v_indices: array<u32>; // this is used as both input and output for convenience

fn iterations(n_base: u32) -> u32{
    var n: u32 = n_base;
    var a: u32 = 0u;
    var b: u32 = 1u;
    loop {
        if (n <= 1u) {
            break;
        }
        var t: u32 = (a + b) % 65521u;
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
