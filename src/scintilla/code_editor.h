#pragma once

#ifndef CODE_EDITOR
#define CODE_EDITOR

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Keep in sync with CodeEditor.zig

typedef struct ZigEditorInterface ZigEditorInterface;
typedef struct ZigFont ZigFont;
typedef struct ScintillaEditor ScintillaEditor;
typedef struct ZigRect ZigRect;
typedef struct ZigString ZigString;

enum LogLevel {
  LOG_DEBUG,
  LOG_INFO,
  LOG_WARN,
  LOG_ERROR,
};
typedef enum LogLevel LogLevel;

// 0xAABBGGRR
typedef uint32_t ZigColor;

struct ZigRect {
  float x, y;
  float width, height;
};

struct ZigString {
  char *ptr;
  size_t len;
};

struct ZigEditorInterface {
  ZigFont *(*createFont)(ZigEditorInterface *app, char const *font_name, float size);
  void (*destroyFont)(ZigEditorInterface *app, ZigFont *font);

  float (*getFontAscent)(ZigEditorInterface *app, ZigFont *font);
  float (*getFontDescent)(ZigEditorInterface *app, ZigFont *font);
  float (*getFontLineGap)(ZigEditorInterface *app, ZigFont *font);
  float (*getFontCharWidth)(ZigEditorInterface *app, ZigFont *font, uint32_t c);

  // render commands
  float (*measureStringWidth)(ZigEditorInterface *app, ZigFont *font, char const *str, size_t length);
  void (*measureCharPositions)(ZigEditorInterface *app, ZigFont *font, char const *str, size_t length, float *positions);
  void (*drawString)(ZigEditorInterface *app, ZigRect const *rectangle, ZigFont *font, ZigColor color, char const *str, size_t length);
  void (*drawRectangle)(ZigEditorInterface *app, ZigRect const *rectangle, ZigColor color);
  void (*fillRectangle)(ZigEditorInterface *app, ZigRect const *rectangle, ZigColor color);
  void (*setClipRect)(ZigEditorInterface *app, ZigRect const *rectangle);

  void (*setClipboardContent)(ZigEditorInterface *app, char const *str, size_t length);
  size_t (*getClipboardContent)(ZigEditorInterface *app, char *str, size_t max_length);
};

void scintilla_init();
void scintilla_deinit();

ScintillaEditor *scintilla_create(ZigEditorInterface *);
void scintilla_setText(ScintillaEditor *editor, char const *string, size_t length);
ZigString scintilla_getText(ScintillaEditor *editor, void *allocator);
void scintilla_tick(ScintillaEditor *editor);
void scintilla_render(ScintillaEditor *editor);

void scintilla_mouseMove(ScintillaEditor *editor, int x, int y);
void scintilla_mouseDown(ScintillaEditor *editor, float time, int x, int y);
void scintilla_mouseUp(ScintillaEditor *editor, float time, int x, int y);
bool scintilla_keyDown(ScintillaEditor *editor, int zig_scancode, bool shift, bool ctrl, bool alt);
void scintilla_enterString(ScintillaEditor *editor, char const *str, size_t len);

void scintilla_setPosition(ScintillaEditor *editor, int x, int y, int w, int h);

void scintilla_destroy(ScintillaEditor *editor);

#ifdef __cplusplus
}
#endif

#endif // CODE_EDITOR
