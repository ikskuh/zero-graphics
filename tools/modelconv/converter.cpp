#include <assimp/Importer.hpp>  // C++ importer interface
#include <assimp/postprocess.h> // Post processing flags
#include <assimp/scene.h>       // Output data structure

#include <stdlib.h>

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

static bool createStaticModel(aiScene const *scene, char const *dst_file_name) {

  char buffer[256];
  sprintf(buffer, "converting %u meshes", scene->mNumMeshes);

  printInfoMessage(buffer);

  return true;
}

static bool createDynamicModel(aiScene const *scene,
                               char const *dst_file_name) {
  printErrorMessage("dynamic models are not supported yet!");
  return false;
}

enum FileType {
  dynamic = 0,
  _static = 1,
};

extern "C" bool transformFile(char const *src_file_name,
                              char const *dst_file_name,
                              FileType create_static_model) {

  // Create an instance of the Importer class
  Assimp::Importer importer;

  auto import_flags = aiProcess_CalcTangentSpace | aiProcess_Triangulate |
                      aiProcess_JoinIdenticalVertices |
                      aiProcess_RemoveRedundantMaterials |
                      aiProcess_OptimizeGraph | aiProcess_OptimizeMeshes |
                      aiProcess_SortByPType;
  if (create_static_model) {
    import_flags |= aiProcess_PreTransformVertices;
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
    return createStaticModel(scene, dst_file_name);
  } else {
    return createDynamicModel(scene, dst_file_name);
  }
}