const std = @import("std");
const ui = @import("./src/index.zig");

const Configuration = struct {
    fullscreen: bool = false,
    samples: usize = 10,
    threads: usize = 0,
};

var cfg = Configuration {};
var rand = std.rand.DefaultPrng.init(0);
var is_rendering = true;
var last_present: i64 = 0;
const starting_k = 64;
var progress_x: i32 = 0;
var progress_y: i32 = 0;
var progress_k: i32 = starting_k;

pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) @panic("TEST FAIL");
    }

    try parseCliArguments(allocator, &cfg);
    
    var canvas = ui.Canvas32.initAllocEmpty(allocator);
    defer canvas.deinit();

    var window = ui.Window.init(.{ .fullscreen = cfg.fullscreen, .title = "Pathtracer" });
    defer window.deinit();


    while (true) {
        while (ui.nextEvent(.{ .blocking = !is_rendering })) |event| {
            switch (event) {
                .closewindow => return,
                .paint => {
                    progress_k = starting_k;
                    progress_x = 0;
                    progress_y = 0;
                    is_rendering = true;
                },
                .resize => |size| {
                    if (size.width != canvas.width or size.height != canvas.height)
                    {
                        try canvas.reallocate(size.width, size.height);
                        is_rendering = true;
                        canvas.clear(0);
                        ui.presentCanvas32(window, canvas);
                    }
                },
                .keydown => |key| {
                    switch (key) {
                        .escape => return,
                        else => {},
                    }
                },
                else => {},
            }
        }

        if (cfg.threads > 0)
        {
            try multithreadedRenderer(allocator, window, &canvas);
        }
        else {
            progressiveRendererer(window, &canvas);
        }
        
    }
}

fn multithreadedRenderer(allocator: std.mem.Allocator, window: ui.Window, canvas: *ui.Canvas32) !void {
    
    if (!is_rendering){
        return;
    }

    var threads = try allocator.alloc(std.Thread, @max(1, cfg.threads));
    defer allocator.free(threads);
    canvas.clear(0);
    ui.presentCanvas32(window, canvas.*);

    // fork-join style multithreading

    for (0..cfg.threads) |i| {
        const y0 = canvas.height * i / cfg.threads;
        const y1 = (canvas.height * (i + 1)) / cfg.threads;
        threads[i] = try std.Thread.spawn(.{}, threadFn, .{canvas, y0, y1});
    }

    for (0..cfg.threads) |i| {
        threads[i].join();
    }

    is_rendering = false;
    ui.presentCanvas32(window, canvas.*);
}

fn progressiveRendererer(window: ui.Window, canvas: *ui.Canvas32) void {
    var x = progress_x;
    var y = progress_y;
    var k = progress_k;
    
    if (x > canvas.width) {
        x = 0; y += k+k;
    }

    if (y > canvas.height) {
        x = 0;
        y = 0;
        k = @divFloor(k,2);

        if (k == 0) {
            is_rendering = false;
            ui.presentCanvas32(window, canvas.*);
        }
    }

    for (0..100) |i| {
        _ = i;
        if (k > 0)
        {
            if (k == starting_k) 
            {
                canvas.rect(x,y,x+k,y+k, renderPixel(x, y, canvas.width, canvas.height));
            }
            y += k;
            canvas.rect(x,y,x+k,y+k, renderPixel(x, y, canvas.width, canvas.height));
            x += k;
            canvas.rect(x,y,x+k,y+k, renderPixel(x, y, canvas.width, canvas.height));
            y -= k;
            canvas.rect(x,y,x+k,y+k, renderPixel(x, y, canvas.width, canvas.height));
            x += k;
        }

    }

    var now = @divFloor(std.time.milliTimestamp(), 100);
    if (last_present != now)
    {
        last_present = now;
        ui.presentCanvas32(window, canvas.*);
    }

    progress_x = x;
    progress_y = y;
    progress_k = k;
}

fn parseCliArguments(allocator: std.mem.Allocator, c: *Configuration) !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var parse_samples = false;
    var parse_threads = false;

    for (args) |arg| {
        if (parse_samples) {
            parse_samples = false;
            c.samples = try std.fmt.parseInt(usize, arg, 10);
        }
        else if (parse_threads) {
            parse_threads = false;
            c.threads = try std.fmt.parseInt(usize, arg, 10);
        }
        else if (std.mem.eql(u8, arg, "--fullscreen")) {
            c.fullscreen = true;
        }
        else if (std.mem.eql(u8, arg, "--samples")){
            parse_samples = true;
        }
        else if (std.mem.eql(u8, arg, "--threads")) {
            parse_threads = true;
        }
    }
}

