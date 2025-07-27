const std = @import("std");
const Self = @This();

const ImageFormat = enum(u32) { ASCII_PPM = 3, PPM = 6, ASCII_PGM = 2, PGM = 5 };

pub const Header = struct {
    image_format: ImageFormat,
    width: u32,
    height: u32,
    max_color_value: u16, // max is 65536

    pub const default = Header{
        .image_format = .PPM,
        .width = 0,
        .height = 0,
        .max_color_value = 255,
    };
};

header: Header,
data: []u8,

fn readHeader(file: std.fs.File, allocator: std.mem.Allocator) !Header {
    var width: u32 = 0;
    var height: u32 = 0;
    var image_format: ImageFormat = .PPM;

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();

    file.reader().streamUntilDelimiter(line.writer(), '\n', 3) catch |err| switch (err) {
        error.StreamTooLong => {
            std.log.err("Too many characters on the magic number line", .{});
            return err;
        },
        else => return err,
    };

    const first_line = try line.toOwnedSlice();
    defer allocator.free(first_line);

    line.clearRetainingCapacity();

    if (first_line.len < 2 or first_line[0] != 'P') {
        return error.InvalidImageFormat;
    }

    switch (first_line[1]) {
        '3' => image_format = .ASCII_PPM,
        '6' => image_format = .PPM,
        '2' => image_format = .ASCII_PGM,
        '5' => image_format = .PGM,
        else => return error.InvalidImageFormat,
    }

    while (true) {
        file.reader().streamUntilDelimiter(line.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        if (line.items[0] != '#') { // we hit the first non-comment line
            var parts = std.mem.splitScalar(u8, line.items, ' ');

            width = try std.fmt.parseInt(u32, parts.next().?, 10);
            height = try std.fmt.parseInt(u32, parts.next().?, 10);
            break;
        }

        line.clearRetainingCapacity();
    }

    line.clearRetainingCapacity();

    file.reader().streamUntilDelimiter(line.writer(), '\n', 4) catch |err| switch (err) {
        error.StreamTooLong => {
            std.log.err("Too many characters on the color max line", .{});
            return err;
        },
        else => return err,
    };

    const max_color_line = try line.toOwnedSlice();
    defer allocator.free(max_color_line);

    const max_color_value = try std.fmt.parseInt(u16, max_color_line, 10);

    return .{
        .image_format = image_format,
        .width = width,
        .height = height,
        .max_color_value = max_color_value,
    };
}

pub fn free(self: *Self, allocator: std.mem.Allocator) void {
    if (self.data.len > 0) {
        allocator.free(self.data);
    }
}

pub fn fromFile(path: []const u8, allocator: std.mem.Allocator) !Self {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const header = try readHeader(file, allocator);

    var line = std.ArrayList(u8).init(allocator);
    defer line.deinit();

    try file.reader().readAllArrayList(&line, std.math.maxInt(usize));

    return Self{
        .header = header,
        .data = try line.toOwnedSlice(),
    };
}

pub fn toBytes(self: *Self, allocator: std.mem.Allocator) ![]u8 {
    var array = std.ArrayList(u8).init(allocator);
    defer array.deinit();

    try array.writer().print("P{d}\n{d} {d}\n{d}\n", .{
        @intFromEnum(self.header.image_format),
        self.header.width,
        self.header.height,
        self.header.max_color_value,
    });

    try array.writer().writeAll(self.data);

    return array.toOwnedSlice();
}

pub fn toFile(self: *Self, path: []const u8, allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    const bytes = try self.toBytes(allocator);
    defer allocator.free(bytes);

    try file.writer().writeAll(bytes);
}

pub fn empty(allocator: std.mem.Allocator, header: Header) !Self {
    const data_size = switch (header.image_format) {
        .ASCII_PPM, .PPM => 3 * header.width * header.height,
        .ASCII_PGM, .PGM => header.width * header.height,
    };

    const data = try allocator.alloc(u8, data_size);
    for (0..data_size) |i| {
        data[i] = 0;
    }

    return Self{
        .header = header,
        .data = data,
    };
}

pub const Coordinates = struct {
    x: usize,
    y: usize,

    pub const default = Coordinates{
        .x = 0,
        .y = 0,
    };
};

pub const Pixel = union(enum) {
    black_and_white: u8,
    color: struct {
        r: u8,
        g: u8,
        b: u8,
    },
};

pub fn getPixel(self: *Self, coords: Coordinates) Pixel {
    switch (self.header.image_format) {
        .ASCII_PPM, .PPM => {
            const red_data_address = 3 * (coords.x + self.header.width * coords.y);
            const green_data_address = red_data_address + 1;
            const blue_data_address = red_data_address + 2;

            return .{ .color = .{
                .r = self.data[red_data_address],
                .g = self.data[green_data_address],
                .b = self.data[blue_data_address],
            } };
        },
        .ASCII_PGM, .PGM => return .{ .black_and_white = self.data[coords.x + self.header.width * coords.y] },
    }
}

pub fn setPixel(self: *Self, coords: Coordinates, pixel: Pixel) !void {
    if (coords.x >= self.header.width or coords.y >= self.header.height) {
        std.log.err("Coordinates out of bounds: ({}, {})", .{ coords.x, coords.y });
        return error.OutOfBounds;
    }

    switch (self.header.image_format) {
        .ASCII_PPM, .PPM => {
            const red_data_address = 3 * (coords.x + self.header.width * coords.y);
            const green_data_address = red_data_address + 1;
            const blue_data_address = red_data_address + 2;

            self.data[red_data_address] = pixel.color.r;
            self.data[green_data_address] = pixel.color.g;
            self.data[blue_data_address] = pixel.color.b;
        },
        .ASCII_PGM, .PGM => {
            self.data[coords.x + self.header.width * coords.y] = pixel.black_and_white;
        },
    }
}

pub fn histogram(self: *Self, allocator: std.mem.Allocator) !std.meta.Tuple(&.{ Self, ?Self, ?Self }) {
    switch (self.header.image_format) {
        .ASCII_PPM, .PPM => {
            var histogram_red_data = [_]u32{0} ** 256;
            var histogram_green_data = [_]u32{0} ** 256;
            var histogram_blue_data = [_]u32{0} ** 256;

            for (0..self.header.width) |x| {
                for (0..self.header.height) |y| {
                    const coords: Coordinates = .{ .x = x, .y = y };
                    const pixel = self.getPixel(coords).color;
                    histogram_red_data[pixel.r] += 1;
                    histogram_green_data[pixel.g] += 1;
                    histogram_blue_data[pixel.b] += 1;
                }
            }

            const max_red_value: u32 = std.sort.max(u32, &histogram_red_data, {}, std.sort.asc(u32)).?;
            const max_green_value: u32 = std.sort.max(u32, &histogram_green_data, {}, std.sort.asc(u32)).?;
            const max_blue_value: u32 = std.sort.max(u32, &histogram_blue_data, {}, std.sort.asc(u32)).?;

            const histogram_header: Header = .{
                .image_format = .PPM,
                .width = histogram_red_data.len,
                .height = 300,
                .max_color_value = 255,
            };

            var histogram_red_image = try Self.empty(allocator, histogram_header);

            for (histogram_red_data, 0..) |data, i| {
                const normalized_height: u32 = @intCast((data * histogram_red_image.header.height) / max_red_value);
                for (0..normalized_height) |h| {
                    const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_red_image.header.height - 1 - h) };
                    try histogram_red_image.setPixel(coords, .{ .color = .{
                        .r = 255,
                        .g = 0,
                        .b = 0,
                    } });
                }
            }

            var histogram_green_image = try Self.empty(allocator, histogram_header);

            for (histogram_green_data, 0..) |data, i| {
                const normalized_height: u32 = @intCast((data * histogram_green_image.header.height) / max_green_value);
                for (0..normalized_height) |h| {
                    const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_green_image.header.height - 1 - h) };
                    try histogram_green_image.setPixel(coords, .{ .color = .{
                        .r = 0,
                        .g = 255,
                        .b = 0,
                    } });
                }
            }

            var histogram_blue_image = try Self.empty(allocator, histogram_header);

            for (histogram_blue_data, 0..) |data, i| {
                const normalized_height: u32 = @intCast((data * histogram_blue_image.header.height) / max_blue_value);
                for (0..normalized_height) |h| {
                    const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_blue_image.header.height - 1 - h) };
                    try histogram_blue_image.setPixel(coords, .{ .color = .{
                        .r = 0,
                        .g = 0,
                        .b = 255,
                    } });
                }
            }

            return .{ histogram_red_image, histogram_green_image, histogram_blue_image };
        },
        .ASCII_PGM, .PGM => {
            var histogram_data = [_]u32{0} ** 256;

            for (self.data) |byte| {
                histogram_data[byte] += 1;
            }

            const max_value: u32 = std.sort.max(u32, &histogram_data, {}, std.sort.asc(u32)).?;

            var histogram_image = try Self.empty(allocator, .{
                .image_format = .PGM,
                .width = histogram_data.len,
                .height = 300,
                .max_color_value = 255,
            });

            for (histogram_data, 0..) |data, i| {
                const normalized_height: u32 = @intCast((data * histogram_image.header.height) / max_value);
                for (0..normalized_height) |h| {
                    const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_image.header.height - 1 - h) };
                    try histogram_image.setPixel(coords, .{ .black_and_white = 255 });
                }
            }

            return .{ histogram_image, null, null };
        },
    }
}

