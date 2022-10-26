//
// This code file is licenced under any of Public Domain, WTFPL or CC0.
// There are no restrictions in the use of this file.
//

//
// Generation parameters:
// API:        GL_ES_VERSION_2_0
// Profile:    core
// Extensions: GL_KHR_debug
//

//
// This file was generated with the following command line:
// generator /home/felix/projects/libraries/zig-opengl/bin/Debug/net6.0/generator.dll OpenGL-Registry/xml/gl.xml /home/felix/projects/libraries/zyclone/vendor/zero-graphics/src/gl_es_2v0.zig GL_ES_VERSION_2_0 GL_KHR_debug
//

const std = @import("std");
const builtin = @import("builtin");
const log = std.log.scoped(.OpenGL);

pub const FunctionPointer: type = blk: {
    const BaseFunc = fn (u32) callconv(.C) u32;
    const SpecializedFnPtr = FnPtr(BaseFunc);
    const fnptr_type = @typeInfo(SpecializedFnPtr);
    var generic_type = fnptr_type;
    std.debug.assert(generic_type.Pointer.size == .One);
    generic_type.Pointer.child = anyopaque;
    break :blk @Type(generic_type);
};

pub const GLenum = c_uint;
pub const GLboolean = u8;
pub const GLbitfield = c_uint;
pub const GLbyte = i8;
pub const GLubyte = u8;
pub const GLshort = i16;
pub const GLushort = u16;
pub const GLint = c_int;
pub const GLuint = c_uint;
pub const GLclampx = i32;
pub const GLsizei = c_int;
pub const GLfloat = f32;
pub const GLclampf = f32;
pub const GLdouble = f64;
pub const GLclampd = f64;
pub const GLeglClientBufferEXT = void;
pub const GLeglImageOES = void;
pub const GLchar = u8;
pub const GLcharARB = u8;

pub const GLhandleARB = if (builtin.os.tag == .macos) *anyopaque else c_uint;

pub const GLhalf = u16;
pub const GLhalfARB = u16;
pub const GLfixed = i32;
pub const GLintptr = usize;
pub const GLintptrARB = usize;
pub const GLsizeiptr = isize;
pub const GLsizeiptrARB = isize;
pub const GLint64 = i64;
pub const GLint64EXT = i64;
pub const GLuint64 = u64;
pub const GLuint64EXT = u64;

pub const GLsync = *opaque {};

pub const _cl_context = opaque {};
pub const _cl_event = opaque {};

