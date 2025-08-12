const std = @import("std");
const Image = @import("Image.zig").Image;
const Coordinates = @import("Image.zig").Coordinates;
const Pixel = @import("Image.zig").Pixel;
const LinearFilter = @import("LinearFilter.zig");

fn medianFilter(image: *Image, point: Coordinates) Pixel {
    var median = [_]u8{0} ** 9;

    var neighbor_point: Coordinates = .default;

    var index: usize = 0;

    for (0..3) |i| {
        for (0..3) |j| {
            neighbor_point = .{
                .x = @truncate(point.x + i - 1),
                .y = @truncate(point.y + j - 1),
            };

            const pixel = image.getPixel(neighbor_point);

            median[index] = pixel.black_and_white;

            index += 1;
        }
    }

    const half_index = 4;

    std.mem.sort(u8, &median, {}, comptime std.sort.asc(u8));

    return .{ .black_and_white = median[half_index] };
}

pub fn medianFiltering(image: *Image, allocator: std.mem.Allocator) !*Image {
    return LinearFilter.filter(image, allocator, medianFilter);
}

test "median filtering" {
    var image = try Image.fromFile("image_bank/CircuitNoise.ppm", std.testing.allocator);
    defer image.free(std.testing.allocator);

    var new_image = try medianFiltering(&image, std.testing.allocator);
    defer new_image.free(std.testing.allocator);
    try new_image.toFile("test.ppm", std.testing.allocator);
}
