const std = @import("std");
const Image = @import("Image.zig").Image;
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

pub fn meanFiltering(image: *Image, allocator: std.mem.Allocator) !*Image {
    return LinearFilter.filter(image, allocator, meanFilter);
}