pub const GLDEBUGPROC = FnPtr(fn (source: GLenum, _type: GLenum, id: GLuint, severity: GLenum, length: GLsizei, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void);
pub const GLDEBUGPROCARB = FnPtr(fn (source: GLenum, _type: GLenum, id: GLuint, severity: GLenum, length: GLsizei, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void);
pub const GLDEBUGPROCKHR = FnPtr(fn (source: GLenum, _type: GLenum, id: GLuint, severity: GLenum, length: GLsizei, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void);

pub const GLDEBUGPROCAMD = FnPtr(fn (id: GLuint, category: GLenum, severity: GLenum, length: GLsizei, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void);

pub const GLhalfNV = u16;
pub const GLvdpauSurfaceNV = GLintptr;
pub const GLVULKANPROCNV = *const fn () callconv(.C) void;

fn FnPtr(comptime Fn: type) type {
    return if (@import("builtin").zig_backend != .stage1)
        *const Fn
    else
        Fn;
}


pub const DEPTH_BUFFER_BIT = 0x00000100;
pub const STENCIL_BUFFER_BIT = 0x00000400;
pub const COLOR_BUFFER_BIT = 0x00004000;
pub const FALSE = 0;
pub const TRUE = 1;
pub const POINTS = 0x0000;
pub const LINES = 0x0001;
pub const LINE_LOOP = 0x0002;
pub const LINE_STRIP = 0x0003;
pub const TRIANGLES = 0x0004;
pub const TRIANGLE_STRIP = 0x0005;
pub const TRIANGLE_FAN = 0x0006;
pub const ZERO = 0;
pub const ONE = 1;
pub const SRC_COLOR = 0x0300;
pub const ONE_MINUS_SRC_COLOR = 0x0301;
pub const SRC_ALPHA = 0x0302;
pub const ONE_MINUS_SRC_ALPHA = 0x0303;
pub const DST_ALPHA = 0x0304;
pub const ONE_MINUS_DST_ALPHA = 0x0305;
pub const DST_COLOR = 0x0306;
pub const ONE_MINUS_DST_COLOR = 0x0307;
pub const SRC_ALPHA_SATURATE = 0x0308;
pub const FUNC_ADD = 0x8006;
pub const BLEND_EQUATION = 0x8009;
pub const BLEND_EQUATION_RGB = 0x8009;
pub const BLEND_EQUATION_ALPHA = 0x883D;
pub const FUNC_SUBTRACT = 0x800A;
pub const FUNC_REVERSE_SUBTRACT = 0x800B;
pub const BLEND_DST_RGB = 0x80C8;
pub const BLEND_SRC_RGB = 0x80C9;
pub const BLEND_DST_ALPHA = 0x80CA;
pub const BLEND_SRC_ALPHA = 0x80CB;
pub const CONSTANT_COLOR = 0x8001;
pub const ONE_MINUS_CONSTANT_COLOR = 0x8002;
pub const CONSTANT_ALPHA = 0x8003;
pub const ONE_MINUS_CONSTANT_ALPHA = 0x8004;
pub const BLEND_COLOR = 0x8005;
pub const ARRAY_BUFFER = 0x8892;
pub const ELEMENT_ARRAY_BUFFER = 0x8893;
pub const ARRAY_BUFFER_BINDING = 0x8894;
pub const ELEMENT_ARRAY_BUFFER_BINDING = 0x8895;
pub const STREAM_DRAW = 0x88E0;
pub const STATIC_DRAW = 0x88E4;
pub const DYNAMIC_DRAW = 0x88E8;
pub const BUFFER_SIZE = 0x8764;
pub const BUFFER_USAGE = 0x8765;
pub const CURRENT_VERTEX_ATTRIB = 0x8626;
pub const FRONT = 0x0404;
pub const BACK = 0x0405;
pub const FRONT_AND_BACK = 0x0408;
pub const TEXTURE_2D = 0x0DE1;
pub const CULL_FACE = 0x0B44;
pub const BLEND = 0x0BE2;
pub const DITHER = 0x0BD0;
pub const STENCIL_TEST = 0x0B90;
pub const DEPTH_TEST = 0x0B71;
pub const SCISSOR_TEST = 0x0C11;
pub const POLYGON_OFFSET_FILL = 0x8037;
pub const SAMPLE_ALPHA_TO_COVERAGE = 0x809E;
pub const SAMPLE_COVERAGE = 0x80A0;
pub const NO_ERROR = 0;
pub const INVALID_ENUM = 0x0500;
pub const INVALID_VALUE = 0x0501;
pub const INVALID_OPERATION = 0x0502;
pub const OUT_OF_MEMORY = 0x0505;
pub const CW = 0x0900;
pub const CCW = 0x0901;
pub const LINE_WIDTH = 0x0B21;
pub const ALIASED_POINT_SIZE_RANGE = 0x846D;
pub const ALIASED_LINE_WIDTH_RANGE = 0x846E;
pub const CULL_FACE_MODE = 0x0B45;
pub const FRONT_FACE = 0x0B46;
pub const DEPTH_RANGE = 0x0B70;
pub const DEPTH_WRITEMASK = 0x0B72;
pub const DEPTH_CLEAR_VALUE = 0x0B73;
pub const DEPTH_FUNC = 0x0B74;
pub const STENCIL_CLEAR_VALUE = 0x0B91;
pub const STENCIL_FUNC = 0x0B92;
pub const STENCIL_FAIL = 0x0B94;
pub const STENCIL_PASS_DEPTH_FAIL = 0x0B95;
pub const STENCIL_PASS_DEPTH_PASS = 0x0B96;
pub const STENCIL_REF = 0x0B97;
pub const STENCIL_VALUE_MASK = 0x0B93;
pub const STENCIL_WRITEMASK = 0x0B98;
pub const STENCIL_BACK_FUNC = 0x8800;
pub const STENCIL_BACK_FAIL = 0x8801;
pub const STENCIL_BACK_PASS_DEPTH_FAIL = 0x8802;
pub const STENCIL_BACK_PASS_DEPTH_PASS = 0x8803;
pub const STENCIL_BACK_REF = 0x8CA3;
pub const STENCIL_BACK_VALUE_MASK = 0x8CA4;
pub const STENCIL_BACK_WRITEMASK = 0x8CA5;
pub const VIEWPORT = 0x0BA2;
pub const SCISSOR_BOX = 0x0C10;
pub const COLOR_CLEAR_VALUE = 0x0C22;
pub const COLOR_WRITEMASK = 0x0C23;
pub const UNPACK_ALIGNMENT = 0x0CF5;
pub const PACK_ALIGNMENT = 0x0D05;
pub const MAX_TEXTURE_SIZE = 0x0D33;
pub const MAX_VIEWPORT_DIMS = 0x0D3A;
pub const SUBPIXEL_BITS = 0x0D50;
pub const RED_BITS = 0x0D52;
pub const GREEN_BITS = 0x0D53;
pub const BLUE_BITS = 0x0D54;
pub const ALPHA_BITS = 0x0D55;
pub const DEPTH_BITS = 0x0D56;
pub const STENCIL_BITS = 0x0D57;
pub const POLYGON_OFFSET_UNITS = 0x2A00;
pub const POLYGON_OFFSET_FACTOR = 0x8038;
pub const TEXTURE_BINDING_2D = 0x8069;
pub const SAMPLE_BUFFERS = 0x80A8;
pub const SAMPLES = 0x80A9;
pub const SAMPLE_COVERAGE_VALUE = 0x80AA;
pub const SAMPLE_COVERAGE_INVERT = 0x80AB;
pub const NUM_COMPRESSED_TEXTURE_FORMATS = 0x86A2;
pub const COMPRESSED_TEXTURE_FORMATS = 0x86A3;
pub const DONT_CARE = 0x1100;
pub const FASTEST = 0x1101;
pub const NICEST = 0x1102;
pub const GENERATE_MIPMAP_HINT = 0x8192;
pub const BYTE = 0x1400;
pub const UNSIGNED_BYTE = 0x1401;
pub const SHORT = 0x1402;
pub const UNSIGNED_SHORT = 0x1403;
pub const INT = 0x1404;
pub const UNSIGNED_INT = 0x1405;
pub const FLOAT = 0x1406;
pub const FIXED = 0x140C;
pub const DEPTH_COMPONENT = 0x1902;
pub const ALPHA = 0x1906;
pub const RGB = 0x1907;
pub const RGBA = 0x1908;
pub const LUMINANCE = 0x1909;
pub const LUMINANCE_ALPHA = 0x190A;
pub const UNSIGNED_SHORT_4_4_4_4 = 0x8033;
pub const UNSIGNED_SHORT_5_5_5_1 = 0x8034;
pub const UNSIGNED_SHORT_5_6_5 = 0x8363;
pub const FRAGMENT_SHADER = 0x8B30;
pub const VERTEX_SHADER = 0x8B31;
pub const MAX_VERTEX_ATTRIBS = 0x8869;
pub const MAX_VERTEX_UNIFORM_VECTORS = 0x8DFB;
pub const MAX_VARYING_VECTORS = 0x8DFC;
pub const MAX_COMBINED_TEXTURE_IMAGE_UNITS = 0x8B4D;
pub const MAX_VERTEX_TEXTURE_IMAGE_UNITS = 0x8B4C;
pub const MAX_TEXTURE_IMAGE_UNITS = 0x8872;
pub const MAX_FRAGMENT_UNIFORM_VECTORS = 0x8DFD;
pub const SHADER_TYPE = 0x8B4F;
pub const DELETE_STATUS = 0x8B80;
pub const LINK_STATUS = 0x8B82;
pub const VALIDATE_STATUS = 0x8B83;
pub const ATTACHED_SHADERS = 0x8B85;
pub const ACTIVE_UNIFORMS = 0x8B86;
pub const ACTIVE_UNIFORM_MAX_LENGTH = 0x8B87;
pub const ACTIVE_ATTRIBUTES = 0x8B89;
pub const ACTIVE_ATTRIBUTE_MAX_LENGTH = 0x8B8A;
pub const SHADING_LANGUAGE_VERSION = 0x8B8C;
pub const CURRENT_PROGRAM = 0x8B8D;
pub const NEVER = 0x0200;
pub const LESS = 0x0201;
pub const EQUAL = 0x0202;
pub const LEQUAL = 0x0203;
pub const GREATER = 0x0204;
pub const NOTEQUAL = 0x0205;
pub const GEQUAL = 0x0206;
pub const ALWAYS = 0x0207;
pub const KEEP = 0x1E00;
pub const REPLACE = 0x1E01;
pub const INCR = 0x1E02;
pub const DECR = 0x1E03;
pub const INVERT = 0x150A;
pub const INCR_WRAP = 0x8507;
pub const DECR_WRAP = 0x8508;
pub const VENDOR = 0x1F00;
pub const RENDERER = 0x1F01;
pub const VERSION = 0x1F02;
pub const EXTENSIONS = 0x1F03;
pub const NEAREST = 0x2600;
pub const LINEAR = 0x2601;
pub const NEAREST_MIPMAP_NEAREST = 0x2700;
pub const LINEAR_MIPMAP_NEAREST = 0x2701;
pub const NEAREST_MIPMAP_LINEAR = 0x2702;
pub const LINEAR_MIPMAP_LINEAR = 0x2703;
pub const TEXTURE_MAG_FILTER = 0x2800;
pub const TEXTURE_MIN_FILTER = 0x2801;
pub const TEXTURE_WRAP_S = 0x2802;
pub const TEXTURE_WRAP_T = 0x2803;
pub const TEXTURE = 0x1702;
pub const TEXTURE_CUBE_MAP = 0x8513;
pub const TEXTURE_BINDING_CUBE_MAP = 0x8514;
pub const TEXTURE_CUBE_MAP_POSITIVE_X = 0x8515;
pub const TEXTURE_CUBE_MAP_NEGATIVE_X = 0x8516;
pub const TEXTURE_CUBE_MAP_POSITIVE_Y = 0x8517;
pub const TEXTURE_CUBE_MAP_NEGATIVE_Y = 0x8518;
pub const TEXTURE_CUBE_MAP_POSITIVE_Z = 0x8519;
pub const TEXTURE_CUBE_MAP_NEGATIVE_Z = 0x851A;
pub const MAX_CUBE_MAP_TEXTURE_SIZE = 0x851C;
pub const TEXTURE0 = 0x84C0;
pub const TEXTURE1 = 0x84C1;
pub const TEXTURE2 = 0x84C2;
pub const TEXTURE3 = 0x84C3;
pub const TEXTURE4 = 0x84C4;
pub const TEXTURE5 = 0x84C5;
pub const TEXTURE6 = 0x84C6;
pub const TEXTURE7 = 0x84C7;
pub const TEXTURE8 = 0x84C8;
pub const TEXTURE9 = 0x84C9;
pub const TEXTURE10 = 0x84CA;
pub const TEXTURE11 = 0x84CB;
pub const TEXTURE12 = 0x84CC;
pub const TEXTURE13 = 0x84CD;
pub const TEXTURE14 = 0x84CE;
pub const TEXTURE15 = 0x84CF;
pub const TEXTURE16 = 0x84D0;
pub const TEXTURE17 = 0x84D1;
pub const TEXTURE18 = 0x84D2;
pub const TEXTURE19 = 0x84D3;
pub const TEXTURE20 = 0x84D4;
pub const TEXTURE21 = 0x84D5;
pub const TEXTURE22 = 0x84D6;
pub const TEXTURE23 = 0x84D7;
pub const TEXTURE24 = 0x84D8;
pub const TEXTURE25 = 0x84D9;
pub const TEXTURE26 = 0x84DA;
pub const TEXTURE27 = 0x84DB;
pub const TEXTURE28 = 0x84DC;
pub const TEXTURE29 = 0x84DD;
pub const TEXTURE30 = 0x84DE;
pub const TEXTURE31 = 0x84DF;
pub const ACTIVE_TEXTURE = 0x84E0;
pub const REPEAT = 0x2901;
pub const CLAMP_TO_EDGE = 0x812F;
pub const MIRRORED_REPEAT = 0x8370;
pub const FLOAT_VEC2 = 0x8B50;
pub const FLOAT_VEC3 = 0x8B51;
pub const FLOAT_VEC4 = 0x8B52;
pub const INT_VEC2 = 0x8B53;
pub const INT_VEC3 = 0x8B54;
pub const INT_VEC4 = 0x8B55;
pub const BOOL = 0x8B56;
pub const BOOL_VEC2 = 0x8B57;
pub const BOOL_VEC3 = 0x8B58;
pub const BOOL_VEC4 = 0x8B59;
pub const FLOAT_MAT2 = 0x8B5A;
pub const FLOAT_MAT3 = 0x8B5B;
pub const FLOAT_MAT4 = 0x8B5C;
pub const SAMPLER_2D = 0x8B5E;
pub const SAMPLER_CUBE = 0x8B60;
pub const VERTEX_ATTRIB_ARRAY_ENABLED = 0x8622;
pub const VERTEX_ATTRIB_ARRAY_SIZE = 0x8623;
pub const VERTEX_ATTRIB_ARRAY_STRIDE = 0x8624;
pub const VERTEX_ATTRIB_ARRAY_TYPE = 0x8625;
pub const VERTEX_ATTRIB_ARRAY_NORMALIZED = 0x886A;
pub const VERTEX_ATTRIB_ARRAY_POINTER = 0x8645;
pub const VERTEX_ATTRIB_ARRAY_BUFFER_BINDING = 0x889F;
pub const IMPLEMENTATION_COLOR_READ_TYPE = 0x8B9A;
pub const IMPLEMENTATION_COLOR_READ_FORMAT = 0x8B9B;
pub const COMPILE_STATUS = 0x8B81;
pub const INFO_LOG_LENGTH = 0x8B84;
pub const SHADER_SOURCE_LENGTH = 0x8B88;
pub const SHADER_COMPILER = 0x8DFA;
pub const SHADER_BINARY_FORMATS = 0x8DF8;
pub const NUM_SHADER_BINARY_FORMATS = 0x8DF9;
pub const LOW_FLOAT = 0x8DF0;
pub const MEDIUM_FLOAT = 0x8DF1;
pub const HIGH_FLOAT = 0x8DF2;
pub const LOW_INT = 0x8DF3;
pub const MEDIUM_INT = 0x8DF4;
pub const HIGH_INT = 0x8DF5;
pub const FRAMEBUFFER = 0x8D40;
pub const RENDERBUFFER = 0x8D41;
pub const RGBA4 = 0x8056;
pub const RGB5_A1 = 0x8057;
pub const RGB565 = 0x8D62;
pub const DEPTH_COMPONENT16 = 0x81A5;
pub const STENCIL_INDEX8 = 0x8D48;
pub const RENDERBUFFER_WIDTH = 0x8D42;
pub const RENDERBUFFER_HEIGHT = 0x8D43;
pub const RENDERBUFFER_INTERNAL_FORMAT = 0x8D44;
pub const RENDERBUFFER_RED_SIZE = 0x8D50;
pub const RENDERBUFFER_GREEN_SIZE = 0x8D51;
pub const RENDERBUFFER_BLUE_SIZE = 0x8D52;
pub const RENDERBUFFER_ALPHA_SIZE = 0x8D53;
pub const RENDERBUFFER_DEPTH_SIZE = 0x8D54;
pub const RENDERBUFFER_STENCIL_SIZE = 0x8D55;
pub const FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE = 0x8CD0;
pub const FRAMEBUFFER_ATTACHMENT_OBJECT_NAME = 0x8CD1;
pub const FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL = 0x8CD2;
pub const FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE = 0x8CD3;
pub const COLOR_ATTACHMENT0 = 0x8CE0;
pub const DEPTH_ATTACHMENT = 0x8D00;
pub const STENCIL_ATTACHMENT = 0x8D20;
pub const NONE = 0;
pub const FRAMEBUFFER_COMPLETE = 0x8CD5;
pub const FRAMEBUFFER_INCOMPLETE_ATTACHMENT = 0x8CD6;
pub const FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT = 0x8CD7;
pub const FRAMEBUFFER_INCOMPLETE_DIMENSIONS = 0x8CD9;
pub const FRAMEBUFFER_UNSUPPORTED = 0x8CDD;
pub const FRAMEBUFFER_BINDING = 0x8CA6;
pub const RENDERBUFFER_BINDING = 0x8CA7;
pub const MAX_RENDERBUFFER_SIZE = 0x84E8;
pub const INVALID_FRAMEBUFFER_OPERATION = 0x0506;


pub fn activeTexture(_texture: GLenum) callconv(.C) void {
    return (function_pointers.glActiveTexture orelse @panic("glActiveTexture was not bound."))(_texture);
}

pub fn attachShader(_program: GLuint, _shader: GLuint) callconv(.C) void {
    return (function_pointers.glAttachShader orelse @panic("glAttachShader was not bound."))(_program, _shader);
}

pub fn bindAttribLocation(_program: GLuint, _index: GLuint, _name: [*c]const GLchar) callconv(.C) void {
    return (function_pointers.glBindAttribLocation orelse @panic("glBindAttribLocation was not bound."))(_program, _index, _name);
}

pub fn bindBuffer(_target: GLenum, _buffer: GLuint) callconv(.C) void {
    return (function_pointers.glBindBuffer orelse @panic("glBindBuffer was not bound."))(_target, _buffer);
}

pub fn bindFramebuffer(_target: GLenum, _framebuffer: GLuint) callconv(.C) void {
    return (function_pointers.glBindFramebuffer orelse @panic("glBindFramebuffer was not bound."))(_target, _framebuffer);
}

pub fn bindRenderbuffer(_target: GLenum, _renderbuffer: GLuint) callconv(.C) void {
    return (function_pointers.glBindRenderbuffer orelse @panic("glBindRenderbuffer was not bound."))(_target, _renderbuffer);
}

pub fn bindTexture(_target: GLenum, _texture: GLuint) callconv(.C) void {
    return (function_pointers.glBindTexture orelse @panic("glBindTexture was not bound."))(_target, _texture);
}

pub fn blendColor(_red: GLfloat, _green: GLfloat, _blue: GLfloat, _alpha: GLfloat) callconv(.C) void {
    return (function_pointers.glBlendColor orelse @panic("glBlendColor was not bound."))(_red, _green, _blue, _alpha);
}

pub fn blendEquation(_mode: GLenum) callconv(.C) void {
    return (function_pointers.glBlendEquation orelse @panic("glBlendEquation was not bound."))(_mode);
}

pub fn blendEquationSeparate(_modeRGB: GLenum, _modeAlpha: GLenum) callconv(.C) void {
    return (function_pointers.glBlendEquationSeparate orelse @panic("glBlendEquationSeparate was not bound."))(_modeRGB, _modeAlpha);
}

pub fn blendFunc(_sfactor: GLenum, _dfactor: GLenum) callconv(.C) void {
    return (function_pointers.glBlendFunc orelse @panic("glBlendFunc was not bound."))(_sfactor, _dfactor);
}

pub fn blendFuncSeparate(_sfactorRGB: GLenum, _dfactorRGB: GLenum, _sfactorAlpha: GLenum, _dfactorAlpha: GLenum) callconv(.C) void {
    return (function_pointers.glBlendFuncSeparate orelse @panic("glBlendFuncSeparate was not bound."))(_sfactorRGB, _dfactorRGB, _sfactorAlpha, _dfactorAlpha);
}

pub fn bufferData(_target: GLenum, _size: GLsizeiptr, _data: ?*const anyopaque, _usage: GLenum) callconv(.C) void {
    return (function_pointers.glBufferData orelse @panic("glBufferData was not bound."))(_target, _size, _data, _usage);
}

pub fn bufferSubData(_target: GLenum, _offset: GLintptr, _size: GLsizeiptr, _data: ?*const anyopaque) callconv(.C) void {
    return (function_pointers.glBufferSubData orelse @panic("glBufferSubData was not bound."))(_target, _offset, _size, _data);
}

pub fn checkFramebufferStatus(_target: GLenum) callconv(.C) GLenum {
    return (function_pointers.glCheckFramebufferStatus orelse @panic("glCheckFramebufferStatus was not bound."))(_target);
}

pub fn clear(_mask: GLbitfield) callconv(.C) void {
    return (function_pointers.glClear orelse @panic("glClear was not bound."))(_mask);
}

pub fn clearColor(_red: GLfloat, _green: GLfloat, _blue: GLfloat, _alpha: GLfloat) callconv(.C) void {
    return (function_pointers.glClearColor orelse @panic("glClearColor was not bound."))(_red, _green, _blue, _alpha);
}

pub fn clearDepthf(_d: GLfloat) callconv(.C) void {
    return (function_pointers.glClearDepthf orelse @panic("glClearDepthf was not bound."))(_d);
}

pub fn clearStencil(_s: GLint) callconv(.C) void {
    return (function_pointers.glClearStencil orelse @panic("glClearStencil was not bound."))(_s);
}

pub fn colorMask(_red: GLboolean, _green: GLboolean, _blue: GLboolean, _alpha: GLboolean) callconv(.C) void {
    return (function_pointers.glColorMask orelse @panic("glColorMask was not bound."))(_red, _green, _blue, _alpha);
}

pub fn compileShader(_shader: GLuint) callconv(.C) void {
    return (function_pointers.glCompileShader orelse @panic("glCompileShader was not bound."))(_shader);
}

pub fn compressedTexImage2D(_target: GLenum, _level: GLint, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _border: GLint, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void {
    return (function_pointers.glCompressedTexImage2D orelse @panic("glCompressedTexImage2D was not bound."))(_target, _level, _internalformat, _width, _height, _border, _imageSize, _data);
}

pub fn compressedTexSubImage2D(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void {
    return (function_pointers.glCompressedTexSubImage2D orelse @panic("glCompressedTexSubImage2D was not bound."))(_target, _level, _xoffset, _yoffset, _width, _height, _format, _imageSize, _data);
}

pub fn copyTexImage2D(_target: GLenum, _level: GLint, _internalformat: GLenum, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _border: GLint) callconv(.C) void {
    return (function_pointers.glCopyTexImage2D orelse @panic("glCopyTexImage2D was not bound."))(_target, _level, _internalformat, _x, _y, _width, _height, _border);
}

pub fn copyTexSubImage2D(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void {
    return (function_pointers.glCopyTexSubImage2D orelse @panic("glCopyTexSubImage2D was not bound."))(_target, _level, _xoffset, _yoffset, _x, _y, _width, _height);
}

pub fn createProgram() callconv(.C) GLuint {
    return (function_pointers.glCreateProgram orelse @panic("glCreateProgram was not bound."))();
}

pub fn createShader(_type: GLenum) callconv(.C) GLuint {
    return (function_pointers.glCreateShader orelse @panic("glCreateShader was not bound."))(_type);
}

pub fn cullFace(_mode: GLenum) callconv(.C) void {
    return (function_pointers.glCullFace orelse @panic("glCullFace was not bound."))(_mode);
}

pub fn deleteBuffers(_n: GLsizei, _buffers: [*c]const GLuint) callconv(.C) void {
    return (function_pointers.glDeleteBuffers orelse @panic("glDeleteBuffers was not bound."))(_n, _buffers);
}

pub fn deleteFramebuffers(_n: GLsizei, _framebuffers: [*c]const GLuint) callconv(.C) void {
    return (function_pointers.glDeleteFramebuffers orelse @panic("glDeleteFramebuffers was not bound."))(_n, _framebuffers);
}

pub fn deleteProgram(_program: GLuint) callconv(.C) void {
    return (function_pointers.glDeleteProgram orelse @panic("glDeleteProgram was not bound."))(_program);
}

pub fn deleteRenderbuffers(_n: GLsizei, _renderbuffers: [*c]const GLuint) callconv(.C) void {
    return (function_pointers.glDeleteRenderbuffers orelse @panic("glDeleteRenderbuffers was not bound."))(_n, _renderbuffers);
}

pub fn deleteShader(_shader: GLuint) callconv(.C) void {
    return (function_pointers.glDeleteShader orelse @panic("glDeleteShader was not bound."))(_shader);
}

pub fn deleteTextures(_n: GLsizei, _textures: [*c]const GLuint) callconv(.C) void {
    return (function_pointers.glDeleteTextures orelse @panic("glDeleteTextures was not bound."))(_n, _textures);
}

pub fn depthFunc(_func: GLenum) callconv(.C) void {
    return (function_pointers.glDepthFunc orelse @panic("glDepthFunc was not bound."))(_func);
}

pub fn depthMask(_flag: GLboolean) callconv(.C) void {
    return (function_pointers.glDepthMask orelse @panic("glDepthMask was not bound."))(_flag);
}

pub fn depthRangef(_n: GLfloat, _f: GLfloat) callconv(.C) void {
    return (function_pointers.glDepthRangef orelse @panic("glDepthRangef was not bound."))(_n, _f);
}

pub fn detachShader(_program: GLuint, _shader: GLuint) callconv(.C) void {
    return (function_pointers.glDetachShader orelse @panic("glDetachShader was not bound."))(_program, _shader);
}

pub fn disable(_cap: GLenum) callconv(.C) void {
    return (function_pointers.glDisable orelse @panic("glDisable was not bound."))(_cap);
}

pub fn disableVertexAttribArray(_index: GLuint) callconv(.C) void {
    return (function_pointers.glDisableVertexAttribArray orelse @panic("glDisableVertexAttribArray was not bound."))(_index);
}

pub fn drawArrays(_mode: GLenum, _first: GLint, _count: GLsizei) callconv(.C) void {
    return (function_pointers.glDrawArrays orelse @panic("glDrawArrays was not bound."))(_mode, _first, _count);
}

pub fn drawElements(_mode: GLenum, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque) callconv(.C) void {
    return (function_pointers.glDrawElements orelse @panic("glDrawElements was not bound."))(_mode, _count, _type, _indices);
}

pub fn enable(_cap: GLenum) callconv(.C) void {
    return (function_pointers.glEnable orelse @panic("glEnable was not bound."))(_cap);
}

pub fn enableVertexAttribArray(_index: GLuint) callconv(.C) void {
    return (function_pointers.glEnableVertexAttribArray orelse @panic("glEnableVertexAttribArray was not bound."))(_index);
}

pub fn finish() callconv(.C) void {
    return (function_pointers.glFinish orelse @panic("glFinish was not bound."))();
}

pub fn flush() callconv(.C) void {
    return (function_pointers.glFlush orelse @panic("glFlush was not bound."))();
}

pub fn framebufferRenderbuffer(_target: GLenum, _attachment: GLenum, _renderbuffertarget: GLenum, _renderbuffer: GLuint) callconv(.C) void {
    return (function_pointers.glFramebufferRenderbuffer orelse @panic("glFramebufferRenderbuffer was not bound."))(_target, _attachment, _renderbuffertarget, _renderbuffer);
}

pub fn framebufferTexture2D(_target: GLenum, _attachment: GLenum, _textarget: GLenum, _texture: GLuint, _level: GLint) callconv(.C) void {
    return (function_pointers.glFramebufferTexture2D orelse @panic("glFramebufferTexture2D was not bound."))(_target, _attachment, _textarget, _texture, _level);
}

pub fn frontFace(_mode: GLenum) callconv(.C) void {
    return (function_pointers.glFrontFace orelse @panic("glFrontFace was not bound."))(_mode);
}

pub fn genBuffers(_n: GLsizei, _buffers: [*c]GLuint) callconv(.C) void {
    return (function_pointers.glGenBuffers orelse @panic("glGenBuffers was not bound."))(_n, _buffers);
}

pub fn generateMipmap(_target: GLenum) callconv(.C) void {
    return (function_pointers.glGenerateMipmap orelse @panic("glGenerateMipmap was not bound."))(_target);
}

pub fn genFramebuffers(_n: GLsizei, _framebuffers: [*c]GLuint) callconv(.C) void {
    return (function_pointers.glGenFramebuffers orelse @panic("glGenFramebuffers was not bound."))(_n, _framebuffers);
}

pub fn genRenderbuffers(_n: GLsizei, _renderbuffers: [*c]GLuint) callconv(.C) void {
    return (function_pointers.glGenRenderbuffers orelse @panic("glGenRenderbuffers was not bound."))(_n, _renderbuffers);
}

pub fn genTextures(_n: GLsizei, _textures: [*c]GLuint) callconv(.C) void {
    return (function_pointers.glGenTextures orelse @panic("glGenTextures was not bound."))(_n, _textures);
}

pub fn getActiveAttrib(_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) callconv(.C) void {
    return (function_pointers.glGetActiveAttrib orelse @panic("glGetActiveAttrib was not bound."))(_program, _index, _bufSize, _length, _size, _type, _name);
}

pub fn getActiveUniform(_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) callconv(.C) void {
    return (function_pointers.glGetActiveUniform orelse @panic("glGetActiveUniform was not bound."))(_program, _index, _bufSize, _length, _size, _type, _name);
}

pub fn getAttachedShaders(_program: GLuint, _maxCount: GLsizei, _count: [*c]GLsizei, _shaders: [*c]GLuint) callconv(.C) void {
    return (function_pointers.glGetAttachedShaders orelse @panic("glGetAttachedShaders was not bound."))(_program, _maxCount, _count, _shaders);
}

pub fn getAttribLocation(_program: GLuint, _name: [*c]const GLchar) callconv(.C) GLint {
    return (function_pointers.glGetAttribLocation orelse @panic("glGetAttribLocation was not bound."))(_program, _name);
}

pub fn getBooleanv(_pname: GLenum, _data: [*c]GLboolean) callconv(.C) void {
    return (function_pointers.glGetBooleanv orelse @panic("glGetBooleanv was not bound."))(_pname, _data);
}

pub fn getBufferParameteriv(_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return (function_pointers.glGetBufferParameteriv orelse @panic("glGetBufferParameteriv was not bound."))(_target, _pname, _params);
}

pub fn getError() callconv(.C) GLenum {
    return (function_pointers.glGetError orelse @panic("glGetError was not bound."))();
}

pub fn getFloatv(_pname: GLenum, _data: [*c]GLfloat) callconv(.C) void {
    return (function_pointers.glGetFloatv orelse @panic("glGetFloatv was not bound."))(_pname, _data);
}

pub fn getFramebufferAttachmentParameteriv(_target: GLenum, _attachment: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return (function_pointers.glGetFramebufferAttachmentParameteriv orelse @panic("glGetFramebufferAttachmentParameteriv was not bound."))(_target, _attachment, _pname, _params);
}

pub fn getIntegerv(_pname: GLenum, _data: [*c]GLint) callconv(.C) void {
    return (function_pointers.glGetIntegerv orelse @panic("glGetIntegerv was not bound."))(_pname, _data);
}

pub fn getProgramiv(_program: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return (function_pointers.glGetProgramiv orelse @panic("glGetProgramiv was not bound."))(_program, _pname, _params);
}

pub fn getProgramInfoLog(_program: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _infoLog: [*c]GLchar) callconv(.C) void {
    return (function_pointers.glGetProgramInfoLog orelse @panic("glGetProgramInfoLog was not bound."))(_program, _bufSize, _length, _infoLog);
}

pub fn getRenderbufferParameteriv(_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return (function_pointers.glGetRenderbufferParameteriv orelse @panic("glGetRenderbufferParameteriv was not bound."))(_target, _pname, _params);
}

pub fn getShaderiv(_shader: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return (function_pointers.glGetShaderiv orelse @panic("glGetShaderiv was not bound."))(_shader, _pname, _params);
}

pub fn getShaderInfoLog(_shader: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _infoLog: [*c]GLchar) callconv(.C) void {
    return (function_pointers.glGetShaderInfoLog orelse @panic("glGetShaderInfoLog was not bound."))(_shader, _bufSize, _length, _infoLog);
}

pub fn getShaderPrecisionFormat(_shadertype: GLenum, _precisiontype: GLenum, _range: [*c]GLint, _precision: [*c]GLint) callconv(.C) void {
    return (function_pointers.glGetShaderPrecisionFormat orelse @panic("glGetShaderPrecisionFormat was not bound."))(_shadertype, _precisiontype, _range, _precision);
}

pub fn getShaderSource(_shader: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _source: [*c]GLchar) callconv(.C) void {
    return (function_pointers.glGetShaderSource orelse @panic("glGetShaderSource was not bound."))(_shader, _bufSize, _length, _source);
}

pub fn getString(_name: GLenum) callconv(.C) ?[*:0]const GLubyte {
    return (function_pointers.glGetString orelse @panic("glGetString was not bound."))(_name);
}

pub fn getTexParameterfv(_target: GLenum, _pname: GLenum, _params: [*c]GLfloat) callconv(.C) void {
    return (function_pointers.glGetTexParameterfv orelse @panic("glGetTexParameterfv was not bound."))(_target, _pname, _params);
}

pub fn getTexParameteriv(_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return (function_pointers.glGetTexParameteriv orelse @panic("glGetTexParameteriv was not bound."))(_target, _pname, _params);
}

pub fn getUniformfv(_program: GLuint, _location: GLint, _params: [*c]GLfloat) callconv(.C) void {
    return (function_pointers.glGetUniformfv orelse @panic("glGetUniformfv was not bound."))(_program, _location, _params);
}

pub fn getUniformiv(_program: GLuint, _location: GLint, _params: [*c]GLint) callconv(.C) void {
    return (function_pointers.glGetUniformiv orelse @panic("glGetUniformiv was not bound."))(_program, _location, _params);
}

pub fn getUniformLocation(_program: GLuint, _name: [*c]const GLchar) callconv(.C) GLint {
    return (function_pointers.glGetUniformLocation orelse @panic("glGetUniformLocation was not bound."))(_program, _name);
}

pub fn getVertexAttribfv(_index: GLuint, _pname: GLenum, _params: [*c]GLfloat) callconv(.C) void {
    return (function_pointers.glGetVertexAttribfv orelse @panic("glGetVertexAttribfv was not bound."))(_index, _pname, _params);
}

pub fn getVertexAttribiv(_index: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void {
    return (function_pointers.glGetVertexAttribiv orelse @panic("glGetVertexAttribiv was not bound."))(_index, _pname, _params);
}

pub fn getVertexAttribPointerv(_index: GLuint, _pname: GLenum, _pointer: ?*?*anyopaque) callconv(.C) void {
    return (function_pointers.glGetVertexAttribPointerv orelse @panic("glGetVertexAttribPointerv was not bound."))(_index, _pname, _pointer);
}

pub fn hint(_target: GLenum, _mode: GLenum) callconv(.C) void {
    return (function_pointers.glHint orelse @panic("glHint was not bound."))(_target, _mode);
}

pub fn isBuffer(_buffer: GLuint) callconv(.C) GLboolean {
    return (function_pointers.glIsBuffer orelse @panic("glIsBuffer was not bound."))(_buffer);
}

pub fn isEnabled(_cap: GLenum) callconv(.C) GLboolean {
    return (function_pointers.glIsEnabled orelse @panic("glIsEnabled was not bound."))(_cap);
}

pub fn isFramebuffer(_framebuffer: GLuint) callconv(.C) GLboolean {
    return (function_pointers.glIsFramebuffer orelse @panic("glIsFramebuffer was not bound."))(_framebuffer);
}

pub fn isProgram(_program: GLuint) callconv(.C) GLboolean {
    return (function_pointers.glIsProgram orelse @panic("glIsProgram was not bound."))(_program);
}

pub fn isRenderbuffer(_renderbuffer: GLuint) callconv(.C) GLboolean {
    return (function_pointers.glIsRenderbuffer orelse @panic("glIsRenderbuffer was not bound."))(_renderbuffer);
}

pub fn isShader(_shader: GLuint) callconv(.C) GLboolean {
    return (function_pointers.glIsShader orelse @panic("glIsShader was not bound."))(_shader);
}

pub fn isTexture(_texture: GLuint) callconv(.C) GLboolean {
    return (function_pointers.glIsTexture orelse @panic("glIsTexture was not bound."))(_texture);
}

pub fn lineWidth(_width: GLfloat) callconv(.C) void {
    return (function_pointers.glLineWidth orelse @panic("glLineWidth was not bound."))(_width);
}

pub fn linkProgram(_program: GLuint) callconv(.C) void {
    return (function_pointers.glLinkProgram orelse @panic("glLinkProgram was not bound."))(_program);
}

pub fn pixelStorei(_pname: GLenum, _param: GLint) callconv(.C) void {
    return (function_pointers.glPixelStorei orelse @panic("glPixelStorei was not bound."))(_pname, _param);
}

pub fn polygonOffset(_factor: GLfloat, _units: GLfloat) callconv(.C) void {
    return (function_pointers.glPolygonOffset orelse @panic("glPolygonOffset was not bound."))(_factor, _units);
}

pub fn readPixels(_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*anyopaque) callconv(.C) void {
    return (function_pointers.glReadPixels orelse @panic("glReadPixels was not bound."))(_x, _y, _width, _height, _format, _type, _pixels);
}

pub fn releaseShaderCompiler() callconv(.C) void {
    return (function_pointers.glReleaseShaderCompiler orelse @panic("glReleaseShaderCompiler was not bound."))();
}

pub fn renderbufferStorage(_target: GLenum, _internalformat: GLenum, _width: GLsizei, _height: GLsizei) callconv(.C) void {
    return (function_pointers.glRenderbufferStorage orelse @panic("glRenderbufferStorage was not bound."))(_target, _internalformat, _width, _height);
}

pub fn sampleCoverage(_value: GLfloat, _invert: GLboolean) callconv(.C) void {
    return (function_pointers.glSampleCoverage orelse @panic("glSampleCoverage was not bound."))(_value, _invert);
}

pub fn scissor(_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void {
    return (function_pointers.glScissor orelse @panic("glScissor was not bound."))(_x, _y, _width, _height);
}

pub fn shaderBinary(_count: GLsizei, _shaders: [*c]const GLuint, _binaryFormat: GLenum, _binary: ?*const anyopaque, _length: GLsizei) callconv(.C) void {
    return (function_pointers.glShaderBinary orelse @panic("glShaderBinary was not bound."))(_count, _shaders, _binaryFormat, _binary, _length);
}

pub fn shaderSource(_shader: GLuint, _count: GLsizei, _string: [*c]const [*c]const GLchar, _length: [*c]const GLint) callconv(.C) void {
    return (function_pointers.glShaderSource orelse @panic("glShaderSource was not bound."))(_shader, _count, _string, _length);
}

pub fn stencilFunc(_func: GLenum, _ref: GLint, _mask: GLuint) callconv(.C) void {
    return (function_pointers.glStencilFunc orelse @panic("glStencilFunc was not bound."))(_func, _ref, _mask);
}

pub fn stencilFuncSeparate(_face: GLenum, _func: GLenum, _ref: GLint, _mask: GLuint) callconv(.C) void {
    return (function_pointers.glStencilFuncSeparate orelse @panic("glStencilFuncSeparate was not bound."))(_face, _func, _ref, _mask);
}

pub fn stencilMask(_mask: GLuint) callconv(.C) void {
    return (function_pointers.glStencilMask orelse @panic("glStencilMask was not bound."))(_mask);
}

pub fn stencilMaskSeparate(_face: GLenum, _mask: GLuint) callconv(.C) void {
    return (function_pointers.glStencilMaskSeparate orelse @panic("glStencilMaskSeparate was not bound."))(_face, _mask);
}

pub fn stencilOp(_fail: GLenum, _zfail: GLenum, _zpass: GLenum) callconv(.C) void {
    return (function_pointers.glStencilOp orelse @panic("glStencilOp was not bound."))(_fail, _zfail, _zpass);
}

pub fn stencilOpSeparate(_face: GLenum, _sfail: GLenum, _dpfail: GLenum, _dppass: GLenum) callconv(.C) void {
    return (function_pointers.glStencilOpSeparate orelse @panic("glStencilOpSeparate was not bound."))(_face, _sfail, _dpfail, _dppass);
}

pub fn texImage2D(_target: GLenum, _level: GLint, _internalformat: GLint, _width: GLsizei, _height: GLsizei, _border: GLint, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void {
    return (function_pointers.glTexImage2D orelse @panic("glTexImage2D was not bound."))(_target, _level, _internalformat, _width, _height, _border, _format, _type, _pixels);
}

pub fn texParameterf(_target: GLenum, _pname: GLenum, _param: GLfloat) callconv(.C) void {
    return (function_pointers.glTexParameterf orelse @panic("glTexParameterf was not bound."))(_target, _pname, _param);
}

pub fn texParameterfv(_target: GLenum, _pname: GLenum, _params: [*c]const GLfloat) callconv(.C) void {
    return (function_pointers.glTexParameterfv orelse @panic("glTexParameterfv was not bound."))(_target, _pname, _params);
}

pub fn texParameteri(_target: GLenum, _pname: GLenum, _param: GLint) callconv(.C) void {
    return (function_pointers.glTexParameteri orelse @panic("glTexParameteri was not bound."))(_target, _pname, _param);
}

pub fn texParameteriv(_target: GLenum, _pname: GLenum, _params: [*c]const GLint) callconv(.C) void {
    return (function_pointers.glTexParameteriv orelse @panic("glTexParameteriv was not bound."))(_target, _pname, _params);
}

pub fn texSubImage2D(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void {
    return (function_pointers.glTexSubImage2D orelse @panic("glTexSubImage2D was not bound."))(_target, _level, _xoffset, _yoffset, _width, _height, _format, _type, _pixels);
}

pub fn uniform1f(_location: GLint, _v0: GLfloat) callconv(.C) void {
    return (function_pointers.glUniform1f orelse @panic("glUniform1f was not bound."))(_location, _v0);
}

pub fn uniform1fv(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void {
    return (function_pointers.glUniform1fv orelse @panic("glUniform1fv was not bound."))(_location, _count, _value);
}

pub fn uniform1i(_location: GLint, _v0: GLint) callconv(.C) void {
    return (function_pointers.glUniform1i orelse @panic("glUniform1i was not bound."))(_location, _v0);
}

pub fn uniform1iv(_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void {
    return (function_pointers.glUniform1iv orelse @panic("glUniform1iv was not bound."))(_location, _count, _value);
}

pub fn uniform2f(_location: GLint, _v0: GLfloat, _v1: GLfloat) callconv(.C) void {
    return (function_pointers.glUniform2f orelse @panic("glUniform2f was not bound."))(_location, _v0, _v1);
}

pub fn uniform2fv(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void {
    return (function_pointers.glUniform2fv orelse @panic("glUniform2fv was not bound."))(_location, _count, _value);
}

pub fn uniform2i(_location: GLint, _v0: GLint, _v1: GLint) callconv(.C) void {
    return (function_pointers.glUniform2i orelse @panic("glUniform2i was not bound."))(_location, _v0, _v1);
}

pub fn uniform2iv(_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void {
    return (function_pointers.glUniform2iv orelse @panic("glUniform2iv was not bound."))(_location, _count, _value);
}

pub fn uniform3f(_location: GLint, _v0: GLfloat, _v1: GLfloat, _v2: GLfloat) callconv(.C) void {
    return (function_pointers.glUniform3f orelse @panic("glUniform3f was not bound."))(_location, _v0, _v1, _v2);
}

pub fn uniform3fv(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void {
    return (function_pointers.glUniform3fv orelse @panic("glUniform3fv was not bound."))(_location, _count, _value);
}

pub fn uniform3i(_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint) callconv(.C) void {
    return (function_pointers.glUniform3i orelse @panic("glUniform3i was not bound."))(_location, _v0, _v1, _v2);
}

pub fn uniform3iv(_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void {
    return (function_pointers.glUniform3iv orelse @panic("glUniform3iv was not bound."))(_location, _count, _value);
}

pub fn uniform4f(_location: GLint, _v0: GLfloat, _v1: GLfloat, _v2: GLfloat, _v3: GLfloat) callconv(.C) void {
    return (function_pointers.glUniform4f orelse @panic("glUniform4f was not bound."))(_location, _v0, _v1, _v2, _v3);
}

pub fn uniform4fv(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void {
    return (function_pointers.glUniform4fv orelse @panic("glUniform4fv was not bound."))(_location, _count, _value);
}

pub fn uniform4i(_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint, _v3: GLint) callconv(.C) void {
    return (function_pointers.glUniform4i orelse @panic("glUniform4i was not bound."))(_location, _v0, _v1, _v2, _v3);
}

pub fn uniform4iv(_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void {
    return (function_pointers.glUniform4iv orelse @panic("glUniform4iv was not bound."))(_location, _count, _value);
}

pub fn uniformMatrix2fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void {
    return (function_pointers.glUniformMatrix2fv orelse @panic("glUniformMatrix2fv was not bound."))(_location, _count, _transpose, _value);
}

pub fn uniformMatrix3fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void {
    return (function_pointers.glUniformMatrix3fv orelse @panic("glUniformMatrix3fv was not bound."))(_location, _count, _transpose, _value);
}

pub fn uniformMatrix4fv(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void {
    return (function_pointers.glUniformMatrix4fv orelse @panic("glUniformMatrix4fv was not bound."))(_location, _count, _transpose, _value);
}

pub fn useProgram(_program: GLuint) callconv(.C) void {
    return (function_pointers.glUseProgram orelse @panic("glUseProgram was not bound."))(_program);
}

pub fn validateProgram(_program: GLuint) callconv(.C) void {
    return (function_pointers.glValidateProgram orelse @panic("glValidateProgram was not bound."))(_program);
}

pub fn vertexAttrib1f(_index: GLuint, _x: GLfloat) callconv(.C) void {
    return (function_pointers.glVertexAttrib1f orelse @panic("glVertexAttrib1f was not bound."))(_index, _x);
}

pub fn vertexAttrib1fv(_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void {
    return (function_pointers.glVertexAttrib1fv orelse @panic("glVertexAttrib1fv was not bound."))(_index, _v);
}

pub fn vertexAttrib2f(_index: GLuint, _x: GLfloat, _y: GLfloat) callconv(.C) void {
    return (function_pointers.glVertexAttrib2f orelse @panic("glVertexAttrib2f was not bound."))(_index, _x, _y);
}

pub fn vertexAttrib2fv(_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void {
    return (function_pointers.glVertexAttrib2fv orelse @panic("glVertexAttrib2fv was not bound."))(_index, _v);
}

pub fn vertexAttrib3f(_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat) callconv(.C) void {
    return (function_pointers.glVertexAttrib3f orelse @panic("glVertexAttrib3f was not bound."))(_index, _x, _y, _z);
}

pub fn vertexAttrib3fv(_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void {
    return (function_pointers.glVertexAttrib3fv orelse @panic("glVertexAttrib3fv was not bound."))(_index, _v);
}

pub fn vertexAttrib4f(_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat, _w: GLfloat) callconv(.C) void {
    return (function_pointers.glVertexAttrib4f orelse @panic("glVertexAttrib4f was not bound."))(_index, _x, _y, _z, _w);
}

pub fn vertexAttrib4fv(_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void {
    return (function_pointers.glVertexAttrib4fv orelse @panic("glVertexAttrib4fv was not bound."))(_index, _v);
}

pub fn vertexAttribPointer(_index: GLuint, _size: GLint, _type: GLenum, _normalized: GLboolean, _stride: GLsizei, _pointer: ?*const anyopaque) callconv(.C) void {
    return (function_pointers.glVertexAttribPointer orelse @panic("glVertexAttribPointer was not bound."))(_index, _size, _type, _normalized, _stride, _pointer);
}

pub fn viewport(_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void {
    return (function_pointers.glViewport orelse @panic("glViewport was not bound."))(_x, _y, _width, _height);
}
// Extensions:

pub const GL_KHR_debug = struct {
pub const DEBUG_OUTPUT_SYNCHRONOUS_KHR = 0x8242;
pub const DEBUG_NEXT_LOGGED_MESSAGE_LENGTH_KHR = 0x8243;
pub const DEBUG_CALLBACK_FUNCTION_KHR = 0x8244;
pub const DEBUG_CALLBACK_USER_PARAM_KHR = 0x8245;
pub const DEBUG_SOURCE_API_KHR = 0x8246;
pub const DEBUG_SOURCE_WINDOW_SYSTEM_KHR = 0x8247;
pub const DEBUG_SOURCE_SHADER_COMPILER_KHR = 0x8248;
pub const DEBUG_SOURCE_THIRD_PARTY_KHR = 0x8249;
pub const DEBUG_SOURCE_APPLICATION_KHR = 0x824A;
pub const DEBUG_SOURCE_OTHER_KHR = 0x824B;
pub const DEBUG_TYPE_ERROR_KHR = 0x824C;
pub const DEBUG_TYPE_DEPRECATED_BEHAVIOR_KHR = 0x824D;
pub const DEBUG_TYPE_UNDEFINED_BEHAVIOR_KHR = 0x824E;
pub const DEBUG_TYPE_PORTABILITY_KHR = 0x824F;
pub const DEBUG_TYPE_PERFORMANCE_KHR = 0x8250;
pub const DEBUG_TYPE_OTHER_KHR = 0x8251;
pub const DEBUG_TYPE_MARKER_KHR = 0x8268;
pub const DEBUG_TYPE_PUSH_GROUP_KHR = 0x8269;
pub const DEBUG_TYPE_POP_GROUP_KHR = 0x826A;
pub const DEBUG_SEVERITY_NOTIFICATION_KHR = 0x826B;
pub const MAX_DEBUG_GROUP_STACK_DEPTH_KHR = 0x826C;
pub const DEBUG_GROUP_STACK_DEPTH_KHR = 0x826D;
pub const BUFFER_KHR = 0x82E0;
pub const SHADER_KHR = 0x82E1;
pub const PROGRAM_KHR = 0x82E2;
pub const VERTEX_ARRAY_KHR = 0x8074;
pub const QUERY_KHR = 0x82E3;
pub const PROGRAM_PIPELINE_KHR = 0x82E4;
pub const SAMPLER_KHR = 0x82E6;
pub const MAX_LABEL_LENGTH_KHR = 0x82E8;
pub const MAX_DEBUG_MESSAGE_LENGTH_KHR = 0x9143;
pub const MAX_DEBUG_LOGGED_MESSAGES_KHR = 0x9144;
pub const DEBUG_LOGGED_MESSAGES_KHR = 0x9145;
pub const DEBUG_SEVERITY_HIGH_KHR = 0x9146;
pub const DEBUG_SEVERITY_MEDIUM_KHR = 0x9147;
pub const DEBUG_SEVERITY_LOW_KHR = 0x9148;
pub const DEBUG_OUTPUT_KHR = 0x92E0;
pub const CONTEXT_FLAG_DEBUG_BIT_KHR = 0x00000002;
pub const STACK_OVERFLOW_KHR = 0x0503;
pub const STACK_UNDERFLOW_KHR = 0x0504;


pub fn debugMessageControlKHR(_source: GLenum, _type: GLenum, _severity: GLenum, _count: GLsizei, _ids: [*c]const GLuint, _enabled: GLboolean) callconv(.C) void {
    return (function_pointers.glDebugMessageControlKHR orelse @panic("glDebugMessageControlKHR was not bound."))(_source, _type, _severity, _count, _ids, _enabled);
}

pub fn debugMessageInsertKHR(_source: GLenum, _type: GLenum, _id: GLuint, _severity: GLenum, _length: GLsizei, _buf: [*c]const GLchar) callconv(.C) void {
    return (function_pointers.glDebugMessageInsertKHR orelse @panic("glDebugMessageInsertKHR was not bound."))(_source, _type, _id, _severity, _length, _buf);
}

pub fn debugMessageCallbackKHR(_callback: GLDEBUGPROCKHR, _userParam: ?*const anyopaque) callconv(.C) void {
    return (function_pointers.glDebugMessageCallbackKHR orelse @panic("glDebugMessageCallbackKHR was not bound."))(_callback, _userParam);
}

pub fn getDebugMessageLogKHR(_count: GLuint, _bufSize: GLsizei, _sources: [*c]GLenum, _types: [*c]GLenum, _ids: [*c]GLuint, _severities: [*c]GLenum, _lengths: [*c]GLsizei, _messageLog: [*c]GLchar) callconv(.C) GLuint {
    return (function_pointers.glGetDebugMessageLogKHR orelse @panic("glGetDebugMessageLogKHR was not bound."))(_count, _bufSize, _sources, _types, _ids, _severities, _lengths, _messageLog);
}

pub fn pushDebugGroupKHR(_source: GLenum, _id: GLuint, _length: GLsizei, _message: [*c]const GLchar) callconv(.C) void {
    return (function_pointers.glPushDebugGroupKHR orelse @panic("glPushDebugGroupKHR was not bound."))(_source, _id, _length, _message);
}

pub fn popDebugGroupKHR() callconv(.C) void {
    return (function_pointers.glPopDebugGroupKHR orelse @panic("glPopDebugGroupKHR was not bound."))();
}

pub fn objectLabelKHR(_identifier: GLenum, _name: GLuint, _length: GLsizei, _label: [*c]const GLchar) callconv(.C) void {
    return (function_pointers.glObjectLabelKHR orelse @panic("glObjectLabelKHR was not bound."))(_identifier, _name, _length, _label);
}

pub fn getObjectLabelKHR(_identifier: GLenum, _name: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _label: [*c]GLchar) callconv(.C) void {
    return (function_pointers.glGetObjectLabelKHR orelse @panic("glGetObjectLabelKHR was not bound."))(_identifier, _name, _bufSize, _length, _label);
}

pub fn objectPtrLabelKHR(_ptr: ?*const anyopaque, _length: GLsizei, _label: [*c]const GLchar) callconv(.C) void {
    return (function_pointers.glObjectPtrLabelKHR orelse @panic("glObjectPtrLabelKHR was not bound."))(_ptr, _length, _label);
}

pub fn getObjectPtrLabelKHR(_ptr: ?*const anyopaque, _bufSize: GLsizei, _length: [*c]GLsizei, _label: [*c]GLchar) callconv(.C) void {
    return (function_pointers.glGetObjectPtrLabelKHR orelse @panic("glGetObjectPtrLabelKHR was not bound."))(_ptr, _bufSize, _length, _label);
}

pub fn getPointervKHR(_pname: GLenum, _params: ?*?*anyopaque) callconv(.C) void {
    return (function_pointers.glGetPointervKHR orelse @panic("glGetPointervKHR was not bound."))(_pname, _params);
}

pub fn load(load_ctx: anytype, get_proc_address: fn(@TypeOf(load_ctx), [:0]const u8) ?FunctionPointer) !void {
    var success = true;
    if(get_proc_address(load_ctx, "glDebugMessageControlKHR")) |proc| {
        function_pointers.glDebugMessageControlKHR = @ptrCast(@TypeOf(function_pointers.glDebugMessageControlKHR),  proc);
    } else {
        log.err("entry point glDebugMessageControlKHR not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDebugMessageInsertKHR")) |proc| {
        function_pointers.glDebugMessageInsertKHR = @ptrCast(@TypeOf(function_pointers.glDebugMessageInsertKHR),  proc);
    } else {
        log.err("entry point glDebugMessageInsertKHR not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDebugMessageCallbackKHR")) |proc| {
        function_pointers.glDebugMessageCallbackKHR = @ptrCast(@TypeOf(function_pointers.glDebugMessageCallbackKHR),  proc);
    } else {
        log.err("entry point glDebugMessageCallbackKHR not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetDebugMessageLogKHR")) |proc| {
        function_pointers.glGetDebugMessageLogKHR = @ptrCast(@TypeOf(function_pointers.glGetDebugMessageLogKHR),  proc);
    } else {
        log.err("entry point glGetDebugMessageLogKHR not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glPushDebugGroupKHR")) |proc| {
        function_pointers.glPushDebugGroupKHR = @ptrCast(@TypeOf(function_pointers.glPushDebugGroupKHR),  proc);
    } else {
        log.err("entry point glPushDebugGroupKHR not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glPopDebugGroupKHR")) |proc| {
        function_pointers.glPopDebugGroupKHR = @ptrCast(@TypeOf(function_pointers.glPopDebugGroupKHR),  proc);
    } else {
        log.err("entry point glPopDebugGroupKHR not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glObjectLabelKHR")) |proc| {
        function_pointers.glObjectLabelKHR = @ptrCast(@TypeOf(function_pointers.glObjectLabelKHR),  proc);
    } else {
        log.err("entry point glObjectLabelKHR not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetObjectLabelKHR")) |proc| {
        function_pointers.glGetObjectLabelKHR = @ptrCast(@TypeOf(function_pointers.glGetObjectLabelKHR),  proc);
    } else {
        log.err("entry point glGetObjectLabelKHR not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glObjectPtrLabelKHR")) |proc| {
        function_pointers.glObjectPtrLabelKHR = @ptrCast(@TypeOf(function_pointers.glObjectPtrLabelKHR),  proc);
    } else {
        log.err("entry point glObjectPtrLabelKHR not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetObjectPtrLabelKHR")) |proc| {
        function_pointers.glGetObjectPtrLabelKHR = @ptrCast(@TypeOf(function_pointers.glGetObjectPtrLabelKHR),  proc);
    } else {
        log.err("entry point glGetObjectPtrLabelKHR not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetPointervKHR")) |proc| {
        function_pointers.glGetPointervKHR = @ptrCast(@TypeOf(function_pointers.glGetPointervKHR),  proc);
    } else {
        log.err("entry point glGetPointervKHR not found!", .{});
        success = false;
    }
    if(!success)
        return error.EntryPointNotFound;
}
};

// Loader API:
pub fn load(load_ctx: anytype, get_proc_address: fn(@TypeOf(load_ctx), [:0]const u8) ?FunctionPointer) !void {
    var success = true;
    if(get_proc_address(load_ctx, "glActiveTexture")) |proc| {
        function_pointers.glActiveTexture = @ptrCast(@TypeOf(function_pointers.glActiveTexture),  proc);
    } else {
        log.err("entry point glActiveTexture not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glAttachShader")) |proc| {
        function_pointers.glAttachShader = @ptrCast(@TypeOf(function_pointers.glAttachShader),  proc);
    } else {
        log.err("entry point glAttachShader not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glBindAttribLocation")) |proc| {
        function_pointers.glBindAttribLocation = @ptrCast(@TypeOf(function_pointers.glBindAttribLocation),  proc);
    } else {
        log.err("entry point glBindAttribLocation not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glBindBuffer")) |proc| {
        function_pointers.glBindBuffer = @ptrCast(@TypeOf(function_pointers.glBindBuffer),  proc);
    } else {
        log.err("entry point glBindBuffer not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glBindFramebuffer")) |proc| {
        function_pointers.glBindFramebuffer = @ptrCast(@TypeOf(function_pointers.glBindFramebuffer),  proc);
    } else {
        log.err("entry point glBindFramebuffer not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glBindRenderbuffer")) |proc| {
        function_pointers.glBindRenderbuffer = @ptrCast(@TypeOf(function_pointers.glBindRenderbuffer),  proc);
    } else {
        log.err("entry point glBindRenderbuffer not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glBindTexture")) |proc| {
        function_pointers.glBindTexture = @ptrCast(@TypeOf(function_pointers.glBindTexture),  proc);
    } else {
        log.err("entry point glBindTexture not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glBlendColor")) |proc| {
        function_pointers.glBlendColor = @ptrCast(@TypeOf(function_pointers.glBlendColor),  proc);
    } else {
        log.err("entry point glBlendColor not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glBlendEquation")) |proc| {
        function_pointers.glBlendEquation = @ptrCast(@TypeOf(function_pointers.glBlendEquation),  proc);
    } else {
        log.err("entry point glBlendEquation not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glBlendEquationSeparate")) |proc| {
        function_pointers.glBlendEquationSeparate = @ptrCast(@TypeOf(function_pointers.glBlendEquationSeparate),  proc);
    } else {
        log.err("entry point glBlendEquationSeparate not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glBlendFunc")) |proc| {
        function_pointers.glBlendFunc = @ptrCast(@TypeOf(function_pointers.glBlendFunc),  proc);
    } else {
        log.err("entry point glBlendFunc not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glBlendFuncSeparate")) |proc| {
        function_pointers.glBlendFuncSeparate = @ptrCast(@TypeOf(function_pointers.glBlendFuncSeparate),  proc);
    } else {
        log.err("entry point glBlendFuncSeparate not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glBufferData")) |proc| {
        function_pointers.glBufferData = @ptrCast(@TypeOf(function_pointers.glBufferData),  proc);
    } else {
        log.err("entry point glBufferData not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glBufferSubData")) |proc| {
        function_pointers.glBufferSubData = @ptrCast(@TypeOf(function_pointers.glBufferSubData),  proc);
    } else {
        log.err("entry point glBufferSubData not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glCheckFramebufferStatus")) |proc| {
        function_pointers.glCheckFramebufferStatus = @ptrCast(@TypeOf(function_pointers.glCheckFramebufferStatus),  proc);
    } else {
        log.err("entry point glCheckFramebufferStatus not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glClear")) |proc| {
        function_pointers.glClear = @ptrCast(@TypeOf(function_pointers.glClear),  proc);
    } else {
        log.err("entry point glClear not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glClearColor")) |proc| {
        function_pointers.glClearColor = @ptrCast(@TypeOf(function_pointers.glClearColor),  proc);
    } else {
        log.err("entry point glClearColor not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glClearDepthf")) |proc| {
        function_pointers.glClearDepthf = @ptrCast(@TypeOf(function_pointers.glClearDepthf),  proc);
    } else {
        log.err("entry point glClearDepthf not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glClearStencil")) |proc| {
        function_pointers.glClearStencil = @ptrCast(@TypeOf(function_pointers.glClearStencil),  proc);
    } else {
        log.err("entry point glClearStencil not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glColorMask")) |proc| {
        function_pointers.glColorMask = @ptrCast(@TypeOf(function_pointers.glColorMask),  proc);
    } else {
        log.err("entry point glColorMask not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glCompileShader")) |proc| {
        function_pointers.glCompileShader = @ptrCast(@TypeOf(function_pointers.glCompileShader),  proc);
    } else {
        log.err("entry point glCompileShader not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glCompressedTexImage2D")) |proc| {
        function_pointers.glCompressedTexImage2D = @ptrCast(@TypeOf(function_pointers.glCompressedTexImage2D),  proc);
    } else {
        log.err("entry point glCompressedTexImage2D not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glCompressedTexSubImage2D")) |proc| {
        function_pointers.glCompressedTexSubImage2D = @ptrCast(@TypeOf(function_pointers.glCompressedTexSubImage2D),  proc);
    } else {
        log.err("entry point glCompressedTexSubImage2D not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glCopyTexImage2D")) |proc| {
        function_pointers.glCopyTexImage2D = @ptrCast(@TypeOf(function_pointers.glCopyTexImage2D),  proc);
    } else {
        log.err("entry point glCopyTexImage2D not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glCopyTexSubImage2D")) |proc| {
        function_pointers.glCopyTexSubImage2D = @ptrCast(@TypeOf(function_pointers.glCopyTexSubImage2D),  proc);
    } else {
        log.err("entry point glCopyTexSubImage2D not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glCreateProgram")) |proc| {
        function_pointers.glCreateProgram = @ptrCast(@TypeOf(function_pointers.glCreateProgram),  proc);
    } else {
        log.err("entry point glCreateProgram not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glCreateShader")) |proc| {
        function_pointers.glCreateShader = @ptrCast(@TypeOf(function_pointers.glCreateShader),  proc);
    } else {
        log.err("entry point glCreateShader not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glCullFace")) |proc| {
        function_pointers.glCullFace = @ptrCast(@TypeOf(function_pointers.glCullFace),  proc);
    } else {
        log.err("entry point glCullFace not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDeleteBuffers")) |proc| {
        function_pointers.glDeleteBuffers = @ptrCast(@TypeOf(function_pointers.glDeleteBuffers),  proc);
    } else {
        log.err("entry point glDeleteBuffers not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDeleteFramebuffers")) |proc| {
        function_pointers.glDeleteFramebuffers = @ptrCast(@TypeOf(function_pointers.glDeleteFramebuffers),  proc);
    } else {
        log.err("entry point glDeleteFramebuffers not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDeleteProgram")) |proc| {
        function_pointers.glDeleteProgram = @ptrCast(@TypeOf(function_pointers.glDeleteProgram),  proc);
    } else {
        log.err("entry point glDeleteProgram not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDeleteRenderbuffers")) |proc| {
        function_pointers.glDeleteRenderbuffers = @ptrCast(@TypeOf(function_pointers.glDeleteRenderbuffers),  proc);
    } else {
        log.err("entry point glDeleteRenderbuffers not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDeleteShader")) |proc| {
        function_pointers.glDeleteShader = @ptrCast(@TypeOf(function_pointers.glDeleteShader),  proc);
    } else {
        log.err("entry point glDeleteShader not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDeleteTextures")) |proc| {
        function_pointers.glDeleteTextures = @ptrCast(@TypeOf(function_pointers.glDeleteTextures),  proc);
    } else {
        log.err("entry point glDeleteTextures not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDepthFunc")) |proc| {
        function_pointers.glDepthFunc = @ptrCast(@TypeOf(function_pointers.glDepthFunc),  proc);
    } else {
        log.err("entry point glDepthFunc not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDepthMask")) |proc| {
        function_pointers.glDepthMask = @ptrCast(@TypeOf(function_pointers.glDepthMask),  proc);
    } else {
        log.err("entry point glDepthMask not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDepthRangef")) |proc| {
        function_pointers.glDepthRangef = @ptrCast(@TypeOf(function_pointers.glDepthRangef),  proc);
    } else {
        log.err("entry point glDepthRangef not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDetachShader")) |proc| {
        function_pointers.glDetachShader = @ptrCast(@TypeOf(function_pointers.glDetachShader),  proc);
    } else {
        log.err("entry point glDetachShader not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDisable")) |proc| {
        function_pointers.glDisable = @ptrCast(@TypeOf(function_pointers.glDisable),  proc);
    } else {
        log.err("entry point glDisable not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDisableVertexAttribArray")) |proc| {
        function_pointers.glDisableVertexAttribArray = @ptrCast(@TypeOf(function_pointers.glDisableVertexAttribArray),  proc);
    } else {
        log.err("entry point glDisableVertexAttribArray not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDrawArrays")) |proc| {
        function_pointers.glDrawArrays = @ptrCast(@TypeOf(function_pointers.glDrawArrays),  proc);
    } else {
        log.err("entry point glDrawArrays not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glDrawElements")) |proc| {
        function_pointers.glDrawElements = @ptrCast(@TypeOf(function_pointers.glDrawElements),  proc);
    } else {
        log.err("entry point glDrawElements not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glEnable")) |proc| {
        function_pointers.glEnable = @ptrCast(@TypeOf(function_pointers.glEnable),  proc);
    } else {
        log.err("entry point glEnable not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glEnableVertexAttribArray")) |proc| {
        function_pointers.glEnableVertexAttribArray = @ptrCast(@TypeOf(function_pointers.glEnableVertexAttribArray),  proc);
    } else {
        log.err("entry point glEnableVertexAttribArray not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glFinish")) |proc| {
        function_pointers.glFinish = @ptrCast(@TypeOf(function_pointers.glFinish),  proc);
    } else {
        log.err("entry point glFinish not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glFlush")) |proc| {
        function_pointers.glFlush = @ptrCast(@TypeOf(function_pointers.glFlush),  proc);
    } else {
        log.err("entry point glFlush not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glFramebufferRenderbuffer")) |proc| {
        function_pointers.glFramebufferRenderbuffer = @ptrCast(@TypeOf(function_pointers.glFramebufferRenderbuffer),  proc);
    } else {
        log.err("entry point glFramebufferRenderbuffer not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glFramebufferTexture2D")) |proc| {
        function_pointers.glFramebufferTexture2D = @ptrCast(@TypeOf(function_pointers.glFramebufferTexture2D),  proc);
    } else {
        log.err("entry point glFramebufferTexture2D not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glFrontFace")) |proc| {
        function_pointers.glFrontFace = @ptrCast(@TypeOf(function_pointers.glFrontFace),  proc);
    } else {
        log.err("entry point glFrontFace not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGenBuffers")) |proc| {
        function_pointers.glGenBuffers = @ptrCast(@TypeOf(function_pointers.glGenBuffers),  proc);
    } else {
        log.err("entry point glGenBuffers not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGenerateMipmap")) |proc| {
        function_pointers.glGenerateMipmap = @ptrCast(@TypeOf(function_pointers.glGenerateMipmap),  proc);
    } else {
        log.err("entry point glGenerateMipmap not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGenFramebuffers")) |proc| {
        function_pointers.glGenFramebuffers = @ptrCast(@TypeOf(function_pointers.glGenFramebuffers),  proc);
    } else {
        log.err("entry point glGenFramebuffers not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGenRenderbuffers")) |proc| {
        function_pointers.glGenRenderbuffers = @ptrCast(@TypeOf(function_pointers.glGenRenderbuffers),  proc);
    } else {
        log.err("entry point glGenRenderbuffers not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGenTextures")) |proc| {
        function_pointers.glGenTextures = @ptrCast(@TypeOf(function_pointers.glGenTextures),  proc);
    } else {
        log.err("entry point glGenTextures not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetActiveAttrib")) |proc| {
        function_pointers.glGetActiveAttrib = @ptrCast(@TypeOf(function_pointers.glGetActiveAttrib),  proc);
    } else {
        log.err("entry point glGetActiveAttrib not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetActiveUniform")) |proc| {
        function_pointers.glGetActiveUniform = @ptrCast(@TypeOf(function_pointers.glGetActiveUniform),  proc);
    } else {
        log.err("entry point glGetActiveUniform not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetAttachedShaders")) |proc| {
        function_pointers.glGetAttachedShaders = @ptrCast(@TypeOf(function_pointers.glGetAttachedShaders),  proc);
    } else {
        log.err("entry point glGetAttachedShaders not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetAttribLocation")) |proc| {
        function_pointers.glGetAttribLocation = @ptrCast(@TypeOf(function_pointers.glGetAttribLocation),  proc);
    } else {
        log.err("entry point glGetAttribLocation not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetBooleanv")) |proc| {
        function_pointers.glGetBooleanv = @ptrCast(@TypeOf(function_pointers.glGetBooleanv),  proc);
    } else {
        log.err("entry point glGetBooleanv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetBufferParameteriv")) |proc| {
        function_pointers.glGetBufferParameteriv = @ptrCast(@TypeOf(function_pointers.glGetBufferParameteriv),  proc);
    } else {
        log.err("entry point glGetBufferParameteriv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetError")) |proc| {
        function_pointers.glGetError = @ptrCast(@TypeOf(function_pointers.glGetError),  proc);
    } else {
        log.err("entry point glGetError not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetFloatv")) |proc| {
        function_pointers.glGetFloatv = @ptrCast(@TypeOf(function_pointers.glGetFloatv),  proc);
    } else {
        log.err("entry point glGetFloatv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetFramebufferAttachmentParameteriv")) |proc| {
        function_pointers.glGetFramebufferAttachmentParameteriv = @ptrCast(@TypeOf(function_pointers.glGetFramebufferAttachmentParameteriv),  proc);
    } else {
        log.err("entry point glGetFramebufferAttachmentParameteriv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetIntegerv")) |proc| {
        function_pointers.glGetIntegerv = @ptrCast(@TypeOf(function_pointers.glGetIntegerv),  proc);
    } else {
        log.err("entry point glGetIntegerv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetProgramiv")) |proc| {
        function_pointers.glGetProgramiv = @ptrCast(@TypeOf(function_pointers.glGetProgramiv),  proc);
    } else {
        log.err("entry point glGetProgramiv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetProgramInfoLog")) |proc| {
        function_pointers.glGetProgramInfoLog = @ptrCast(@TypeOf(function_pointers.glGetProgramInfoLog),  proc);
    } else {
        log.err("entry point glGetProgramInfoLog not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetRenderbufferParameteriv")) |proc| {
        function_pointers.glGetRenderbufferParameteriv = @ptrCast(@TypeOf(function_pointers.glGetRenderbufferParameteriv),  proc);
    } else {
        log.err("entry point glGetRenderbufferParameteriv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetShaderiv")) |proc| {
        function_pointers.glGetShaderiv = @ptrCast(@TypeOf(function_pointers.glGetShaderiv),  proc);
    } else {
        log.err("entry point glGetShaderiv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetShaderInfoLog")) |proc| {
        function_pointers.glGetShaderInfoLog = @ptrCast(@TypeOf(function_pointers.glGetShaderInfoLog),  proc);
    } else {
        log.err("entry point glGetShaderInfoLog not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetShaderPrecisionFormat")) |proc| {
        function_pointers.glGetShaderPrecisionFormat = @ptrCast(@TypeOf(function_pointers.glGetShaderPrecisionFormat),  proc);
    } else {
        log.err("entry point glGetShaderPrecisionFormat not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetShaderSource")) |proc| {
        function_pointers.glGetShaderSource = @ptrCast(@TypeOf(function_pointers.glGetShaderSource),  proc);
    } else {
        log.err("entry point glGetShaderSource not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetString")) |proc| {
        function_pointers.glGetString = @ptrCast(@TypeOf(function_pointers.glGetString),  proc);
    } else {
        log.err("entry point glGetString not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetTexParameterfv")) |proc| {
        function_pointers.glGetTexParameterfv = @ptrCast(@TypeOf(function_pointers.glGetTexParameterfv),  proc);
    } else {
        log.err("entry point glGetTexParameterfv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetTexParameteriv")) |proc| {
        function_pointers.glGetTexParameteriv = @ptrCast(@TypeOf(function_pointers.glGetTexParameteriv),  proc);
    } else {
        log.err("entry point glGetTexParameteriv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetUniformfv")) |proc| {
        function_pointers.glGetUniformfv = @ptrCast(@TypeOf(function_pointers.glGetUniformfv),  proc);
    } else {
        log.err("entry point glGetUniformfv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetUniformiv")) |proc| {
        function_pointers.glGetUniformiv = @ptrCast(@TypeOf(function_pointers.glGetUniformiv),  proc);
    } else {
        log.err("entry point glGetUniformiv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetUniformLocation")) |proc| {
        function_pointers.glGetUniformLocation = @ptrCast(@TypeOf(function_pointers.glGetUniformLocation),  proc);
    } else {
        log.err("entry point glGetUniformLocation not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetVertexAttribfv")) |proc| {
        function_pointers.glGetVertexAttribfv = @ptrCast(@TypeOf(function_pointers.glGetVertexAttribfv),  proc);
    } else {
        log.err("entry point glGetVertexAttribfv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetVertexAttribiv")) |proc| {
        function_pointers.glGetVertexAttribiv = @ptrCast(@TypeOf(function_pointers.glGetVertexAttribiv),  proc);
    } else {
        log.err("entry point glGetVertexAttribiv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glGetVertexAttribPointerv")) |proc| {
        function_pointers.glGetVertexAttribPointerv = @ptrCast(@TypeOf(function_pointers.glGetVertexAttribPointerv),  proc);
    } else {
        log.err("entry point glGetVertexAttribPointerv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glHint")) |proc| {
        function_pointers.glHint = @ptrCast(@TypeOf(function_pointers.glHint),  proc);
    } else {
        log.err("entry point glHint not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glIsBuffer")) |proc| {
        function_pointers.glIsBuffer = @ptrCast(@TypeOf(function_pointers.glIsBuffer),  proc);
    } else {
        log.err("entry point glIsBuffer not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glIsEnabled")) |proc| {
        function_pointers.glIsEnabled = @ptrCast(@TypeOf(function_pointers.glIsEnabled),  proc);
    } else {
        log.err("entry point glIsEnabled not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glIsFramebuffer")) |proc| {
        function_pointers.glIsFramebuffer = @ptrCast(@TypeOf(function_pointers.glIsFramebuffer),  proc);
    } else {
        log.err("entry point glIsFramebuffer not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glIsProgram")) |proc| {
        function_pointers.glIsProgram = @ptrCast(@TypeOf(function_pointers.glIsProgram),  proc);
    } else {
        log.err("entry point glIsProgram not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glIsRenderbuffer")) |proc| {
        function_pointers.glIsRenderbuffer = @ptrCast(@TypeOf(function_pointers.glIsRenderbuffer),  proc);
    } else {
        log.err("entry point glIsRenderbuffer not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glIsShader")) |proc| {
        function_pointers.glIsShader = @ptrCast(@TypeOf(function_pointers.glIsShader),  proc);
    } else {
        log.err("entry point glIsShader not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glIsTexture")) |proc| {
        function_pointers.glIsTexture = @ptrCast(@TypeOf(function_pointers.glIsTexture),  proc);
    } else {
        log.err("entry point glIsTexture not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glLineWidth")) |proc| {
        function_pointers.glLineWidth = @ptrCast(@TypeOf(function_pointers.glLineWidth),  proc);
    } else {
        log.err("entry point glLineWidth not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glLinkProgram")) |proc| {
        function_pointers.glLinkProgram = @ptrCast(@TypeOf(function_pointers.glLinkProgram),  proc);
    } else {
        log.err("entry point glLinkProgram not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glPixelStorei")) |proc| {
        function_pointers.glPixelStorei = @ptrCast(@TypeOf(function_pointers.glPixelStorei),  proc);
    } else {
        log.err("entry point glPixelStorei not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glPolygonOffset")) |proc| {
        function_pointers.glPolygonOffset = @ptrCast(@TypeOf(function_pointers.glPolygonOffset),  proc);
    } else {
        log.err("entry point glPolygonOffset not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glReadPixels")) |proc| {
        function_pointers.glReadPixels = @ptrCast(@TypeOf(function_pointers.glReadPixels),  proc);
    } else {
        log.err("entry point glReadPixels not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glReleaseShaderCompiler")) |proc| {
        function_pointers.glReleaseShaderCompiler = @ptrCast(@TypeOf(function_pointers.glReleaseShaderCompiler),  proc);
    } else {
        log.err("entry point glReleaseShaderCompiler not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glRenderbufferStorage")) |proc| {
        function_pointers.glRenderbufferStorage = @ptrCast(@TypeOf(function_pointers.glRenderbufferStorage),  proc);
    } else {
        log.err("entry point glRenderbufferStorage not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glSampleCoverage")) |proc| {
        function_pointers.glSampleCoverage = @ptrCast(@TypeOf(function_pointers.glSampleCoverage),  proc);
    } else {
        log.err("entry point glSampleCoverage not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glScissor")) |proc| {
        function_pointers.glScissor = @ptrCast(@TypeOf(function_pointers.glScissor),  proc);
    } else {
        log.err("entry point glScissor not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glShaderBinary")) |proc| {
        function_pointers.glShaderBinary = @ptrCast(@TypeOf(function_pointers.glShaderBinary),  proc);
    } else {
        log.err("entry point glShaderBinary not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glShaderSource")) |proc| {
        function_pointers.glShaderSource = @ptrCast(@TypeOf(function_pointers.glShaderSource),  proc);
    } else {
        log.err("entry point glShaderSource not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glStencilFunc")) |proc| {
        function_pointers.glStencilFunc = @ptrCast(@TypeOf(function_pointers.glStencilFunc),  proc);
    } else {
        log.err("entry point glStencilFunc not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glStencilFuncSeparate")) |proc| {
        function_pointers.glStencilFuncSeparate = @ptrCast(@TypeOf(function_pointers.glStencilFuncSeparate),  proc);
    } else {
        log.err("entry point glStencilFuncSeparate not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glStencilMask")) |proc| {
        function_pointers.glStencilMask = @ptrCast(@TypeOf(function_pointers.glStencilMask),  proc);
    } else {
        log.err("entry point glStencilMask not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glStencilMaskSeparate")) |proc| {
        function_pointers.glStencilMaskSeparate = @ptrCast(@TypeOf(function_pointers.glStencilMaskSeparate),  proc);
    } else {
        log.err("entry point glStencilMaskSeparate not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glStencilOp")) |proc| {
        function_pointers.glStencilOp = @ptrCast(@TypeOf(function_pointers.glStencilOp),  proc);
    } else {
        log.err("entry point glStencilOp not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glStencilOpSeparate")) |proc| {
        function_pointers.glStencilOpSeparate = @ptrCast(@TypeOf(function_pointers.glStencilOpSeparate),  proc);
    } else {
        log.err("entry point glStencilOpSeparate not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glTexImage2D")) |proc| {
        function_pointers.glTexImage2D = @ptrCast(@TypeOf(function_pointers.glTexImage2D),  proc);
    } else {
        log.err("entry point glTexImage2D not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glTexParameterf")) |proc| {
        function_pointers.glTexParameterf = @ptrCast(@TypeOf(function_pointers.glTexParameterf),  proc);
    } else {
        log.err("entry point glTexParameterf not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glTexParameterfv")) |proc| {
        function_pointers.glTexParameterfv = @ptrCast(@TypeOf(function_pointers.glTexParameterfv),  proc);
    } else {
        log.err("entry point glTexParameterfv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glTexParameteri")) |proc| {
        function_pointers.glTexParameteri = @ptrCast(@TypeOf(function_pointers.glTexParameteri),  proc);
    } else {
        log.err("entry point glTexParameteri not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glTexParameteriv")) |proc| {
        function_pointers.glTexParameteriv = @ptrCast(@TypeOf(function_pointers.glTexParameteriv),  proc);
    } else {
        log.err("entry point glTexParameteriv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glTexSubImage2D")) |proc| {
        function_pointers.glTexSubImage2D = @ptrCast(@TypeOf(function_pointers.glTexSubImage2D),  proc);
    } else {
        log.err("entry point glTexSubImage2D not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform1f")) |proc| {
        function_pointers.glUniform1f = @ptrCast(@TypeOf(function_pointers.glUniform1f),  proc);
    } else {
        log.err("entry point glUniform1f not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform1fv")) |proc| {
        function_pointers.glUniform1fv = @ptrCast(@TypeOf(function_pointers.glUniform1fv),  proc);
    } else {
        log.err("entry point glUniform1fv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform1i")) |proc| {
        function_pointers.glUniform1i = @ptrCast(@TypeOf(function_pointers.glUniform1i),  proc);
    } else {
        log.err("entry point glUniform1i not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform1iv")) |proc| {
        function_pointers.glUniform1iv = @ptrCast(@TypeOf(function_pointers.glUniform1iv),  proc);
    } else {
        log.err("entry point glUniform1iv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform2f")) |proc| {
        function_pointers.glUniform2f = @ptrCast(@TypeOf(function_pointers.glUniform2f),  proc);
    } else {
        log.err("entry point glUniform2f not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform2fv")) |proc| {
        function_pointers.glUniform2fv = @ptrCast(@TypeOf(function_pointers.glUniform2fv),  proc);
    } else {
        log.err("entry point glUniform2fv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform2i")) |proc| {
        function_pointers.glUniform2i = @ptrCast(@TypeOf(function_pointers.glUniform2i),  proc);
    } else {
        log.err("entry point glUniform2i not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform2iv")) |proc| {
        function_pointers.glUniform2iv = @ptrCast(@TypeOf(function_pointers.glUniform2iv),  proc);
    } else {
        log.err("entry point glUniform2iv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform3f")) |proc| {
        function_pointers.glUniform3f = @ptrCast(@TypeOf(function_pointers.glUniform3f),  proc);
    } else {
        log.err("entry point glUniform3f not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform3fv")) |proc| {
        function_pointers.glUniform3fv = @ptrCast(@TypeOf(function_pointers.glUniform3fv),  proc);
    } else {
        log.err("entry point glUniform3fv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform3i")) |proc| {
        function_pointers.glUniform3i = @ptrCast(@TypeOf(function_pointers.glUniform3i),  proc);
    } else {
        log.err("entry point glUniform3i not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform3iv")) |proc| {
        function_pointers.glUniform3iv = @ptrCast(@TypeOf(function_pointers.glUniform3iv),  proc);
    } else {
        log.err("entry point glUniform3iv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform4f")) |proc| {
        function_pointers.glUniform4f = @ptrCast(@TypeOf(function_pointers.glUniform4f),  proc);
    } else {
        log.err("entry point glUniform4f not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform4fv")) |proc| {
        function_pointers.glUniform4fv = @ptrCast(@TypeOf(function_pointers.glUniform4fv),  proc);
    } else {
        log.err("entry point glUniform4fv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform4i")) |proc| {
        function_pointers.glUniform4i = @ptrCast(@TypeOf(function_pointers.glUniform4i),  proc);
    } else {
        log.err("entry point glUniform4i not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniform4iv")) |proc| {
        function_pointers.glUniform4iv = @ptrCast(@TypeOf(function_pointers.glUniform4iv),  proc);
    } else {
        log.err("entry point glUniform4iv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniformMatrix2fv")) |proc| {
        function_pointers.glUniformMatrix2fv = @ptrCast(@TypeOf(function_pointers.glUniformMatrix2fv),  proc);
    } else {
        log.err("entry point glUniformMatrix2fv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniformMatrix3fv")) |proc| {
        function_pointers.glUniformMatrix3fv = @ptrCast(@TypeOf(function_pointers.glUniformMatrix3fv),  proc);
    } else {
        log.err("entry point glUniformMatrix3fv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUniformMatrix4fv")) |proc| {
        function_pointers.glUniformMatrix4fv = @ptrCast(@TypeOf(function_pointers.glUniformMatrix4fv),  proc);
    } else {
        log.err("entry point glUniformMatrix4fv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glUseProgram")) |proc| {
        function_pointers.glUseProgram = @ptrCast(@TypeOf(function_pointers.glUseProgram),  proc);
    } else {
        log.err("entry point glUseProgram not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glValidateProgram")) |proc| {
        function_pointers.glValidateProgram = @ptrCast(@TypeOf(function_pointers.glValidateProgram),  proc);
    } else {
        log.err("entry point glValidateProgram not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glVertexAttrib1f")) |proc| {
        function_pointers.glVertexAttrib1f = @ptrCast(@TypeOf(function_pointers.glVertexAttrib1f),  proc);
    } else {
        log.err("entry point glVertexAttrib1f not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glVertexAttrib1fv")) |proc| {
        function_pointers.glVertexAttrib1fv = @ptrCast(@TypeOf(function_pointers.glVertexAttrib1fv),  proc);
    } else {
        log.err("entry point glVertexAttrib1fv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glVertexAttrib2f")) |proc| {
        function_pointers.glVertexAttrib2f = @ptrCast(@TypeOf(function_pointers.glVertexAttrib2f),  proc);
    } else {
        log.err("entry point glVertexAttrib2f not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glVertexAttrib2fv")) |proc| {
        function_pointers.glVertexAttrib2fv = @ptrCast(@TypeOf(function_pointers.glVertexAttrib2fv),  proc);
    } else {
        log.err("entry point glVertexAttrib2fv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glVertexAttrib3f")) |proc| {
        function_pointers.glVertexAttrib3f = @ptrCast(@TypeOf(function_pointers.glVertexAttrib3f),  proc);
    } else {
        log.err("entry point glVertexAttrib3f not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glVertexAttrib3fv")) |proc| {
        function_pointers.glVertexAttrib3fv = @ptrCast(@TypeOf(function_pointers.glVertexAttrib3fv),  proc);
    } else {
        log.err("entry point glVertexAttrib3fv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glVertexAttrib4f")) |proc| {
        function_pointers.glVertexAttrib4f = @ptrCast(@TypeOf(function_pointers.glVertexAttrib4f),  proc);
    } else {
        log.err("entry point glVertexAttrib4f not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glVertexAttrib4fv")) |proc| {
        function_pointers.glVertexAttrib4fv = @ptrCast(@TypeOf(function_pointers.glVertexAttrib4fv),  proc);
    } else {
        log.err("entry point glVertexAttrib4fv not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glVertexAttribPointer")) |proc| {
        function_pointers.glVertexAttribPointer = @ptrCast(@TypeOf(function_pointers.glVertexAttribPointer),  proc);
    } else {
        log.err("entry point glVertexAttribPointer not found!", .{});
        success = false;
    }
    if(get_proc_address(load_ctx, "glViewport")) |proc| {
        function_pointers.glViewport = @ptrCast(@TypeOf(function_pointers.glViewport),  proc);
    } else {
        log.err("entry point glViewport not found!", .{});
        success = false;
    }
    if(!success)
        return error.EntryPointNotFound;
}

const function_signatures = struct {
    const glActiveTexture = fn(_texture: GLenum) callconv(.C) void;
    const glAttachShader = fn(_program: GLuint, _shader: GLuint) callconv(.C) void;
    const glBindAttribLocation = fn(_program: GLuint, _index: GLuint, _name: [*c]const GLchar) callconv(.C) void;
    const glBindBuffer = fn(_target: GLenum, _buffer: GLuint) callconv(.C) void;
    const glBindFramebuffer = fn(_target: GLenum, _framebuffer: GLuint) callconv(.C) void;
    const glBindRenderbuffer = fn(_target: GLenum, _renderbuffer: GLuint) callconv(.C) void;
    const glBindTexture = fn(_target: GLenum, _texture: GLuint) callconv(.C) void;
    const glBlendColor = fn(_red: GLfloat, _green: GLfloat, _blue: GLfloat, _alpha: GLfloat) callconv(.C) void;
    const glBlendEquation = fn(_mode: GLenum) callconv(.C) void;
    const glBlendEquationSeparate = fn(_modeRGB: GLenum, _modeAlpha: GLenum) callconv(.C) void;
    const glBlendFunc = fn(_sfactor: GLenum, _dfactor: GLenum) callconv(.C) void;
    const glBlendFuncSeparate = fn(_sfactorRGB: GLenum, _dfactorRGB: GLenum, _sfactorAlpha: GLenum, _dfactorAlpha: GLenum) callconv(.C) void;
    const glBufferData = fn(_target: GLenum, _size: GLsizeiptr, _data: ?*const anyopaque, _usage: GLenum) callconv(.C) void;
    const glBufferSubData = fn(_target: GLenum, _offset: GLintptr, _size: GLsizeiptr, _data: ?*const anyopaque) callconv(.C) void;
    const glCheckFramebufferStatus = fn(_target: GLenum) callconv(.C) GLenum;
    const glClear = fn(_mask: GLbitfield) callconv(.C) void;
    const glClearColor = fn(_red: GLfloat, _green: GLfloat, _blue: GLfloat, _alpha: GLfloat) callconv(.C) void;
    const glClearDepthf = fn(_d: GLfloat) callconv(.C) void;
    const glClearStencil = fn(_s: GLint) callconv(.C) void;
    const glColorMask = fn(_red: GLboolean, _green: GLboolean, _blue: GLboolean, _alpha: GLboolean) callconv(.C) void;
    const glCompileShader = fn(_shader: GLuint) callconv(.C) void;
    const glCompressedTexImage2D = fn(_target: GLenum, _level: GLint, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _border: GLint, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void;
    const glCompressedTexSubImage2D = fn(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _imageSize: GLsizei, _data: ?*const anyopaque) callconv(.C) void;
    const glCopyTexImage2D = fn(_target: GLenum, _level: GLint, _internalformat: GLenum, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _border: GLint) callconv(.C) void;
    const glCopyTexSubImage2D = fn(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void;
    const glCreateProgram = fn() callconv(.C) GLuint;
    const glCreateShader = fn(_type: GLenum) callconv(.C) GLuint;
    const glCullFace = fn(_mode: GLenum) callconv(.C) void;
    const glDeleteBuffers = fn(_n: GLsizei, _buffers: [*c]const GLuint) callconv(.C) void;
    const glDeleteFramebuffers = fn(_n: GLsizei, _framebuffers: [*c]const GLuint) callconv(.C) void;
    const glDeleteProgram = fn(_program: GLuint) callconv(.C) void;
    const glDeleteRenderbuffers = fn(_n: GLsizei, _renderbuffers: [*c]const GLuint) callconv(.C) void;
    const glDeleteShader = fn(_shader: GLuint) callconv(.C) void;
    const glDeleteTextures = fn(_n: GLsizei, _textures: [*c]const GLuint) callconv(.C) void;
    const glDepthFunc = fn(_func: GLenum) callconv(.C) void;
    const glDepthMask = fn(_flag: GLboolean) callconv(.C) void;
    const glDepthRangef = fn(_n: GLfloat, _f: GLfloat) callconv(.C) void;
    const glDetachShader = fn(_program: GLuint, _shader: GLuint) callconv(.C) void;
    const glDisable = fn(_cap: GLenum) callconv(.C) void;
    const glDisableVertexAttribArray = fn(_index: GLuint) callconv(.C) void;
    const glDrawArrays = fn(_mode: GLenum, _first: GLint, _count: GLsizei) callconv(.C) void;
    const glDrawElements = fn(_mode: GLenum, _count: GLsizei, _type: GLenum, _indices: ?*const anyopaque) callconv(.C) void;
    const glEnable = fn(_cap: GLenum) callconv(.C) void;
    const glEnableVertexAttribArray = fn(_index: GLuint) callconv(.C) void;
    const glFinish = fn() callconv(.C) void;
    const glFlush = fn() callconv(.C) void;
    const glFramebufferRenderbuffer = fn(_target: GLenum, _attachment: GLenum, _renderbuffertarget: GLenum, _renderbuffer: GLuint) callconv(.C) void;
    const glFramebufferTexture2D = fn(_target: GLenum, _attachment: GLenum, _textarget: GLenum, _texture: GLuint, _level: GLint) callconv(.C) void;
    const glFrontFace = fn(_mode: GLenum) callconv(.C) void;
    const glGenBuffers = fn(_n: GLsizei, _buffers: [*c]GLuint) callconv(.C) void;
    const glGenerateMipmap = fn(_target: GLenum) callconv(.C) void;
    const glGenFramebuffers = fn(_n: GLsizei, _framebuffers: [*c]GLuint) callconv(.C) void;
    const glGenRenderbuffers = fn(_n: GLsizei, _renderbuffers: [*c]GLuint) callconv(.C) void;
    const glGenTextures = fn(_n: GLsizei, _textures: [*c]GLuint) callconv(.C) void;
    const glGetActiveAttrib = fn(_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) callconv(.C) void;
    const glGetActiveUniform = fn(_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) callconv(.C) void;
    const glGetAttachedShaders = fn(_program: GLuint, _maxCount: GLsizei, _count: [*c]GLsizei, _shaders: [*c]GLuint) callconv(.C) void;
    const glGetAttribLocation = fn(_program: GLuint, _name: [*c]const GLchar) callconv(.C) GLint;
    const glGetBooleanv = fn(_pname: GLenum, _data: [*c]GLboolean) callconv(.C) void;
    const glGetBufferParameteriv = fn(_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetError = fn() callconv(.C) GLenum;
    const glGetFloatv = fn(_pname: GLenum, _data: [*c]GLfloat) callconv(.C) void;
    const glGetFramebufferAttachmentParameteriv = fn(_target: GLenum, _attachment: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetIntegerv = fn(_pname: GLenum, _data: [*c]GLint) callconv(.C) void;
    const glGetProgramiv = fn(_program: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetProgramInfoLog = fn(_program: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _infoLog: [*c]GLchar) callconv(.C) void;
    const glGetRenderbufferParameteriv = fn(_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetShaderiv = fn(_shader: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetShaderInfoLog = fn(_shader: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _infoLog: [*c]GLchar) callconv(.C) void;
    const glGetShaderPrecisionFormat = fn(_shadertype: GLenum, _precisiontype: GLenum, _range: [*c]GLint, _precision: [*c]GLint) callconv(.C) void;
    const glGetShaderSource = fn(_shader: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _source: [*c]GLchar) callconv(.C) void;
    const glGetString = fn(_name: GLenum) callconv(.C) ?[*:0]const GLubyte;
    const glGetTexParameterfv = fn(_target: GLenum, _pname: GLenum, _params: [*c]GLfloat) callconv(.C) void;
    const glGetTexParameteriv = fn(_target: GLenum, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetUniformfv = fn(_program: GLuint, _location: GLint, _params: [*c]GLfloat) callconv(.C) void;
    const glGetUniformiv = fn(_program: GLuint, _location: GLint, _params: [*c]GLint) callconv(.C) void;
    const glGetUniformLocation = fn(_program: GLuint, _name: [*c]const GLchar) callconv(.C) GLint;
    const glGetVertexAttribfv = fn(_index: GLuint, _pname: GLenum, _params: [*c]GLfloat) callconv(.C) void;
    const glGetVertexAttribiv = fn(_index: GLuint, _pname: GLenum, _params: [*c]GLint) callconv(.C) void;
    const glGetVertexAttribPointerv = fn(_index: GLuint, _pname: GLenum, _pointer: ?*?*anyopaque) callconv(.C) void;
    const glHint = fn(_target: GLenum, _mode: GLenum) callconv(.C) void;
    const glIsBuffer = fn(_buffer: GLuint) callconv(.C) GLboolean;
    const glIsEnabled = fn(_cap: GLenum) callconv(.C) GLboolean;
    const glIsFramebuffer = fn(_framebuffer: GLuint) callconv(.C) GLboolean;
    const glIsProgram = fn(_program: GLuint) callconv(.C) GLboolean;
    const glIsRenderbuffer = fn(_renderbuffer: GLuint) callconv(.C) GLboolean;
    const glIsShader = fn(_shader: GLuint) callconv(.C) GLboolean;
    const glIsTexture = fn(_texture: GLuint) callconv(.C) GLboolean;
    const glLineWidth = fn(_width: GLfloat) callconv(.C) void;
    const glLinkProgram = fn(_program: GLuint) callconv(.C) void;
    const glPixelStorei = fn(_pname: GLenum, _param: GLint) callconv(.C) void;
    const glPolygonOffset = fn(_factor: GLfloat, _units: GLfloat) callconv(.C) void;
    const glReadPixels = fn(_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*anyopaque) callconv(.C) void;
    const glReleaseShaderCompiler = fn() callconv(.C) void;
    const glRenderbufferStorage = fn(_target: GLenum, _internalformat: GLenum, _width: GLsizei, _height: GLsizei) callconv(.C) void;
    const glSampleCoverage = fn(_value: GLfloat, _invert: GLboolean) callconv(.C) void;
    const glScissor = fn(_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void;
    const glShaderBinary = fn(_count: GLsizei, _shaders: [*c]const GLuint, _binaryFormat: GLenum, _binary: ?*const anyopaque, _length: GLsizei) callconv(.C) void;
    const glShaderSource = fn(_shader: GLuint, _count: GLsizei, _string: [*c]const [*c]const GLchar, _length: [*c]const GLint) callconv(.C) void;
    const glStencilFunc = fn(_func: GLenum, _ref: GLint, _mask: GLuint) callconv(.C) void;
    const glStencilFuncSeparate = fn(_face: GLenum, _func: GLenum, _ref: GLint, _mask: GLuint) callconv(.C) void;
    const glStencilMask = fn(_mask: GLuint) callconv(.C) void;
    const glStencilMaskSeparate = fn(_face: GLenum, _mask: GLuint) callconv(.C) void;
    const glStencilOp = fn(_fail: GLenum, _zfail: GLenum, _zpass: GLenum) callconv(.C) void;
    const glStencilOpSeparate = fn(_face: GLenum, _sfail: GLenum, _dpfail: GLenum, _dppass: GLenum) callconv(.C) void;
    const glTexImage2D = fn(_target: GLenum, _level: GLint, _internalformat: GLint, _width: GLsizei, _height: GLsizei, _border: GLint, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void;
    const glTexParameterf = fn(_target: GLenum, _pname: GLenum, _param: GLfloat) callconv(.C) void;
    const glTexParameterfv = fn(_target: GLenum, _pname: GLenum, _params: [*c]const GLfloat) callconv(.C) void;
    const glTexParameteri = fn(_target: GLenum, _pname: GLenum, _param: GLint) callconv(.C) void;
    const glTexParameteriv = fn(_target: GLenum, _pname: GLenum, _params: [*c]const GLint) callconv(.C) void;
    const glTexSubImage2D = fn(_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*const anyopaque) callconv(.C) void;
    const glUniform1f = fn(_location: GLint, _v0: GLfloat) callconv(.C) void;
    const glUniform1fv = fn(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniform1i = fn(_location: GLint, _v0: GLint) callconv(.C) void;
    const glUniform1iv = fn(_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void;
    const glUniform2f = fn(_location: GLint, _v0: GLfloat, _v1: GLfloat) callconv(.C) void;
    const glUniform2fv = fn(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniform2i = fn(_location: GLint, _v0: GLint, _v1: GLint) callconv(.C) void;
    const glUniform2iv = fn(_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void;
    const glUniform3f = fn(_location: GLint, _v0: GLfloat, _v1: GLfloat, _v2: GLfloat) callconv(.C) void;
    const glUniform3fv = fn(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniform3i = fn(_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint) callconv(.C) void;
    const glUniform3iv = fn(_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void;
    const glUniform4f = fn(_location: GLint, _v0: GLfloat, _v1: GLfloat, _v2: GLfloat, _v3: GLfloat) callconv(.C) void;
    const glUniform4fv = fn(_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniform4i = fn(_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint, _v3: GLint) callconv(.C) void;
    const glUniform4iv = fn(_location: GLint, _count: GLsizei, _value: [*c]const GLint) callconv(.C) void;
    const glUniformMatrix2fv = fn(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniformMatrix3fv = fn(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void;
    const glUniformMatrix4fv = fn(_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) callconv(.C) void;
    const glUseProgram = fn(_program: GLuint) callconv(.C) void;
    const glValidateProgram = fn(_program: GLuint) callconv(.C) void;
    const glVertexAttrib1f = fn(_index: GLuint, _x: GLfloat) callconv(.C) void;
    const glVertexAttrib1fv = fn(_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void;
    const glVertexAttrib2f = fn(_index: GLuint, _x: GLfloat, _y: GLfloat) callconv(.C) void;
    const glVertexAttrib2fv = fn(_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void;
    const glVertexAttrib3f = fn(_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat) callconv(.C) void;
    const glVertexAttrib3fv = fn(_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void;
    const glVertexAttrib4f = fn(_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat, _w: GLfloat) callconv(.C) void;
    const glVertexAttrib4fv = fn(_index: GLuint, _v: [*c]const GLfloat) callconv(.C) void;
    const glVertexAttribPointer = fn(_index: GLuint, _size: GLint, _type: GLenum, _normalized: GLboolean, _stride: GLsizei, _pointer: ?*const anyopaque) callconv(.C) void;
    const glViewport = fn(_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) callconv(.C) void;
    const glDebugMessageControlKHR = fn(_source: GLenum, _type: GLenum, _severity: GLenum, _count: GLsizei, _ids: [*c]const GLuint, _enabled: GLboolean) callconv(.C) void;
    const glDebugMessageInsertKHR = fn(_source: GLenum, _type: GLenum, _id: GLuint, _severity: GLenum, _length: GLsizei, _buf: [*c]const GLchar) callconv(.C) void;
    const glDebugMessageCallbackKHR = fn(_callback: GLDEBUGPROCKHR, _userParam: ?*const anyopaque) callconv(.C) void;
    const glGetDebugMessageLogKHR = fn(_count: GLuint, _bufSize: GLsizei, _sources: [*c]GLenum, _types: [*c]GLenum, _ids: [*c]GLuint, _severities: [*c]GLenum, _lengths: [*c]GLsizei, _messageLog: [*c]GLchar) callconv(.C) GLuint;
    const glPushDebugGroupKHR = fn(_source: GLenum, _id: GLuint, _length: GLsizei, _message: [*c]const GLchar) callconv(.C) void;
    const glPopDebugGroupKHR = fn() callconv(.C) void;
    const glObjectLabelKHR = fn(_identifier: GLenum, _name: GLuint, _length: GLsizei, _label: [*c]const GLchar) callconv(.C) void;
    const glGetObjectLabelKHR = fn(_identifier: GLenum, _name: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _label: [*c]GLchar) callconv(.C) void;
    const glObjectPtrLabelKHR = fn(_ptr: ?*const anyopaque, _length: GLsizei, _label: [*c]const GLchar) callconv(.C) void;
    const glGetObjectPtrLabelKHR = fn(_ptr: ?*const anyopaque, _bufSize: GLsizei, _length: [*c]GLsizei, _label: [*c]GLchar) callconv(.C) void;
    const glGetPointervKHR = fn(_pname: GLenum, _params: ?*?*anyopaque) callconv(.C) void;
};

const function_pointers = struct {
    var glActiveTexture: ?FnPtr(function_signatures.glActiveTexture) = null;
    var glAttachShader: ?FnPtr(function_signatures.glAttachShader) = null;
    var glBindAttribLocation: ?FnPtr(function_signatures.glBindAttribLocation) = null;
    var glBindBuffer: ?FnPtr(function_signatures.glBindBuffer) = null;
    var glBindFramebuffer: ?FnPtr(function_signatures.glBindFramebuffer) = null;
    var glBindRenderbuffer: ?FnPtr(function_signatures.glBindRenderbuffer) = null;
    var glBindTexture: ?FnPtr(function_signatures.glBindTexture) = null;
    var glBlendColor: ?FnPtr(function_signatures.glBlendColor) = null;
    var glBlendEquation: ?FnPtr(function_signatures.glBlendEquation) = null;
    var glBlendEquationSeparate: ?FnPtr(function_signatures.glBlendEquationSeparate) = null;
    var glBlendFunc: ?FnPtr(function_signatures.glBlendFunc) = null;
    var glBlendFuncSeparate: ?FnPtr(function_signatures.glBlendFuncSeparate) = null;
    var glBufferData: ?FnPtr(function_signatures.glBufferData) = null;
    var glBufferSubData: ?FnPtr(function_signatures.glBufferSubData) = null;
    var glCheckFramebufferStatus: ?FnPtr(function_signatures.glCheckFramebufferStatus) = null;
    var glClear: ?FnPtr(function_signatures.glClear) = null;
    var glClearColor: ?FnPtr(function_signatures.glClearColor) = null;
    var glClearDepthf: ?FnPtr(function_signatures.glClearDepthf) = null;
    var glClearStencil: ?FnPtr(function_signatures.glClearStencil) = null;
    var glColorMask: ?FnPtr(function_signatures.glColorMask) = null;
    var glCompileShader: ?FnPtr(function_signatures.glCompileShader) = null;
    var glCompressedTexImage2D: ?FnPtr(function_signatures.glCompressedTexImage2D) = null;
    var glCompressedTexSubImage2D: ?FnPtr(function_signatures.glCompressedTexSubImage2D) = null;
    var glCopyTexImage2D: ?FnPtr(function_signatures.glCopyTexImage2D) = null;
    var glCopyTexSubImage2D: ?FnPtr(function_signatures.glCopyTexSubImage2D) = null;
    var glCreateProgram: ?FnPtr(function_signatures.glCreateProgram) = null;
    var glCreateShader: ?FnPtr(function_signatures.glCreateShader) = null;
    var glCullFace: ?FnPtr(function_signatures.glCullFace) = null;
    var glDeleteBuffers: ?FnPtr(function_signatures.glDeleteBuffers) = null;
    var glDeleteFramebuffers: ?FnPtr(function_signatures.glDeleteFramebuffers) = null;
    var glDeleteProgram: ?FnPtr(function_signatures.glDeleteProgram) = null;
    var glDeleteRenderbuffers: ?FnPtr(function_signatures.glDeleteRenderbuffers) = null;
    var glDeleteShader: ?FnPtr(function_signatures.glDeleteShader) = null;
    var glDeleteTextures: ?FnPtr(function_signatures.glDeleteTextures) = null;
    var glDepthFunc: ?FnPtr(function_signatures.glDepthFunc) = null;
    var glDepthMask: ?FnPtr(function_signatures.glDepthMask) = null;
    var glDepthRangef: ?FnPtr(function_signatures.glDepthRangef) = null;
    var glDetachShader: ?FnPtr(function_signatures.glDetachShader) = null;
    var glDisable: ?FnPtr(function_signatures.glDisable) = null;
    var glDisableVertexAttribArray: ?FnPtr(function_signatures.glDisableVertexAttribArray) = null;
    var glDrawArrays: ?FnPtr(function_signatures.glDrawArrays) = null;
    var glDrawElements: ?FnPtr(function_signatures.glDrawElements) = null;
    var glEnable: ?FnPtr(function_signatures.glEnable) = null;
    var glEnableVertexAttribArray: ?FnPtr(function_signatures.glEnableVertexAttribArray) = null;
    var glFinish: ?FnPtr(function_signatures.glFinish) = null;
    var glFlush: ?FnPtr(function_signatures.glFlush) = null;
    var glFramebufferRenderbuffer: ?FnPtr(function_signatures.glFramebufferRenderbuffer) = null;
    var glFramebufferTexture2D: ?FnPtr(function_signatures.glFramebufferTexture2D) = null;
    var glFrontFace: ?FnPtr(function_signatures.glFrontFace) = null;
    var glGenBuffers: ?FnPtr(function_signatures.glGenBuffers) = null;
    var glGenerateMipmap: ?FnPtr(function_signatures.glGenerateMipmap) = null;
    var glGenFramebuffers: ?FnPtr(function_signatures.glGenFramebuffers) = null;
    var glGenRenderbuffers: ?FnPtr(function_signatures.glGenRenderbuffers) = null;
    var glGenTextures: ?FnPtr(function_signatures.glGenTextures) = null;
    var glGetActiveAttrib: ?FnPtr(function_signatures.glGetActiveAttrib) = null;
    var glGetActiveUniform: ?FnPtr(function_signatures.glGetActiveUniform) = null;
    var glGetAttachedShaders: ?FnPtr(function_signatures.glGetAttachedShaders) = null;
    var glGetAttribLocation: ?FnPtr(function_signatures.glGetAttribLocation) = null;
    var glGetBooleanv: ?FnPtr(function_signatures.glGetBooleanv) = null;
    var glGetBufferParameteriv: ?FnPtr(function_signatures.glGetBufferParameteriv) = null;
    var glGetError: ?FnPtr(function_signatures.glGetError) = null;
    var glGetFloatv: ?FnPtr(function_signatures.glGetFloatv) = null;
    var glGetFramebufferAttachmentParameteriv: ?FnPtr(function_signatures.glGetFramebufferAttachmentParameteriv) = null;
    var glGetIntegerv: ?FnPtr(function_signatures.glGetIntegerv) = null;
    var glGetProgramiv: ?FnPtr(function_signatures.glGetProgramiv) = null;
    var glGetProgramInfoLog: ?FnPtr(function_signatures.glGetProgramInfoLog) = null;
    var glGetRenderbufferParameteriv: ?FnPtr(function_signatures.glGetRenderbufferParameteriv) = null;
    var glGetShaderiv: ?FnPtr(function_signatures.glGetShaderiv) = null;
    var glGetShaderInfoLog: ?FnPtr(function_signatures.glGetShaderInfoLog) = null;
    var glGetShaderPrecisionFormat: ?FnPtr(function_signatures.glGetShaderPrecisionFormat) = null;
    var glGetShaderSource: ?FnPtr(function_signatures.glGetShaderSource) = null;
    var glGetString: ?FnPtr(function_signatures.glGetString) = null;
    var glGetTexParameterfv: ?FnPtr(function_signatures.glGetTexParameterfv) = null;
    var glGetTexParameteriv: ?FnPtr(function_signatures.glGetTexParameteriv) = null;
    var glGetUniformfv: ?FnPtr(function_signatures.glGetUniformfv) = null;
    var glGetUniformiv: ?FnPtr(function_signatures.glGetUniformiv) = null;
    var glGetUniformLocation: ?FnPtr(function_signatures.glGetUniformLocation) = null;
    var glGetVertexAttribfv: ?FnPtr(function_signatures.glGetVertexAttribfv) = null;
    var glGetVertexAttribiv: ?FnPtr(function_signatures.glGetVertexAttribiv) = null;
    var glGetVertexAttribPointerv: ?FnPtr(function_signatures.glGetVertexAttribPointerv) = null;
    var glHint: ?FnPtr(function_signatures.glHint) = null;
    var glIsBuffer: ?FnPtr(function_signatures.glIsBuffer) = null;
    var glIsEnabled: ?FnPtr(function_signatures.glIsEnabled) = null;
    var glIsFramebuffer: ?FnPtr(function_signatures.glIsFramebuffer) = null;
    var glIsProgram: ?FnPtr(function_signatures.glIsProgram) = null;
    var glIsRenderbuffer: ?FnPtr(function_signatures.glIsRenderbuffer) = null;
    var glIsShader: ?FnPtr(function_signatures.glIsShader) = null;
    var glIsTexture: ?FnPtr(function_signatures.glIsTexture) = null;
    var glLineWidth: ?FnPtr(function_signatures.glLineWidth) = null;
    var glLinkProgram: ?FnPtr(function_signatures.glLinkProgram) = null;
    var glPixelStorei: ?FnPtr(function_signatures.glPixelStorei) = null;
    var glPolygonOffset: ?FnPtr(function_signatures.glPolygonOffset) = null;
    var glReadPixels: ?FnPtr(function_signatures.glReadPixels) = null;
    var glReleaseShaderCompiler: ?FnPtr(function_signatures.glReleaseShaderCompiler) = null;
    var glRenderbufferStorage: ?FnPtr(function_signatures.glRenderbufferStorage) = null;
    var glSampleCoverage: ?FnPtr(function_signatures.glSampleCoverage) = null;
    var glScissor: ?FnPtr(function_signatures.glScissor) = null;
    var glShaderBinary: ?FnPtr(function_signatures.glShaderBinary) = null;
    var glShaderSource: ?FnPtr(function_signatures.glShaderSource) = null;
    var glStencilFunc: ?FnPtr(function_signatures.glStencilFunc) = null;
    var glStencilFuncSeparate: ?FnPtr(function_signatures.glStencilFuncSeparate) = null;
    var glStencilMask: ?FnPtr(function_signatures.glStencilMask) = null;
    var glStencilMaskSeparate: ?FnPtr(function_signatures.glStencilMaskSeparate) = null;
    var glStencilOp: ?FnPtr(function_signatures.glStencilOp) = null;
    var glStencilOpSeparate: ?FnPtr(function_signatures.glStencilOpSeparate) = null;
    var glTexImage2D: ?FnPtr(function_signatures.glTexImage2D) = null;
    var glTexParameterf: ?FnPtr(function_signatures.glTexParameterf) = null;
    var glTexParameterfv: ?FnPtr(function_signatures.glTexParameterfv) = null;
    var glTexParameteri: ?FnPtr(function_signatures.glTexParameteri) = null;
    var glTexParameteriv: ?FnPtr(function_signatures.glTexParameteriv) = null;
    var glTexSubImage2D: ?FnPtr(function_signatures.glTexSubImage2D) = null;
    var glUniform1f: ?FnPtr(function_signatures.glUniform1f) = null;
    var glUniform1fv: ?FnPtr(function_signatures.glUniform1fv) = null;
    var glUniform1i: ?FnPtr(function_signatures.glUniform1i) = null;
    var glUniform1iv: ?FnPtr(function_signatures.glUniform1iv) = null;
    var glUniform2f: ?FnPtr(function_signatures.glUniform2f) = null;
    var glUniform2fv: ?FnPtr(function_signatures.glUniform2fv) = null;
    var glUniform2i: ?FnPtr(function_signatures.glUniform2i) = null;
    var glUniform2iv: ?FnPtr(function_signatures.glUniform2iv) = null;
    var glUniform3f: ?FnPtr(function_signatures.glUniform3f) = null;
    var glUniform3fv: ?FnPtr(function_signatures.glUniform3fv) = null;
    var glUniform3i: ?FnPtr(function_signatures.glUniform3i) = null;
    var glUniform3iv: ?FnPtr(function_signatures.glUniform3iv) = null;
    var glUniform4f: ?FnPtr(function_signatures.glUniform4f) = null;
    var glUniform4fv: ?FnPtr(function_signatures.glUniform4fv) = null;
    var glUniform4i: ?FnPtr(function_signatures.glUniform4i) = null;
    var glUniform4iv: ?FnPtr(function_signatures.glUniform4iv) = null;
    var glUniformMatrix2fv: ?FnPtr(function_signatures.glUniformMatrix2fv) = null;
    var glUniformMatrix3fv: ?FnPtr(function_signatures.glUniformMatrix3fv) = null;
    var glUniformMatrix4fv: ?FnPtr(function_signatures.glUniformMatrix4fv) = null;
    var glUseProgram: ?FnPtr(function_signatures.glUseProgram) = null;
    var glValidateProgram: ?FnPtr(function_signatures.glValidateProgram) = null;
    var glVertexAttrib1f: ?FnPtr(function_signatures.glVertexAttrib1f) = null;
    var glVertexAttrib1fv: ?FnPtr(function_signatures.glVertexAttrib1fv) = null;
    var glVertexAttrib2f: ?FnPtr(function_signatures.glVertexAttrib2f) = null;
    var glVertexAttrib2fv: ?FnPtr(function_signatures.glVertexAttrib2fv) = null;
    var glVertexAttrib3f: ?FnPtr(function_signatures.glVertexAttrib3f) = null;
    var glVertexAttrib3fv: ?FnPtr(function_signatures.glVertexAttrib3fv) = null;
    var glVertexAttrib4f: ?FnPtr(function_signatures.glVertexAttrib4f) = null;
    var glVertexAttrib4fv: ?FnPtr(function_signatures.glVertexAttrib4fv) = null;
    var glVertexAttribPointer: ?FnPtr(function_signatures.glVertexAttribPointer) = null;
    var glViewport: ?FnPtr(function_signatures.glViewport) = null;
    var glDebugMessageControlKHR: ?FnPtr(function_signatures.glDebugMessageControlKHR) = null;
    var glDebugMessageInsertKHR: ?FnPtr(function_signatures.glDebugMessageInsertKHR) = null;
    var glDebugMessageCallbackKHR: ?FnPtr(function_signatures.glDebugMessageCallbackKHR) = null;
    var glGetDebugMessageLogKHR: ?FnPtr(function_signatures.glGetDebugMessageLogKHR) = null;
    var glPushDebugGroupKHR: ?FnPtr(function_signatures.glPushDebugGroupKHR) = null;
    var glPopDebugGroupKHR: ?FnPtr(function_signatures.glPopDebugGroupKHR) = null;
    var glObjectLabelKHR: ?FnPtr(function_signatures.glObjectLabelKHR) = null;
    var glGetObjectLabelKHR: ?FnPtr(function_signatures.glGetObjectLabelKHR) = null;
    var glObjectPtrLabelKHR: ?FnPtr(function_signatures.glObjectPtrLabelKHR) = null;
    var glGetObjectPtrLabelKHR: ?FnPtr(function_signatures.glGetObjectPtrLabelKHR) = null;
    var glGetPointervKHR: ?FnPtr(function_signatures.glGetPointervKHR) = null;
};

test {
    _ = load;
    @setEvalBranchQuota(100_000); // Yes, this is necessary. OpenGL gets quite large!
    std.testing.refAllDecls(@This());
}
