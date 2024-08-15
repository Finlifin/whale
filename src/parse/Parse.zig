gpa: Alc,
arena: Alc,

src: []const u8,

map: std.StringArrayHashMap(Index),
str_bytes: std.ArrayList(u8),

root: Index = 0,
nodes: Soa(Node),
nodes_capacity: usize,
prisma: std.ArrayList(Index),

tokens: *const Soa(Token),
ts_cusor: usize = 0,

err: void = undefined,

// pub fn parse(src: []const u8, ts: *const Soa(Token)) void {}

pub fn pNamespace(p: *Self) Index {
    const t = p.nextToken();

    switch (t) {
        .k_fn => {
            return p.pFn();
        },
        else => {},
    }

    return 0;
}

pub fn pFn(p: *Self) Index {
    if (p.nextToken() != .id) {
        unreachable;
    }

    const fn_name =
        p.push(
        .id,
        p.tokens.items(.from)[p.ts_cusor],
        p.tokens.items(.to)[p.ts_cusor],
    ) catch unreachable;
    const dependent_args = blk: {
        if (!p.eatToken(.@"<"))
            break :blk 0;
        const result = p.pDeclList();

        if (!p.eatToken(.@">")) {
            // ERR, todo
        }
        break :blk result;
    };
    const args = blk: {
        if (p.eatToken(.@"(")) {
            // ERR, todo
        }

        const result = p.pDeclList();

        if (p.eatToken(.@")")) {
            // ERR, todo
        }
        break :blk result;
    };
    const return_type = blk: {
        if (!(p.eatToken(.@"-") and p.eatToken(.@">"))) break :blk 0;
        break :blk p.pExpr();
    };
    const fn_proto = @as(Index, @intCast(p.prisma.items.len));
    p.prismaPush(fn_name);
    p.prismaPush(dependent_args);
    p.prismaPush(args);
    p.prismaPush(return_type);

    const fn_def =
        p.push(.fn_def, fn_proto, 0) catch unreachable;

    return fn_def;
}

pub fn srcContent(self: Self, id: Index) []const u8 {
    const from = self.gef(id, .lhs);
    const to = self.gef(id, .rhs);
    return self.src[from..to];
}

fn pDeclList(p: *Self) Index {
    _ = p;
    return 0;
}

pub fn pExpr(p: *Self) Index {
    return p.pPrefixExpr();
}

fn pPrefixExpr(p: *Self) Index {
    const t = p.nextToken();
    p.dumpTokens();

    return switch (t) {
        .int => p.push(
            .int,
            p.tokens.items(.from)[p.ts_cusor],
            p.tokens.items(.to)[p.ts_cusor],
        ) catch unreachable,
        .real => 0,
        // may be a call, a struct_construction, cstr, char, raw_byte, or just an id...
        .id => 0,
        // bool not
        .@"!" => 0,
        // reference type
        .@"&" => 0,
        // it may be a list_construction, map_construction, type_slice, type_array
        .@"[" => 0,
        // symbol stuff
        .@"." => {
            _ = p.eatToken(.@".");
            std.debug.print("current token: {s}\n", .{@tagName(p.tokens.items(.tag)[p.ts_cusor])});
            return p.push(
                .symbol,
                p.tokens.items(.from)[p.ts_cusor],
                p.tokens.items(.to)[p.ts_cusor],
            ) catch unreachable;
        },
        else => 0,
    };
}

pub fn init(gpa: Alc, arena: Alc, src: []const u8, ts: *const Soa(Token)) Self {
    var result = Self{
        .src = src,
        .tokens = ts,
        .gpa = gpa,
        .arena = arena,
        .nodes = .{},
        .nodes_capacity = 128,
        .map = std.StringArrayHashMap(Index).init(gpa),
        .str_bytes = std.ArrayList(u8).init(gpa),
        .prisma = std.ArrayList(Index).init(gpa),
    };

    result.nodes.setCapacity(gpa, 128) catch unreachable;
    _ = result.push(.placeholder, 0, 0) catch unreachable;
    return result;
}

pub fn dump(self: Self, node: Index, offset: usize) void {
    const print = std.debug.print;

    for (0..offset) |_| {
        print(" ", .{});
    }

    if (offset != 0) print("⎣-", .{});

    if (node == 0) {
        print("null\n", .{});
        return;
    }

    print("%{} {s}: ", .{ node, @tagName(self.gef(node, .tag)) });
    switch (self.gef(node, .tag)) {
        .symbol,
        => {
            print(".{s}\n", .{self.srcContent(node)});
            return;
        },
        .id, .int, .real => {
            print("{s}\n", .{self.srcContent(node)});
            return;
        },

        else => {},
    }

    self.dump(self.gef(node, .lhs), offset + 2);
    self.dump(self.gef(node, .rhs), offset + 2);
}

fn push(p: *Self, tag: Node.Tag, lhs: Index, rhs: Index) !Index {
    if (p.nodes.len >= p.nodes_capacity) {
        const new_capacity = @as(usize, @intFromFloat(@as(f64, @floatFromInt(p.nodes_capacity)) * 1.5));
        try p.nodes.setCapacity(p.gpa, new_capacity);
        p.nodes_capacity = new_capacity;
    }

    p.nodes.appendAssumeCapacity(.{ .tag = tag, .lhs = lhs, .rhs = rhs });
    return @as(Index, @intCast(p.nodes.len - 1));
}

fn prismaPush(p: *Self, index: Index) void {
    p.prisma.append(index) catch unreachable;
}

fn gef(p: Self, node: Index, field: anytype) FieldType(field) {
    return p.nodes.items(field)[node];
}

fn nextToken(p: *Self) Token.Tag {
    p.ts_cusor += 1;
    return p.tokens.items(.tag)[p.ts_cusor];
}
fn eatToken(p: *Self, tag: Token.Tag) bool {
    if (p.ts_cusor >= p.tokens.len) return false;
    // std.debug.print(
    //     "compare {s} with current cursor: {s}\n",
    //     .{
    //         @tagName(tag),
    //         @tagName(p.tokens.items(.tag)[p.ts_cusor]),
    //     },
    // );
    if (tag == p.tokens.items(.tag)[p.ts_cusor]) {
        p.ts_cusor += 1;
        return true;
    }

    return false;
}
fn expectToken(p: *Self, tag: Token.Tag) bool {
    if (p.ts_cusor >= p.tokens.len) return false;

    if (tag == p.tokens.items(.tag)[p.ts_cusor]) {
        return true;
    }

    return false;
}

fn expectNextToken(p: *Self, tag: Token.Tag) bool {
    if (p.ts_cusor + 1 >= p.tokens.len) return false;

    if (tag == p.tokens.items(.tag)[p.ts_cusor + 1]) {
        return true;
    }

    return false;
}

fn dumpTokens(p: Self) void {
    for (p.tokens.items(.tag)) |t| {
        std.debug.print("{s}\n", .{@tagName(t)});
    }
}

fn FieldType(field: anytype) type {
    return switch (field) {
        .tag => Node.Tag,
        .lhs, .rhs => Index,
        else => @compileError("Unknown field: " ++ @tagName(field)),
    };
}

const Self = @This();
const Ast = @import("Ast.zig");
const Node = Ast.Node;
const Index = @import("../base/types.zig").Index;
const std = @import("std");
const Soa = std.MultiArrayList;
const Alc = std.mem.Allocator;
const Token = @import("../lex/lex.zig").Token;
