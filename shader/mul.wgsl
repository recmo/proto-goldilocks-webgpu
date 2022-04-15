@group(0)
@binding(0)
var<storage, read_write> v_indices: array<vec2<u32>>; // this is used as both input and output for convenience

// Compute the top 32 bit of the addition
fn addh(a: u32, b: u32) -> u32 {
    return (a >> 1u) + (b >> 1u) + ((a & b) & 1u);
}

fn addc32(a: u32, b: u32) -> vec2<u32> {
    var r = vec2<u32>(a + b, 0u);
    if (r.x < a) {
        r.y = 1u;
    }
    return r;
}

fn addc64(a: vec2<u32>, b: vec2<u32>) -> vec3<u32> {
    var r = vec3<u32>(a + b, 0u);
    if (r.x < a.x) {
        r.y += 1u;
    }
    if (r.y < a.y || (r.y == a.y && r.x < a.x)) {
        r.z = 1u;
    }
    return r;
}

// See <https://github.com/intel/llvm/blob/54ede407edeb93b7e9334d1e725f48bf981b2965/sycl/source/detail/builtins_integer.cpp>
fn mul64(a: u32, b: u32) -> vec2<u32> {
    // Split into 16 bit parts
    var a0 = (a << 16u) >> 16u;
    var a1 = a >> 16u;
    var b0 = (b << 16u) >> 16u;
    var b1 = b >> 16u;

    // Compute 32 bit half products
    // Each of these is at most 0xfffe0001
    var a0b0 = a0 * b0;
    var a0b1 = a0 * b1;
    var a1b0 = a1 * b0;
    var a1b1 = a1 * b1;

    // Sum the half products
    var r: vec2<u32>;
    r.x = a0b0 + (a1b0 << 16u) + (a0b1 << 16u);
    r.y = a1b1 + (addh((a0b0 >> 16u) + a0b1, a1b0) >> 15u);
    return r;
}

fn mul128(a: vec2<u32>, b: vec2<u32>) -> vec4<u32> {
    // Compute 64 bit half products
    // Each of these is at most 0xfffffffe00000001
    var a0b0 = mul64(a.x, b.x);
    var a0b1 = mul64(a.x, b.y);
    var a1b0 = mul64(a.y, b.x);
    var a1b1 = mul64(a.y, b.y);

    var r = vec4<u32>(a0b0, a1b1);

    // Add a0b1
    r.y += a0b1.x;
    if (r.y < a0b1.x) {
        a0b1.y += 1u; // Can not overflow
    }
    r.z += a0b1.y;
    if (r.z < a0b1.y) {
        r.w += 1u;
    }

    // Add a1b0
    r.y += a1b0.x;
    if (r.y < a1b0.x) {
        a1b0.y += 1u; // Can not overflow
    }
    r.z += a1b0.y;
    if (r.z < a1b0.y) {
        r.w += 1u;
    }

    return r;
}

/// See <https://github.com/mir-protocol/plonky2/blob/main/field/src/goldilocks_field.rs#L327>
fn reduce(n: vec4<u32>) -> vec2<u32> {
    // Compute 
    // n.x + n.y * 2^32 + n.z * 2^64 + n.w * 2^96 mod 2^64 - 2^32 + 1
    // which equals
    // n.x - n.z - n.w + (n.y + n.z) * 2^32 mod 2^64 - 2^32 + 1

    var r = n.xy;
    r.x -= n.z;
    r.x -= n.w;
    r.y += n.z;

    return vec2<u32>(0u, 0u);
}

fn factorial(n: vec2<u32>) -> vec2<u32> {
    var i = vec2<u32>(2u, 0u);
    var r = vec2<u32>(1u, 0u);
    loop {
        if (i.x > n.x) {
            break;
        }
        var p = mul128(r, i);
        r = p.xy ^ p.zw;
        i.x += 1u;
    }
    return r;
}

@stage(compute)
@workgroup_size(1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    v_indices[global_id.x] = factorial(v_indices[global_id.x]);
}
