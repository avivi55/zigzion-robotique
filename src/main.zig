const Image = @import("Image.zig");

const std = @import("std");
const gtk = @import("gtk");
const Application = gtk.Application;
const ApplicationWindow = gtk.ApplicationWindow;
const Box = gtk.Box;
const Button = gtk.Button;
const Widget = gtk.Widget;
const Window = gtk.Window;
const gio = gtk.gio;
const GApplication = gio.Application;

pub fn printHello() void {
    std.log.info("Hello World", .{});
}

pub fn activate(app: *GApplication) void {
    var window = ApplicationWindow.new(app.tryInto(Application).?).into(Window);
    window.setTitle("Window");
    window.setDefaultSize(200, 200);
    var box = Box.new(.vertical, 0);
    var box_as_widget = box.into(Widget);
    box_as_widget.setHalign(.center);
    box_as_widget.setValign(.center);
    window.setChild(box_as_widget);

    var image = Image.fromFile("image_bank/LenaHead.pgm", std.heap.page_allocator) catch {
        std.debug.print("Error reading image", .{});
        return;
    };
    defer image.free(std.heap.page_allocator);

    var histogram_image: Image, _, _ = image.histogram(std.heap.page_allocator) catch {
        std.debug.print("Error reading histogram", .{});
        return;
    };
    defer histogram_image.free(std.heap.page_allocator);

    var er: ?*gtk.core.Error = null;
    const im_bytes = histogram_image.toBytes(std.heap.page_allocator) catch {
        return;
    };
    defer std.heap.page_allocator.free(im_bytes);

    const bytes = gtk.glib.Bytes.newTake(im_bytes);
    defer gtk.glib.free(bytes);

    const texture = gtk.gdk.Texture.newFromBytes(bytes, &er) catch {
        return;
    };
    // defer gtk.;

    const paintable = texture.into(gtk.gdk.Paintable);
    var img = gtk.Picture.newForPaintable(@constCast(paintable));
    box.append(img.into(Widget));

    var button = Button.newWithLabel("Hello, World");
    _ = button.connectClicked(printHello, .{}, .{});
    _ = button.connectClicked(Window.destroy, .{window}, .{ .swapped = true });
    box.append(button.into(Widget));
    window.present();
}

pub fn main() u8 {
    var app = Application.new("org.gtk.example", .{}).into(GApplication);
    defer app.__call("unref", .{});
    _ = app.connectActivate(activate, .{}, .{});
    return @intCast(app.run(@ptrCast(std.os.argv)));
}