pub fn logHistogram(self: *Self, allocator: std.mem.Allocator) !std.meta.Tuple(&.{ Self, ?Self, ?Self }) {
    switch (self.header.image_format) {
        .ASCII_PPM, .PPM => {
            var histogram_red_data = [_]u32{0} ** 256;
            var histogram_green_data = [_]u32{0} ** 256;
            var histogram_blue_data = [_]u32{0} ** 256;

            for (0..self.header.width) |x| {
                for (0..self.header.height) |y| {
                    const coords: Coordinates = .{ .x = x, .y = y };
                    const pixel = self.getPixel(coords).color;
                    histogram_red_data[pixel.r] += 1;
                    histogram_green_data[pixel.g] += 1;
                    histogram_blue_data[pixel.b] += 1;
                }
            }

            const max_red_value: u32 = std.sort.max(u32, &histogram_red_data, {}, std.sort.asc(u32)).?;
            const max_green_value: u32 = std.sort.max(u32, &histogram_green_data, {}, std.sort.asc(u32)).?;
            const max_blue_value: u32 = std.sort.max(u32, &histogram_blue_data, {}, std.sort.asc(u32)).?;

            const histogram_header: Header = .{
                .image_format = .PPM,
                .width = histogram_red_data.len,
                .height = 300,
                .max_color_value = 255,
            };

            var histogram_red_image = try Self.empty(allocator, histogram_header);

            for (histogram_red_data, 0..) |data, i| {
                const normalized_height: u32 = @intFromFloat((std.math.log10(@as(f64, @floatFromInt(1 + data))) * @as(f64, @floatFromInt(histogram_red_image.header.height))) / std.math.log10(@as(f64, @floatFromInt(max_red_value + 1))));
                for (0..normalized_height) |h| {
                    const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_red_image.header.height - 1 - h) };
                    try histogram_red_image.setPixel(coords, .{ .color = .{
                        .r = 255,
                        .g = 0,
                        .b = 0,
                    } });
                }
            }

            var histogram_green_image = try Self.empty(allocator, histogram_header);

            for (histogram_green_data, 0..) |data, i| {
                const normalized_height: u32 = @intFromFloat((std.math.log10(@as(f64, @floatFromInt(1 + data))) * @as(f64, @floatFromInt(histogram_green_image.header.height))) / std.math.log10(@as(f64, @floatFromInt(max_green_value + 1))));
                for (0..normalized_height) |h| {
                    const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_green_image.header.height - 1 - h) };
                    try histogram_green_image.setPixel(coords, .{ .color = .{
                        .r = 0,
                        .g = 255,
                        .b = 0,
                    } });
                }
            }

            var histogram_blue_image = try Self.empty(allocator, histogram_header);

            for (histogram_blue_data, 0..) |data, i| {
                const normalized_height: u32 = @intFromFloat((std.math.log10(@as(f64, @floatFromInt(1 + data))) * @as(f64, @floatFromInt(histogram_blue_image.header.height))) / std.math.log10(@as(f64, @floatFromInt(max_blue_value + 1))));
                for (0..normalized_height) |h| {
                    const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_blue_image.header.height - 1 - h) };
                    try histogram_blue_image.setPixel(coords, .{ .color = .{
                        .r = 0,
                        .g = 0,
                        .b = 255,
                    } });
                }
            }

            return .{ histogram_red_image, histogram_green_image, histogram_blue_image };
        },
        .ASCII_PGM, .PGM => {
            var histogram_data = [_]u32{0} ** 256;

            for (self.data) |byte| {
                histogram_data[byte] += 1;
            }

            const max_value: u32 = std.sort.max(u32, &histogram_data, {}, std.sort.asc(u32)).?;

            var histogram_image = try Self.empty(allocator, .{
                .image_format = .PGM,
                .width = histogram_data.len,
                .height = 300,
                .max_color_value = 255,
            });

            for (histogram_data, 0..) |data, i| {
                const normalized_height: u32 = @intFromFloat((std.math.log10(@as(f64, @floatFromInt(1 + data))) * @as(f64, @floatFromInt(histogram_image.header.height))) / std.math.log10(@as(f64, @floatFromInt(max_value + 1))));
                for (0..normalized_height) |h| {
                    const coords: Coordinates = .{ .x = @intCast(i), .y = @intCast(histogram_image.header.height - 1 - h) };
                    try histogram_image.setPixel(coords, .{ .black_and_white = 255 });
                }
            }

            return .{ histogram_image, null, null };
        },
    }
}

