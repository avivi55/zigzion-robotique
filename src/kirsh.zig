const std = @import("std");
const Image = @import("Image.zig");
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;
const LinearFilter = @import("LinearFilter.zig");

// zig fmt: off
const Masks = struct{
    pub const horizontal = [3][3]i16{ 
        .{ -1, 0, 1 }, 
        .{ -1, 0, 1 }, 
        .{ -1, 0, 1 } 
    };
    
    pub const vertical = [3][3]i16{ 
        .{ -1, -1, -1 }, 
        .{  0,  0,  0 }, 
        .{  1,  1,  1 } 
    };
    
    pub const up_diagonal = [3][3]i16{ 
        .{  0,  1, 1 }, 
        .{ -1,  0, 1 }, 
        .{ -1, -1, 0 } 
    };
    
    pub const down_diagonal = [3][3]i16{ 
        .{ -1, -1,  0 }, 
        .{ -1,  0,  1 }, 
        .{  0,  1,  1 } 
    };
};
// zig fmt: on

///
/// To iterate v
fn kirshBorder(image: *Image, point: Coordinates) Pixel {
    var neighbor_point: Coordinates = .default;

    var grad_x: i32 = 0;
    var grad_y: i32 = 0;
    var grad_d: i32 = 0;
    var grad_i: i32 = 0;

    inline for (0..3) |i| {
        inline for (0..3) |j| {
            neighbor_point = .{
                .x = @truncate(point.x + i - 1),
                .y = @truncate(point.y + j - 1),
            };
            const pixel: i16 = @intCast(image.getPixel(neighbor_point).black_and_white);

            grad_x += Masks.horizontal[i][j] * pixel;
            grad_y += Masks.vertical[i][j] * pixel;
            grad_d += Masks.up_diagonal[i][j] * pixel;
            grad_i += Masks.down_diagonal[i][j] * pixel;
        }
    }

    grad_x = @intCast(@abs(grad_x));
    grad_y = @intCast(@abs(grad_y));
    grad_d = @intCast(@abs(grad_d));
    grad_i = @intCast(@abs(grad_i));
    grad_x = @divFloor(grad_x, 3);
    grad_y = @divFloor(grad_y, 3);
    grad_d = @divFloor(grad_d, 3);
    grad_i = @divFloor(grad_i, 3);

    const max_grad: u8 = @intCast(@max(grad_x, grad_y, grad_d, grad_i));

    return .{ .black_and_white = max_grad };
}

pub fn kirsh(image: *Image, allocator: std.mem.Allocator) !Image {
    return LinearFilter.filter(image, allocator, kirshBorder);
}

test "kirsh border detection" {
    var image = try Image.fromFile("image_bank/LenaHeadBruit.ppm", std.testing.allocator);
    defer image.free(std.testing.allocator);

    var noiseless = try @import("median.zig").medianFiltering(&image, std.testing.allocator);
    defer noiseless.free(std.testing.allocator);

    var new_image = try kirsh(&noiseless, std.testing.allocator);
    defer new_image.free(std.testing.allocator);

    try new_image.toFile("test.ppm", std.testing.allocator);
}