fn threadFn(canvas: *ui.Canvas32, y0: usize, y1: usize) void {
    for (y0..y1) |y| {
        const row = canvas.row(y);
        for (0..canvas.width) |x| {
            const pixel = renderPixel(@intCast(x), @intCast(y), canvas.width, canvas.height);
            row[x] = pixel;
        }
    }
}

fn renderPixel(ix: i32, iy: i32, width: usize, height: usize) u32 {

    var cix = ix; cix -= @intCast(width/2);
    var ciy = iy; ciy -= @intCast(height/2);
    
    var frag_coord = vec2{ @floatFromInt(ix), @floatFromInt(iy) };
    _ = frag_coord;
    var centerd_coord = vec2{ @floatFromInt(cix), @floatFromInt(ciy) };
    var size: f32 = @floatFromInt(@min(width, height));
    var uv = centerd_coord / vec2{ size, size };

    //var color = plasma(uv + vec2{1,1});
    var color = vec3{0,0,0};
    const maxSample = cfg.samples;
    for (0..maxSample) |sample| 
    {
        _ = sample;
        const s = 1/size;
        const noise = vec2{ randF32(-s, s), randF32(-s,s) };
        color += raytrace(uv + noise);
    }
    color /= splat3(@floatFromInt(maxSample));
    color = @max(vec3{0,0,0}, color);
    color = splat3(1.4) * color / (splat3(1) + color);
    color = @sqrt(color);
    color = @min(vec3{1,1,1}, color);

    var byte_r: u8 = @intFromFloat(color[0] * 0xff);
    var byte_g: u8 = @intFromFloat(color[1] * 0xff);
    var byte_b: u8 = @intFromFloat(color[2] * 0xff);

    return ui.color32bgra.makeColor32bgra(byte_r, byte_g, byte_b, 255);
}

fn plasma(uv: vec2) vec3 
{
    var color = vec3{ uv[0], uv[1], @sin(uv[0]*4) };
    for (0..2)|i| {
        _ = i;
    
        color = (color + @sin(vec3{color[1]*4, color[2]*4, color[0]*4})) / vec3{2,2,2};
    }
    color = @max(vec3{0,0,0}, @min(vec3{1,1,1}, color));
    return color;
}

fn raytrace(uv: vec2) vec3 {

    const camera = Ray { 
        .origin = vec3{0,0,-4}, 
        .dir = normalize(vec3{uv[0], uv[1], 1}), 
    };

    const scene: [6]SceneObject = .{
        //SceneObject { .sphere = Sphere { .center = vec3{0,0.5,-1}, .radius = 0.5,} }, 
        SceneObject { .sphere = Sphere { .center = vec3{1.5,0.5,2}, .radius = 0.5,} }, 
        SceneObject { 
            .plane = Plane {
                .normal = vec3{0, 1, 0},
                .point = vec3{0, 1, 0},
            }
        },
        SceneObject {
            .cube = Cube.fromLocationSize(vec3{-2,1,0}, vec3{1,1,1}),
        },
        SceneObject {
            .cube = Cube.fromLocationSize(vec3{0,-2,4}, vec3{16,8,1}),
        },
        SceneObject {
            .cube = Cube.fromLocationSize(vec3{-4,-2,5}, vec3{1,8,8}),
        },
        SceneObject {
            .cube = Cube.fromLocationSize(vec3{3,-2,0}, vec3{1,8,2}),
        }
    };
    
    const light = Cube.fromLocationSize(vec3{4,-2,0.9}, vec3{0.1,0.1,0.1});
    const light_pos = light.getRandomPos();

    var accum = vec3 {0,0,0};
    var ray: Ray = camera;
    
    const max_bounce = 4;

    for (0..max_bounce) |bounce_index| {


        if ( intersect.rayScene(ray, &scene)) |hit| {

            var light_distance = length(light_pos - hit.position);
            var light_dir = normalize(light_pos - hit.position);
            var diffuse = dot(hit.normal, light_dir);
            diffuse = @max(0, diffuse);

            var occlusion: f32 = 1.0;

            var fresnel = schlickApproximation(dot(-ray.dir, hit.normal), 0.1);
            if (bounce_index + 1 == max_bounce) {
                fresnel = 1;
            }
            //return vec3{fresnel, fresnel, fresnel};
            // if (randF32(0, 1) > fresnel) {
            //     return vec3{1,0,0};
            // }
            // else {
            //     return vec3{0,1,1};
            // }
            if (randF32(0, 1) > fresnel) {
                // diffuse bounce

                if (intersect.rayScene(Ray { .origin = hit.position, .dir = light_dir }, &scene)) |shadow_hit| {
                    if (light_distance < shadow_hit.distance) {
                        occlusion = 1.0;
                    } else {
                        occlusion = 0.0;
                    }
                }

                accum += splat3(diffuse * occlusion);

                ray = Ray {
                    .origin = hit.position,
                    .dir = randHemiDir(hit.normal),
                };
            }
            else {
                // specular bounce
                const reflection = reflect(ray.dir, hit.normal);
                ray = Ray {
                    .origin = hit.position,
                    .dir = normalize(reflection + randHemiDir(reflection) * splat3(0.1)),
                };
            }


        } else {
            break;
        }
    }

    return accum;
}

