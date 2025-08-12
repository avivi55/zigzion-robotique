const std = @import("std");
const Image = @import("Image.zig").Image;
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;
const LinearFilter = @import("LinearFilter.zig");

const laplace_mask = [3][3]i16{ .{ 0, 1, 0 }, .{ 1, -4, 1 }, .{ 0, 1, 0 } };

fn laplaceFilter(image: *Image, point: Coordinates) Pixel {
    var laplace: i32 = 0;

    var neighbor_point: Coordinates = .default;

    for (0..3) |i| {
        for (0..3) |j| {
            neighbor_point = .{
                .x = @truncate(point.x + i - 1),
                .y = @truncate(point.y + j - 1),
            };
            const pixel: i16 = @intCast(image.getPixel(neighbor_point).black_and_white);

            laplace += laplace_mask[i][j] * pixel;
        }
    }
    if (laplace < 0) {
        return .{ .black_and_white = 0 };
    } else {
        return .{ .black_and_white = @truncate(@abs(laplace)) };
    }
}

pub fn laplaceFiltering(image: *Image, allocator: std.mem.Allocator) !Image {
    return LinearFilter.filter(image, allocator, laplaceFilter);
}

test "laplace filtering" {
    var image = try Image.fromFile("image_bank/Bureau.pgm", std.testing.allocator);
    defer image.free(std.testing.allocator);

    var new_image = try laplaceFiltering(&image, std.testing.allocator);
    defer new_image.free(std.testing.allocator);
    try new_image.toFile("test.pgm", std.testing.allocator);
}