// test "getImage returns Image" {
//     var image = try Self.fromFile("image_bank/CircuitNoise.ppm", std.testing.allocator);
//     defer image.free(std.testing.allocator);
//     try std.testing.expectEqual(image.header.width, 320);
//     try std.testing.expectEqual(image.header.height, 213);
//     try std.testing.expectEqual(image.header.image_format, .PPM);
//     try image.toFile("test.ppm", std.testing.allocator);
// }

test "histogram test pgm" {
    var image = try Self.fromFile("image_bank/Secateur.pgm", std.heap.page_allocator);
    defer image.free(std.heap.page_allocator);

    var histogram_image, _, _ = try image.histogram(std.heap.page_allocator);
    defer histogram_image.free(std.heap.page_allocator);

    try histogram_image.toFile("test2.pgm", std.testing.allocator);
}

// test "histogram test ppm" {
//     var image = try Self.fromFile("image_bank/LenaHeadBruit.ppm", std.testing.allocator);
//     defer image.free(std.testing.allocator);

//     var histogram_red_image: Self = undefined;
//     var histogram_green_image: ?Self = undefined;
//     var histogram_blue_image: ?Self = undefined;

//     histogram_red_image, histogram_green_image, histogram_blue_image = try image.histogram(std.testing.allocator);
//     defer histogram_red_image.free(std.testing.allocator);
//     defer histogram_green_image.?.free(std.testing.allocator);
//     defer histogram_blue_image.?.free(std.testing.allocator);

//     try histogram_red_image.toFile("testred.pgm");
//     try histogram_green_image.?.toFile("testgreen.pgm");
//     try histogram_blue_image.?.toFile("testblue.pgm");
// }