const Ray = struct {
    origin: vec3,
    dir: vec3,

    fn getPositionAt(r: Ray, t: f32) vec3 { return r.origin + r.dir * splat3(t); }
};

const Sphere = struct {
    center: vec3,
    radius: f32,

    fn getNormalAt(s: Sphere, p: vec3) vec3 { return normalize(p - s.center); }
};

const Cube = struct {
    min: vec3,
    max: vec3,

    fn fromLocationSize(location: vec3, size: vec3) Cube {
        const half = size * splat3(0.5);
        return Cube {
            .min = location - half,
            .max = location + half,
        };
    }

    fn getNormalAt(c: Cube, p: vec3) vec3 {
        const epsilon = 1e-6;
        var result = vec3 {0,0,0};
        for (0..3) |i| {
            if (p[i] <= c.min[i] + epsilon) {
                result[i] = -1;
                break;
            }
            else if (p[i] >= c.max[i] - epsilon) 
            {
                result[i] = 1;
                break;
            }
        }
        return result;
    }

    fn getRandomPos(cube: Cube) vec3 {
        return vec3 {
            randF32(cube.min[0], cube.max[0]),
            randF32(cube.min[1], cube.max[1]),
            randF32(cube.min[2], cube.max[2]),
        };
    }
};

fn randHemiDir(normal: vec3) vec3 {
    return normalize(randHemi(normal));
}   

fn randHemi(normal: vec3) vec3 {
    const pos = randSphere();
    if (dot(pos, normal) < 0) {
        return -pos;
    }
    return pos;
}

fn randSphere() vec3 {
    const box = Cube{ .min = vec3{-1,-1,-1}, .max = vec3{1,1,1} };
    var pos: vec3 = undefined;
    for (0..10) |i| {
        _ = i;
        pos = box.getRandomPos();
        if (lengthSquared(pos) < 1) {
            return pos;
        }
    }
    return pos;
}

fn randF32(min: f32, max: f32) f32 {
    var value = rand.next();
    var f: f32 = @floatFromInt(value);
    var l: f32 = @floatFromInt(std.math.maxInt(u64));
    f /= l;
    f = f * (max - min) + min;
    return f;
}

const Plane = struct {
    normal: vec3,
    point: vec3,
};

const SceneObjectType = enum {
    sphere,
    plane,
    cube,
};

const SceneObject = union(SceneObjectType) {
    sphere: Sphere,
    plane: Plane,
    cube: Cube,
};

inline fn normalize(v: vec3) vec3 { return v / splat3(length(v)); }
inline fn splat3(s: f32) vec3 { return vec3 { s,s,s }; }
inline fn length(v: vec3) f32 { return @sqrt(lengthSquared(v)); }
inline fn lengthSquared(v: vec3) f32 { return dot(v,v); }
inline fn dot(a: vec3, b: vec3) f32 { return @reduce(.Add, a*b); }

inline fn reflect(v: vec3, normal: vec3) vec3 {
    return v - splat3(dot(v, normal) * 2) * normal;
}

inline fn pow5(base: f32) f32 {
    const base2 = base * base;
    return base2 * base2 * base;
}

inline fn schlickApproximation(cosTheta: f32, reflectanceAtNormal: f32) f32 {
    const R0: f32 = reflectanceAtNormal;
    return R0 + (1.0 - R0) * pow5(1.0 - cosTheta);
}

const HitInformation = struct {
    normal: vec3,
    position: vec3,
    distance: f32,
};

