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

pub fn toFile(self: *Self, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writer().print("P{d}\n{d} {d}\n{d}\n", .{
        @intFromEnum(self.header.image_format),
        self.header.width,
        self.header.height,
        self.header.max_color_value,
    });

    try file.writer().writeAll(self.data);
}

pub fn empty(allocator: std.mem.Allocator, header: Header) !Self {
    const data_size = switch (header.image_format) {
        .ASCII_PPM, .PPM => 3 * header.width * header.height,
        .ASCII_PGM, .PGM => header.width * header.height,
    };

    const data = try allocator.alloc(u8, data_size);

    return Self{
        .header = header,
        .data = data,
    };
}

pub const Coordinates = struct {
    x: u32,
    y: u32,

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

pub fn setPixel(self: *Self, coords: Coordinates, pixel: Pixel) void {
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

test "getImage returns Image" {
    var image = try Self.fromFile("example.ppm", std.testing.allocator);
    defer image.free(std.testing.allocator);
    try std.testing.expectEqual(image.header.width, 320);
    try std.testing.expectEqual(image.header.height, 213);
    try std.testing.expectEqual(image.header.image_format, .PPM);

    try image.toFile("test.ppm");
}
