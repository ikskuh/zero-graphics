import bpy


def write_some_data(context, filepath, use_some_setting):
    print("running write_some_data...")
    print(context, context.scene, context.scene.objects, context.selected_objects)
    f = open(filepath, 'w', encoding='utf-8')
    if use_some_setting:
        f.write("Hello with bones")
    else:
        f.write("Hello without bones")
    f.close()

    return {'FINISHED'}


# ExportHelper is a helper class, defines filename and
# invoke() function which calls the file selector.
from bpy_extras.io_utils import ExportHelper
from bpy.props import StringProperty, BoolProperty, EnumProperty
from bpy.types import Operator


class ExportZeroGraphicsModel(Operator, ExportHelper):
    """Exports a 3D model for the use with zero-graphics."""
    bl_idname = "export_zero_graphics_3d.model"  # important since its how bpy.ops.import_test.some_data is constructed
    bl_label = "Export model"

    # ExportHelper mixin class uses this
    filename_ext = ".z3d"

    filter_glob: StringProperty(
        default="*.z3d",
        options={'HIDDEN'},
        maxlen=255,  # Max internal buffer length, longer would be clamped.
    )

    # List of operator properties, the attributes will be assigned
    # to the class instance from the operator settings before calling.
    include_bones: BoolProperty(
        name="Include Bones",
        description="If this is checked, the model will be a dynamic model with skinned vertices and a bone structure.",
        default=False,
    )

    def execute(self, context):
        return write_some_data(context, self.filepath, self.include_bones)


# Only needed if you want to add into a dynamic menu
def menu_func_export(self, context):
    self.layout.operator(ExportZeroGraphicsModel.bl_idname, text="Export zero-graphics model")


def register():
    bpy.utils.register_class(ExportZeroGraphicsModel)
    bpy.types.TOPBAR_MT_file_export.append(menu_func_export)


def unregister():
    bpy.utils.unregister_class(ExportZeroGraphicsModel)
    bpy.types.TOPBAR_MT_file_export.remove(menu_func_export)


if __name__ == "__main__":
    register()

    # test call
    bpy.ops.export_zero_graphics_3d.model('INVOKE_DEFAULT')
