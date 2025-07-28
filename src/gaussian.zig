const std = @import("std");
const Image = @import("Image.zig");
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;
const LinearFilter = @import("LinearFilter.zig");

fn gaussianFilter(image: *Image, point: Coordinates) Pixel {
    var gauss: u32 = 0;

    var neighbor_point: Coordinates = .default;

    for (0..3) |i| {
        for (0..3) |j| {
            neighbor_point = .{
                .x = @truncate(point.x + i - 1),
                .y = @truncate(point.y + j - 1),
            };
            const pixel = image.getPixel(neighbor_point);
            gauss += pixel.black_and_white;
        }
    }

    const pixel = image.getPixel(point);
    gauss += pixel.black_and_white;

    const neighbor_count = 10;

    gauss /= neighbor_count;

    return .{ .black_and_white = @intCast(gauss) };
}

pub fn gaussianFiltering(image: *Image, allocator: std.mem.Allocator) !Image {
    return LinearFilter.filter(image, allocator, gaussianFilter);
}

test "gaussian filtering" {
    var image = try Image.fromFile("image_bank/CircuitNoise.ppm", std.testing.allocator);
    defer image.free(std.testing.allocator);

    var new_image = try gaussianFiltering(&image, std.testing.allocator);
    defer new_image.free(std.testing.allocator);
    try new_image.toFile("test.ppm",std.testing.allocator);
}
