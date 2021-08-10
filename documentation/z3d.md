# Z3D Model Format

Everything is encoded little-endian

```zig

// size: variable
const File = struct {
  header: Header,
  vertices: [header.vertex_count]Vertex,
  indices: [header.index_count]Index,
  meshes: [header.mesh_count]Mesh,
};

// size: 24
const Header = struct {
  magic: [4]u8 = .{ 0xae, 0x32, 0x51, 0x1d },
  
  version: u16 = 1,
  type: enum(u8) { static = 0, dynamic = 1 },
  _: u8 = undefined,

  vertex_count: u32,
  index_count: u32,
  mesh_count: u32,
  _: u32 = undefined,
};

// size: 32
const Vertex = struct {
  x: f32,
  y: f32,
  z: f32,
  nx: f32,
  ny: f32,
  nz: f32,
  u: f32,
  v: f32,
};

// size: 2
const Index = u16;

// size: 128
const Mesh = struct {
  offset: u32,
  length: u32,
  texture_file: [120]u8, // NUL padded
};
```