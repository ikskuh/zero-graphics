#pragma once

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

struct MeshStream {
  void (*writeStaticHeader)(struct MeshStream *, size_t vertices, size_t indices, size_t ranges);
  void (*writeVertex)(struct MeshStream *, float x, float y, float z, float nx, float ny, float nz, float u, float v);
  void (*writeFace)(struct MeshStream *, uint16_t i0, uint16_t i1, uint16_t i2);
  void (*writeMeshRange)(struct MeshStream *, size_t offset, size_t count, char const *texture);
};

enum FileType {
  dynamic_geometry = 0,
  static_geometry = 1,
};

bool transformFile(char const *src_file_name, struct MeshStream *stream, enum FileType create_static_model);

#ifdef __cplusplus
}
#endif