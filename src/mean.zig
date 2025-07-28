const std = @import("std");
const Image = @import("Image.zig");
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;
const LinearFilter = @import("LinearFilter.zig");

fn meanFilter(image: *Image, point: Coordinates) Pixel {
    var mean: u32 = 0;

    var neighbor_point: Coordinates = .default;

    for (0..3) |i| {
        for (0..3) |j| {
            neighbor_point = .{
                .x = @truncate(point.x + i - 1),
                .y = @truncate(point.y + j - 1),
            };
            const pixel = image.getPixel(neighbor_point);
            mean += pixel.black_and_white;
        }
    }

    const neighbor_count = 9;
    mean /= neighbor_count;

    return .{ .black_and_white = @intCast(mean) };
}

pub fn meanFiltering(image: *Image, allocator: std.mem.Allocator) !Image {
    return LinearFilter.filter(image, allocator, meanFilter);
}

test "mean filtering" {
    var image = try Image.fromFile("image_bank/CircuitImprime.ppm", std.testing.allocator);
    defer image.free(std.testing.allocator);

    var new_image = try meanFiltering(&image, std.testing.allocator);
    defer new_image.free(std.testing.allocator);
    try new_image.toFile("test.ppm", std.testing.allocator);
}
