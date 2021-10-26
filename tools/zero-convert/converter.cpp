#include <assimp/Importer.hpp> // C++ importer interface
#include <assimp/material.h>
#include <assimp/mesh.h>
#include <assimp/postprocess.h> // Post processing flags
#include <assimp/scene.h>       // Output data structure

#include <assimp/types.h>
#include <assimp/vector3.h>
#include <stdlib.h>

#include "api.h"

#include <string.h>

extern "C" void printErrorMessage(char const *text, size_t length);
extern "C" void printInfoMessage(char const *text, size_t length);
extern "C" void printWarningMessage(char const *text, size_t length);

void printErrorMessage(char const *error_string) {
  printErrorMessage(error_string, strlen(error_string));
}
void printInfoMessage(char const *error_string) {
  printInfoMessage(error_string, strlen(error_string));
}
void printWarningMessage(char const *error_string) {
  printWarningMessage(error_string, strlen(error_string));
}

static bool createStaticModel(aiScene const *scene, MeshStream *stream) {

  char buffer[256];
  sprintf(buffer, "converting %u meshes", scene->mNumMeshes);

  size_t total_vertex_count = 0;
  size_t total_index_count = 0;

  for (size_t i = 0; i < scene->mNumMeshes; i++) {
    aiMesh const *mesh = scene->mMeshes[i];
    total_vertex_count += mesh->mNumVertices;
    total_index_count += 3 * mesh->mNumFaces;
  }

  if (total_vertex_count >= (1 << 16)) {
    printErrorMessage("Model has too many vertices. Only up to 65536 are supported!");
    return false;
  }

  stream->writeStaticHeader(stream, total_vertex_count, total_index_count, scene->mNumMeshes);

  for (size_t i = 0; i < scene->mNumMeshes; i++) {
    aiMesh const *mesh = scene->mMeshes[i];

    for (size_t vi = 0; vi < mesh->mNumVertices; vi++) {
      aiVector3D uv(0, 0, 0);
      if (mesh->HasTextureCoords(0)) {
        uv = mesh->mTextureCoords[0][vi];
      }
      aiVector3D normal(0, 0, 0);
      if (mesh->HasNormals()) {
        normal = mesh->mNormals[vi];
      }
      aiVector3D pos = mesh->mVertices[vi];

      stream->writeVertex(stream,
                          pos.x, pos.y, pos.z,
                          normal.x, normal.y, normal.z,
                          uv.x, uv.y);
    }
  }

  size_t index_offset = 0;
  for (size_t i = 0; i < scene->mNumMeshes; i++) {
    aiMesh const *mesh = scene->mMeshes[i];

    for (size_t fi = 0; fi < mesh->mNumFaces; fi++) {
      aiFace face = mesh->mFaces[fi];
      if (face.mNumIndices != 3) {
        printErrorMessage("Triangulation of the model failed. Found at least one non-triangle face!");
        return false;
      }
      stream->writeFace(stream, index_offset + face.mIndices[0], index_offset + face.mIndices[1], index_offset + face.mIndices[2]);
    }
    index_offset += mesh->mNumVertices;
  }

  auto texture_warning = false;

  index_offset = 0;
  for (size_t i = 0; i < scene->mNumMeshes; i++) {
    aiMesh const *mesh = scene->mMeshes[i];
    aiMaterial const *mtl = scene->mMaterials[mesh->mMaterialIndex];

    aiString name = mtl->GetName();

    aiString path;
    bool has_texture = false;
    if (mtl->GetTexture(aiTextureType_DIFFUSE, 0, &path) == aiReturn_SUCCESS) {
      has_texture = true;
    } else {
      if (!texture_warning) {
        printErrorMessage("At least once mesh doesn't have a texture assigned!");
        texture_warning = true;
      }
    }

    // char msgBuf[64];
    // sprintf(msgBuf, "texture: %s, %s", name.C_Str(), path.C_Str());
    // printWarningMessage(msgBuf);

    stream->writeMeshRange(stream,
                           index_offset,
                           3 * mesh->mNumFaces,
                           has_texture ? path.C_Str() : nullptr);

    index_offset += 3 * mesh->mNumFaces;
  }

  return true;
}

static bool createDynamicModel(aiScene const *scene, MeshStream *stream) {
  printErrorMessage("dynamic models are not supported yet!");
  return false;
}

extern "C" bool transformFile(char const *src_file_name, MeshStream *stream, FileType create_static_model) {

  // Create an instance of the Importer class
  Assimp::Importer importer;

  auto import_flags = aiProcess_CalcTangentSpace |
                      aiProcess_Triangulate |
                      aiProcess_JoinIdenticalVertices |
                      aiProcess_RemoveRedundantMaterials |
                      aiProcess_OptimizeMeshes |
                      aiProcess_SortByPType;
  if (create_static_model) {
    import_flags |= aiProcess_PreTransformVertices;
  } else {
    import_flags |= aiProcess_OptimizeGraph;
  }

  // And have it read the given file with some example postprocessing
  // Usually - if speed is not the most important aspect for you - you'll
  // probably to request more postprocessing than we do in this example.
  const aiScene *scene = importer.ReadFile(src_file_name, import_flags);

  // If the import failed, report it
  if (scene == nullptr) {
    printErrorMessage(importer.GetErrorString());
    return false;
  }

  if (not scene->HasMeshes()) {
    printErrorMessage("Model does not contain any meshes!");
    return false;
  }

  if (create_static_model) {
    return createStaticModel(scene, stream);
  } else {
    return createDynamicModel(scene, stream);
  }
}