const intersect = struct {

    fn raySphere(ray: Ray, sphere: Sphere) ?f32 {
        const oc: vec3 = ray.origin - sphere.center;
        const a: f32 = lengthSquared(ray.dir);
        const b: f32 = 2.0 * dot(oc, ray.dir);
        const c: f32 = lengthSquared(oc) - sphere.radius * sphere.radius;
        const discriminant: f32 = b * b - 4.0 * a * c;

        if (discriminant < 0.0) {
            // No intersection
            return null;
        }

        const sqrt_discriminant = @sqrt(discriminant);

        const t1: f32 = (-b - sqrt_discriminant) / (2.0 * a);
        const t2: f32 = (-b + sqrt_discriminant) / (2.0 * a);

        const epsilon: f32 = 1e-3;

        if (t1 >= epsilon)
        {
            if (t2 >= epsilon)
            {
                if (t1 < t2) {
                    return t1;    
                }
                else {
                    return t2;
                }
            }
        }
        else if (t2 >= epsilon)
        {
            return t2;
        }
        return null;
    }

    fn rayPlane(ray: Ray, plane: Plane) ?f32 {
        const epsilon = 1e-6;
        var denominator: f32 = dot(plane.normal, ray.dir);
        var abs_denom = denominator;
        if (abs_denom < denominator) {
            abs_denom = -denominator;
        }

        if (abs_denom > epsilon) {
            const t: f32 = dot(plane.point - ray.origin, plane.normal) / denominator;

            if (t >= 0.0) {
                return t; 
            }
        }

        // No intersection
        return null;
    }

    fn rayScene(ray: Ray, scene: []const SceneObject) ?HitInformation {

        var t_min: f32 = 1e9;
        var hit = false;
        var hit_normal: vec3 = undefined;
        var hit_position: vec3 = undefined;

        for (scene) |obj| {
            switch (obj) {
                .sphere => |s| {
                    if (intersect.raySphere(ray, s)) |t| {
                        if (t < t_min) {
                            hit = true;
                            t_min = t;
                            hit_position = ray.getPositionAt(t);
                            hit_normal = s.getNormalAt(hit_position);
                        }
                    }
                },
                .plane => |p| {
                    if (intersect.rayPlane(ray, p)) |t| {
                        if (t < t_min) {
                            hit = true;
                            t_min = t;
                            hit_position = ray.getPositionAt(t);
                            hit_normal = -p.normal;
                        }
                    }
                },
                .cube => |c| {
                    if (intersect.rayCube(ray, c, 1e-3, 1e9)) |t| {
                        if (t < t_min) {
                            hit = true;
                            t_min = t;
                            hit_position = ray.getPositionAt(t);
                            hit_normal = c.getNormalAt(hit_position);
                        }
                    }
                }
            }
        }

        if (!hit) return null;
                            

        return HitInformation{
            .position = hit_position,
            .normal = hit_normal,
            .distance = t_min
        };
    }

    fn rayCube(r: Ray, b: Cube, t0: f32, t1: f32) ?f32 {
        var tmin: f32 = undefined;
        var tmax: f32 = undefined;
        var tymin: f32 = undefined;
        var tymax: f32 = undefined;
        var tzmin: f32 = undefined;
        var tzmax: f32 = undefined;
        if (r.dir[0] >= 0) {
            tmin = (b.min[0] - r.origin[0]) / r.dir[0];
            tmax = (b.max[0] - r.origin[0]) / r.dir[0];
        }
        else {
            tmin = (b.max[0] - r.origin[0]) / r.dir[0];
            tmax = (b.min[0] - r.origin[0]) / r.dir[0];
        }
        if (r.dir[1] >= 0) {
            tymin = (b.min[1] - r.origin[1]) / r.dir[1];
            tymax = (b.max[1] - r.origin[1]) / r.dir[1];
        }
        else {
            tymin = (b.max[1] - r.origin[1]) / r.dir[1];
            tymax = (b.min[1] - r.origin[1]) / r.dir[1];
        }
        if ( (tmin > tymax) or (tymin > tmax) )
            return null;
        if (tymin > tmin)
            tmin = tymin;
        if (tymax < tmax)
            tmax = tymax;
        if (r.dir[2] >= 0) {
            tzmin = (b.min[2] - r.origin[2]) / r.dir[2];
            tzmax = (b.max[2] - r.origin[2]) / r.dir[2];
        }
        else {
            tzmin = (b.max[2] - r.origin[2]) / r.dir[2];
            tzmax = (b.min[2] - r.origin[2]) / r.dir[2];
        }
        if ( (tmin > tzmax) or (tzmin > tmax) )
            return null;
        if (tzmin > tmin)
            tmin = tzmin;
        if (tzmax < tmax)
            tmax = tzmax;

        if ( (tmin < t1) and (tmax > t0) )
        {
            return tmin;
        }
        return null;
    }
};

const vec2 = @Vector(2, f32);
const vec3 = @Vector(3, f32);
