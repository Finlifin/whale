gpa: Alc,
arena: Alc,

src: []const u8,
map: std.StringArrayHashMapUnmanaged(Index),
str_bytes: std.ArrayListUnmanaged(u8),
nodes: Soa(Node),
tokens: Soa(Token),
prisma: std.ArrayListUnmanaged(Index),

pub const Node = struct {
    tag: Tag,
    lhs: Index,
    rhs: Index,
    // data: Index,

    pub const Tag = enum(Index) {
        // =========================
        // expressions
        // =========================

        // binary
        add,
        minus,
        mul,
        div,
        // std.mem.Allocator
        select,
        // well'type
        lift,
        bool_and,
        bool_or,
        bool_not,

        // unary (prefix)
        // &usize
        type_ref,
        // [12]bool
        type_array,
        // []u8
        type_slice,
        // ^ann.always_inline fn ...
        annotation,

        // unary (postfix)

        // literals or constructions
        // .say
        symbol,
        // 23
        int,
        // 23.23
        real,
        // Node { .tag =  }
        struct_construction,
        // [say, you, say, me]
        list_construction,
        // [say: you, me: say]
        map_construction,

        // types ?
        // error union,
        struct_def,
        trait_def,
        enum_def,
        union_def,
        opaque_def,
        impl_def,
        derive_def,
        handler_def,

        error_compose,
        effect_compose,
        reference_compose,

        // others
        id,
        // HashMap<&str, Box<usize>>.new()
        call,
        // HashMap<&str, Box<Alright>>
        tcall,
        // { ...; false }
        block,
        cast,
        undefined,
        @"unreachable",

        // =========================
        // statements
        // =========================

        // =========================
        // patterns
        // =========================

        // =========================
        // definitions
        // =========================
        // lhs: [is_runtime, name, dependent args, args, return_type, clauses], rhs: body
        fn_def,

        // =========================
        // others
        // =========================
        invalid,
        placeholder,
    };
};

const Index = @import("../base/types.zig").Index;
const std = @import("std");
const Soa = std.MultiArrayList;
const Alc = std.mem.Allocator;
const Token = @import("../lex/lex.zig").Token;
