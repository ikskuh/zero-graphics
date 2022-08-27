// Some of this code was originally written for the ScintillaGL project by:
// Copyright 2011 by Mykhailo Parfeniuk

#include <cstdarg>
#include <cstddef>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <math.h>

#include <vector>
#include <cmath>
#include <map>
#include <array>
#include <string>

#include <Platform.h>
#include <Scintilla.h>
#include <UniConversion.h>
#include <XPM.h>

#include <ILexer.h>

// #ifdef SCI_LEXER
#include <SciLexer.h>
// #endif
#include <StringCopy.h>
#ifdef SCI_LEXER
#include <LexerModule.h>
#endif
#include <SplitVector.h>
#include <Partitioning.h>
#include <RunStyles.h>
#include <ContractionState.h>
#include <CellBuffer.h>
#include <CallTip.h>
#include <KeyMap.h>
#include <Indicator.h>
#include <XPM.h>
#include <LineMarker.h>
#include <Style.h>
#include <ViewStyle.h>
#include <CharClassify.h>
#include <Decoration.h>
#include <CaseFolder.h>
#include <Document.h>
#include <CaseConvert.h>
#include <UniConversion.h>
#include <Selection.h>
#include <PositionCache.h>
#include <EditModel.h>
#include <MarginView.h>
#include <EditView.h>
#include <Editor.h>
#include <AutoComplete.h>
#include <ScintillaBase.h>

#include "PropSetSimple.h"

// include our application header at last

#include "code_editor.h"
#include "../c_interface.h"

#define UNUSED(_Value) (void)(_Value)

#define ZIG_ASSERT(_Assertion) \
  zig_assert_impl(_Assertion, #_Assertion, __FILE__, __LINE__)

static void zig_assert_impl(int asserted, char const *assertion_text, char const *file, int line) {
  if (asserted)
    return;
  std::array<char, 1024> msg;
  snprintf(msg.data(), msg.size(), "%s:%d: Assertion failed: %s\n", file, line, assertion_text);
  zerog_panic(msg.data());
}

static void log_some(LogLevel level, char const *fmt, va_list list) {
  va_list first_list;
  va_copy(first_list, list);

  int length = vsnprintf(nullptr, 0, fmt, first_list);
  va_end(first_list);

  std::vector<char> str_buf;
  str_buf.resize(length + 1);

  int again = vsnprintf(str_buf.data(), str_buf.size(), fmt, list);
  ZIG_ASSERT(again == length);
  str_buf[length] = 0;

  zero_graphics_writeLog(level, str_buf.data(), size_t(length));
}

static void log_error(char const *fmt, ...) {
  va_list list;
  va_start(list, fmt);
  log_some(LOG_ERROR, fmt, list);
  va_end(list);
}

static void log_warn(char const *fmt, ...) {
  va_list list;
  va_start(list, fmt);
  log_some(LOG_WARN, fmt, list);
  va_end(list);
}

static void log_info(char const *fmt, ...) {
  va_list list;
  va_start(list, fmt);
  log_some(LOG_INFO, fmt, list);
  va_end(list);
}

static void log_debug(char const *fmt, ...) {
  va_list list;
  va_start(list, fmt);
  log_some(LOG_DEBUG, fmt, list);
  va_end(list);
}

#ifdef SCI_NAMESPACE
using namespace Scintilla;
#endif

template <typename T, typename Tag>
struct PseudoGlobal {
  static thread_local bool has_value;
  static thread_local T value;

  PseudoGlobal(T value) {
    ZIG_ASSERT(!has_value);
    PseudoGlobal::value = value;
    has_value = true;
  }
  ~PseudoGlobal() {
    has_value = false;
  }

  static T get() {
    ZIG_ASSERT(has_value);
    return value;
  }
};

template <typename T, typename Tag>
thread_local T PseudoGlobal<T, Tag>::value;

template <typename T, typename Tag>
thread_local bool PseudoGlobal<T, Tag>::has_value = false;

struct EditorInterfaceHack {};

ZigEditorInterface *current_app() {
  return PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack>::get();
}

ZigRect cpp2zig(PRectangle val) {
  // HACK: Fix the wrong coordinate transform here
  return ZigRect{
      val.left,
      val.top,
      val.Width(),
      val.Height(),
  };
}

ZigColor cpp2zig(ColourDesired val) {
  return static_cast<ZigColor>(val.AsLong());
}

//////////////////////////////////////////////////////////////////////////

// this is only used if we support loading external lexers, which we don't
DynamicLibrary *DynamicLibrary::Load(const char *modulePath) {
  UNUSED(modulePath);
  return nullptr;
}

//////////////////////////////////////////////////////////////////////////

ColourDesired MakeRGBA(unsigned char r, unsigned char g, unsigned char b, unsigned char a = 0xFF) {
  return a << 24 | b << 16 | g << 8 | r;
}

ColourDesired Platform::Chrome() {
  return MakeRGBA(0xe0, 0xe0, 0xe0);
}

ColourDesired Platform::ChromeHighlight() {
  return MakeRGBA(0xff, 0xff, 0xff);
}

const char *Platform::DefaultFont() {
  return "SourceCodePro";
}

int Platform::DefaultFontSize() {
  return 10;
}

unsigned int Platform::DoubleClickTime() {
  return 500; // Half a second
}

bool Platform::MouseButtonBounce() {
  return true;
}

void Platform::Assert(const char *c, const char *file, int line) {
  zig_assert_impl(0, c, file, line);
}

int Platform::Minimum(int a, int b) { return a < b ? a : b; }
int Platform::Maximum(int a, int b) { return a > b ? a : b; }
int Platform::Clamp(int val, int minVal, int maxVal) { return Minimum(maxVal, Maximum(val, minVal)); }

#ifdef TRACE
void Platform::DebugPrintf(const char *format, ...) {
  char buffer[2000];
  va_list pArguments;
  va_start(pArguments, format);
  vsprintf(buffer, format, pArguments);
  va_end(pArguments);
  Platform::DebugDisplay(buffer);
}
#else
void Platform::DebugPrintf(const char *, ...) {
}
#endif

//////////////////////////////////////////////////////////////////////////
// FONT

Font::Font() : fid(0) {
}

Font::~Font() {
}

void Font::Create(const FontParameters &fp) {
  log_debug("Font::Create(%s, %.3f, %d, %d)", fp.faceName, fp.size, fp.italic, fp.weight);
  // TODO: Implement font weight
  this->fid = current_app()->createFont(current_app(), fp.faceName, fp.size);
}

void Font::Release() {
  if (this->fid != nullptr) {
    current_app()->destroyFont(current_app(), static_cast<ZigFont *>(this->fid));
  }
}

//////////////////////////////////////////////////////////////////////////
// SURFACE

#ifdef SCI_NAMESPACE
namespace Scintilla {
#endif
struct SurfaceImpl : public Surface {
  ColourDesired penColour;
  float currentX;
  float currentY;
  bool unicodeMode;
  int codePage;
  bool initialised;
  PRectangle clipRect;

public:
  SurfaceImpl();
  virtual ~SurfaceImpl();

  void Init(WindowID wid);
  void Init(SurfaceID sid, WindowID wid);
  void InitPixMap(int width, int height, Surface *surface, WindowID wid);

  void Release();
  bool Initialised();
  void PenColour(ColourDesired fore);
  int LogPixelsY();
  int DeviceHeightFont(int points);
  void MoveTo(float x, float y);
  void LineTo(float x, float y);
  void Polygon(Point *pts, int npts, ColourDesired fore, ColourDesired back);
  void RectangleDraw(PRectangle rc, ColourDesired fore, ColourDesired back);
  void FillRectangle(PRectangle rc, ColourDesired back);
  void FillRectangle(PRectangle rc, Surface &surfacePattern);
  void RoundedRectangle(PRectangle rc, ColourDesired fore, ColourDesired back);
  void AlphaRectangle(PRectangle rc, int cornerSize, ColourDesired fill, int alphaFill,
                      ColourDesired outline, int alphaOutline, int flags);
  void Ellipse(PRectangle rc, ColourDesired fore, ColourDesired back);
  void Copy(PRectangle rc, Point from, Surface &surfaceSource);

  //virtual void DrawPixmap(PRectangle rc, Point from, Pixmap pixmap);
  virtual void DrawRGBAImage(PRectangle rc, int width, int height, const unsigned char *pixelsImage);

  void DrawTextBase(PRectangle rc, Font &font, float ybase, const char *s, int len, ColourDesired fore);
  void DrawTextNoClip(PRectangle rc, Font &font, float ybase, const char *s, int len, ColourDesired fore, ColourDesired back);
  void DrawTextClipped(PRectangle rc, Font &font, float ybase, const char *s, int len, ColourDesired fore, ColourDesired back);
  void DrawTextTransparent(PRectangle rc, Font &font, float ybase, const char *s, int len, ColourDesired fore);
  void MeasureWidths(Font &font, const char *s, int len, float *positions);
  float WidthText(Font &font, const char *s, int len);
  float WidthChar(Font &font, char ch);
  float Ascent(Font &font);
  float Descent(Font &font);
  float InternalLeading(Font &font);
  float ExternalLeading(Font &font);
  float Height(Font &font);
  float AverageCharWidth(Font &font);

  void MoveTo(int x, int y);
  void LineTo(int x, int y);

  void SetClip(PRectangle rc);
  void FlushCachedState();

  void SetUnicodeMode(bool unicodeMode_);
  void SetDBCSMode(int codePage);
};

#ifdef SCI_NAMESPACE
}
#endif

SurfaceImpl::SurfaceImpl()
    : currentX(0), currentY(0) {
  this->unicodeMode = false;
  this->codePage = 0;
  this->initialised = false;
}

SurfaceImpl::~SurfaceImpl() {
}

void SurfaceImpl::Init(WindowID wid) {
  UNUSED(wid);
  this->initialised = true;
}

void SurfaceImpl::Init(SurfaceID sid, WindowID wid) {
  UNUSED(sid);
  UNUSED(wid);
  this->initialised = true;
}

void SurfaceImpl::InitPixMap(int width, int height, Surface *surface, WindowID wid) {
  UNUSED(width);
  UNUSED(height);
  UNUSED(surface);
  UNUSED(wid);
  this->initialised = true;
}

void SurfaceImpl::Release() {
}

bool SurfaceImpl::Initialised() {
  return this->initialised;
}

void SurfaceImpl::PenColour(ColourDesired fore) {
  this->penColour = fore;
}

int SurfaceImpl::LogPixelsY() {
  return zero_graphics_getDisplayDpi();
}

int SurfaceImpl::DeviceHeightFont(int points) {
  int logPix = this->LogPixelsY();

  auto const font_height = (points * logPix + logPix / 2) / 72;
  log_debug("DeviceHeightFont(%d) => %d", points, font_height);
  return font_height;
}

void SurfaceImpl::MoveTo(float x, float y) {
  this->currentX = x;
  this->currentY = y;
}

void SurfaceImpl::LineTo(float targetX, float targetY) {
  ZIG_ASSERT(!"SurfaceImpl::LineTo");
  // Renderer::RenderLine(
  //   Renderer::Vertex( currentX+0.5f, currentY+0.5f, (unsigned int)penColour.AsLong() ),
  //   Renderer::Vertex(  targetX+0.5f,  targetY+0.5f, (unsigned int)penColour.AsLong() )
  // );
  this->currentX = targetX;
  this->currentY = targetY;
}

void SurfaceImpl::MoveTo(int x, int y) {
  this->MoveTo((float)x, (float)y);
}

void SurfaceImpl::LineTo(int x, int y) {
  this->LineTo((float)x, (float)y);
}

void SurfaceImpl::Polygon(Point * /*pts*/, int /*npts*/, ColourDesired /*fore*/, ColourDesired /*back*/) {
  ZIG_ASSERT(!"SurfaceImpl::Polygon");
}

void SurfaceImpl::RectangleDraw(PRectangle rc, ColourDesired fore, ColourDesired back) {
  auto const temp_rect1 = cpp2zig(rc);
  current_app()->fillRectangle(current_app(), &temp_rect1, cpp2zig(back));
  auto const temp_rect2 = cpp2zig(rc);
  current_app()->drawRectangle(current_app(), &temp_rect2, cpp2zig(fore));
}

void SurfaceImpl::FillRectangle(PRectangle rc, ColourDesired back) {
  auto const temp_rect = cpp2zig(rc);
  current_app()->fillRectangle(current_app(), &temp_rect, cpp2zig(back));
}

void SurfaceImpl::FillRectangle(PRectangle rc, Surface &surfacePattern) {
  this->FillRectangle(rc, 0xd0000000);
}

void SurfaceImpl::RoundedRectangle(PRectangle rc, ColourDesired fore, ColourDesired back) {
  this->RectangleDraw(rc, fore, back);
}

void SurfaceImpl::AlphaRectangle(PRectangle rc, int /*cornerSize*/, ColourDesired fill, int alphaFill,
                                 ColourDesired /*outline*/, int /*alphaOutline*/, int /*flags*/) {
  unsigned int back = (fill.AsLong() & 0xFFFFFF) | ((alphaFill & 0xFF) << 24);
  this->FillRectangle(rc, back);
}

void SurfaceImpl::DrawRGBAImage(PRectangle rc, int width, int height, const unsigned char *pixelsImage) {
  ZIG_ASSERT(!"SurfaceImpl::DrawRGBAImage");
}

void SurfaceImpl::Ellipse(PRectangle /*rc*/, ColourDesired /*fore*/, ColourDesired /*back*/) {
  ZIG_ASSERT(!"SurfaceImpl::Ellipse");
}

void SurfaceImpl::Copy(PRectangle rc, Point from, Surface &surfaceSource) {
  UNUSED(rc);
  UNUSED(rc);
  UNUSED(surfaceSource);
  // we don't assert here because this is often used
  // however, we don't support it right now
}

void SurfaceImpl::DrawTextBase(PRectangle rc, Font &font, float ybase, const char *str, int len, ColourDesired fore) {
  auto const temp_rect = cpp2zig(rc);
  current_app()->drawString(
      current_app(),
      &temp_rect,
      static_cast<ZigFont *>(font.GetID()),
      cpp2zig(fore),
      str,
      size_t(len));
}

void SurfaceImpl::DrawTextNoClip(PRectangle rc, Font &font, float ybase, const char *s, int len,
                                 ColourDesired fore, ColourDesired /*back*/) {
  // log_debug("DrawTextNoClip(%.*s)", len, s);
  this->DrawTextBase(rc, font, ybase, s, len, fore);
}

void SurfaceImpl::DrawTextClipped(PRectangle rc, Font &font, float ybase, const char *s, int len,
                                  ColourDesired fore, ColourDesired /*back*/) {
  // log_debug("DrawTextClipped(%.*s)", len, s);
  this->DrawTextBase(rc, font, ybase, s, len, fore);
}

void SurfaceImpl::DrawTextTransparent(PRectangle rc, Font &font, float ybase, const char *s, int len,
                                      ColourDesired fore) {
  // log_debug("DrawTextTransparent(%.*s)", len, s);
  this->DrawTextBase(rc, font, ybase, s, len, fore);
}

void SurfaceImpl::MeasureWidths(Font &font, const char *str, int len, float *positions) {
  current_app()->measureCharPositions(current_app(), static_cast<ZigFont *>(font.GetID()), str, size_t(len), positions);
}

float SurfaceImpl::WidthText(Font &font, const char *str, int len) {
  return current_app()->measureStringWidth(current_app(), static_cast<ZigFont *>(font.GetID()), str, size_t(len));
}

float SurfaceImpl::WidthChar(Font &font, char ch) {
  return current_app()->getFontCharWidth(current_app(), static_cast<ZigFont *>(font.GetID()), ch);
}

float SurfaceImpl::Ascent(Font &font) {
  return current_app()->getFontAscent(current_app(), static_cast<ZigFont *>(font.GetID()));
}

float SurfaceImpl::Descent(Font &font) {
  return current_app()->getFontDescent(current_app(), static_cast<ZigFont *>(font.GetID()));
}

float SurfaceImpl::InternalLeading(Font &) {
  //WTF is this?????
  return 0;
}

float SurfaceImpl::ExternalLeading(Font &font) {
  return current_app()->getFontLineGap(current_app(), static_cast<ZigFont *>(font.GetID()));
}

float SurfaceImpl::Height(Font &font) {
  return Ascent(font) + Descent(font);
}

float SurfaceImpl::AverageCharWidth(Font &font) {
  return this->WidthChar(font, 'n');
}

void SurfaceImpl::SetClip(PRectangle rc) {
  // we deal with this in the renderer
}

void SurfaceImpl::FlushCachedState() {
}

void SurfaceImpl::SetUnicodeMode(bool mode) {
  this->unicodeMode = mode;
}

void SurfaceImpl::SetDBCSMode(int cp) {
  this->codePage = cp;
}

Surface *Surface::Allocate(int technology) {
  return new SurfaceImpl;
}

//////////////////////////////////////////////////////////////////////////
// Window

Window::~Window() {
}

void Window::Destroy() {
}

bool Window::HasFocus() {
  return false;
}

static std::map<Scintilla::WindowID, Scintilla::PRectangle> rects;

PRectangle Window::GetPosition() {
  return rects[wid];
}

void Window::SetPosition(PRectangle rc) {
  rects[wid] = rc;
}

void Window::SetPositionRelative(PRectangle rc, Window w) {
}

PRectangle Window::GetClientPosition() {
  return PRectangle(0, 0, rects[wid].Width(), rects[wid].Height());
}

void Window::Show(bool show) {
}

void Window::InvalidateAll() {
}

void Window::InvalidateRectangle(PRectangle rc) {
}

void Window::SetFont(Font &font) {
}

void Window::SetCursor(Cursor curs) {
}

PRectangle Window::GetMonitorRect(Point pt) {
  return PRectangle(0, 0, zero_graphics_getWidth(), zero_graphics_getHeight());
}

//////////////////////////////////////////////////////////////////////////
// Menus

Menu::Menu() : mid(0) {
  ZIG_ASSERT(!"Menu::Menu");
}

void Menu::CreatePopUp() {
  ZIG_ASSERT(!"Menu::CreatePopUp");
}

void Menu::Destroy() {
  ZIG_ASSERT(!"Menu::Destroy");
}

void Menu::Show(Point pt, Window &w) {
  ZIG_ASSERT(!"Menu::Show");
}

//////////////////////////////////////////////////////////////////////////
// ListBox implementation

ListBox *ListBox::Allocate() {
  return NULL;
}

struct SHADEREDITOR_THEME {
  unsigned int text;
  unsigned int string;
  unsigned int comment;
  unsigned int number;
  unsigned int op;
  unsigned int keyword;
  unsigned int type;
  unsigned int builtin;
  unsigned int preprocessor;
  unsigned int selection;
  unsigned int charBackground;
  bool bUseCharBackground;

  SHADEREDITOR_THEME()
      : text(0xFFFFFFFF), string(0xFF0000CC), comment(0xFF00FF00), number(0xFF0080FF), op(0xFF00CCFF), keyword(0xFF0066FF), type(0xFFFFFF00), builtin(0xFF88FF44), preprocessor(0xFFC0C0C0), selection(0xC0CC9966), charBackground(0xC0000000), bUseCharBackground(false) {
  }
};

static SHADEREDITOR_THEME theme;

const int nOpacity = 0xFF;
#define BACKGROUND(x) ((x) | (nOpacity << 24))

const std::string sFontFile{"SourceCodePro-Regular.ttf"};
const int nFontSize = 10;

const bool bUseSpacesForTabs = true;
const int nTabSize = 4;

const size_t NB_FOLDER_STATE = 7;
const size_t FOLDER_TYPE = 0;

const int markersArray[][NB_FOLDER_STATE] = {
    {SC_MARKNUM_FOLDEROPEN, SC_MARKNUM_FOLDER, SC_MARKNUM_FOLDERSUB, SC_MARKNUM_FOLDERTAIL, SC_MARKNUM_FOLDEREND, SC_MARKNUM_FOLDEROPENMID, SC_MARKNUM_FOLDERMIDTAIL},
    {SC_MARK_MINUS, SC_MARK_PLUS, SC_MARK_EMPTY, SC_MARK_EMPTY, SC_MARK_EMPTY, SC_MARK_EMPTY, SC_MARK_EMPTY},
    {SC_MARK_ARROWDOWN, SC_MARK_ARROW, SC_MARK_EMPTY, SC_MARK_EMPTY, SC_MARK_EMPTY, SC_MARK_EMPTY, SC_MARK_EMPTY},
    {SC_MARK_CIRCLEMINUS, SC_MARK_CIRCLEPLUS, SC_MARK_VLINE, SC_MARK_LCORNERCURVE, SC_MARK_CIRCLEPLUSCONNECTED, SC_MARK_CIRCLEMINUSCONNECTED, SC_MARK_TCORNERCURVE},
    {SC_MARK_BOXMINUS, SC_MARK_BOXPLUS, SC_MARK_VLINE, SC_MARK_LCORNER, SC_MARK_BOXPLUSCONNECTED, SC_MARK_BOXMINUSCONNECTED, SC_MARK_TCORNER}};

const bool bVisibleWhitespace = true;

class Scintilla::LexState : public LexInterface {
  const LexerModule *lexCurrent;
  void SetLexerModule(const LexerModule *lex);
  PropSetSimple props;
  int interfaceVersion;

public:
  int lexLanguage;

  explicit LexState(Document *pdoc_);
  virtual ~LexState();
  void SetLexer(uptr_t wParam);
  void SetLexerLanguage(const char *languageName);
  const char *DescribeWordListSets();
  void SetWordList(int n, const char *wl);
  const char *GetName() const;
  void *PrivateCall(int operation, void *pointer);
  const char *PropertyNames();
  int PropertyType(const char *name);
  const char *DescribeProperty(const char *name);
  void PropSet(const char *key, const char *val);
  const char *PropGet(const char *key) const;
  int PropGetInt(const char *key, int defaultValue = 0) const;
  int PropGetExpanded(const char *key, char *result) const;

  int LineEndTypesSupported();
  int AllocateSubStyles(int styleBase, int numberStyles);
  int SubStylesStart(int styleBase);
  int SubStylesLength(int styleBase);
  int StyleFromSubStyle(int subStyle);
  int PrimaryStyleFromStyle(int style);
  void FreeSubStyles();
  void SetIdentifiers(int style, const char *identifiers);
  int DistanceToSecondaryStyles();
  const char *GetSubStyleBases();
};

static char const *const lola_keywords =
    "and "
    "break "
    "const "
    "continue "
    "else "
    "for "
    "function "
    "if "
    "in "
    "not "
    "or "
    "return "
    "var "
    "while ";

struct ScintillaEditor : public Scintilla::Editor {
  ZigEditorInterface *current_app;
  Scintilla::Surface *surface;
  Scintilla::LexState *lexState;

  bool bReadOnly = false;
  bool bHasMouseCapture = false;

  ScintillaEditor(ZigEditorInterface *interface) : current_app(interface),
                                                   surface(nullptr),
                                                   lexState(nullptr) {
    log_debug("ScintillaEditor::ScintillaEditor()");

    this->surface = Scintilla::Surface::Allocate(SC_TECHNOLOGY_DEFAULT);
    this->surface->Init(nullptr);

    this->Initialise();
  }

  ScintillaEditor(ScintillaEditor const &) = delete;
  ScintillaEditor(ScintillaEditor &&) = delete;

  ~ScintillaEditor() {
    log_debug("ScintillaEditor::~ScintillaEditor()");
    delete this->surface;
  }

  void Render() {
    auto const window_pos = this->wMain.GetPosition();

    auto rect = this->GetClientRectangle();

    auto clip_rect = rect;
    clip_rect.left += window_pos.left;
    clip_rect.right += window_pos.left;
    clip_rect.top += window_pos.top;
    clip_rect.bottom += window_pos.top;

    auto const temp_rect = cpp2zig(clip_rect);
    current_app->setClipRect(current_app, &temp_rect);

    this->Paint(this->surface, rect);
  }

  void Initialise() override {
    wMain = reinterpret_cast<Scintilla::WindowID>(this);

    lexState = new Scintilla::LexState(pdoc);

    this->WndProc(SCI_SETBUFFEREDDRAW, 0, 0);
    this->WndProc(SCI_SETCODEPAGE, SC_CP_UTF8, 0);

    this->WndProc(SCI_SETWRAPMODE, SC_WRAP_WORD, 0);

    WndProc(SCI_SETLEXERLANGUAGE, SCLEX_CPP, 0);

    this->SetAStyle(STYLE_DEFAULT, 0xFFFFFFFF, BACKGROUND(0x000000), nFontSize, sFontFile.c_str());
    this->WndProc(SCI_STYLECLEARALL, 0, 0);
    this->SetAStyle(STYLE_LINENUMBER, 0xFFC0C0C0, BACKGROUND(0x000000), nFontSize, sFontFile.c_str());
    this->SetAStyle(STYLE_BRACELIGHT, 0xFF00FF00, BACKGROUND(0x000000), nFontSize, sFontFile.c_str());
    this->SetAStyle(STYLE_BRACEBAD, 0xFF0000FF, BACKGROUND(0x000000), nFontSize, sFontFile.c_str());
    this->SetAStyle(STYLE_INDENTGUIDE, 0xFFC0C0C0, BACKGROUND(0x000000), nFontSize, sFontFile.c_str());

    // this->WndProc(SCI_SETFOLDMARGINCOLOUR,   1, BACKGROUND( 0x1A1A1A ));
    // this->WndProc(SCI_SETFOLDMARGINHICOLOUR, 1, BACKGROUND( 0x1A1A1A ));
    // this->WndProc(SCI_SETSELBACK,            1, theme.selection);

    this->SetReadOnly(false);

    // for (size_t i = 0 ; i < NB_FOLDER_STATE ; i++)
    // {
    //   this->WndProc(SCI_MARKERDEFINE,  markersArray[FOLDER_TYPE][i], markersArray[4][i]);
    //   this->WndProc(SCI_MARKERSETBACK, markersArray[FOLDER_TYPE][i], 0xFF6A6A6A);
    //   this->WndProc(SCI_MARKERSETFORE, markersArray[FOLDER_TYPE][i], 0xFF333333);
    // }
    this->WndProc(SCI_SETUSETABS, bUseSpacesForTabs ? 0 : 1, 0);
    this->WndProc(SCI_SETTABWIDTH, nTabSize, 0);
    this->WndProc(SCI_SETINDENT, nTabSize, 0);
    this->WndProc(SCI_SETINDENTATIONGUIDES, SC_IV_REAL, 0);

    if (bVisibleWhitespace) {
      WndProc(SCI_SETVIEWWS, SCWS_VISIBLEALWAYS, 0);
      WndProc(SCI_SETWHITESPACEFORE, 1, 0x30FFFFFF);
      WndProc(SCI_SETWHITESPACESIZE, 2, 0);
    }

    lexState->SetLexer(SCLEX_CPP);
    lexState->SetWordList(0, "var const while for if else function in");
    lexState->SetWordList(1, "and or not");
    lexState->SetWordList(3, "return continue break");
    // Do not grey out code inside #if #else #endif (when set to 1 it causes problems with fully transparent background)
    lexState->PropSet("lexer.cpp.track.preprocessor", "0");
    // Colorize the content of the #defines (thx @blackle for finding it)
    lexState->PropSet("styling.within.preprocessor", "1");

    this->SetAStyle(SCE_C_DEFAULT, theme.text, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000), nFontSize, sFontFile.c_str());
    this->SetAStyle(SCE_C_WORD, theme.keyword, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_WORD2, theme.type, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_GLOBALCLASS, theme.builtin, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_PREPROCESSOR, theme.preprocessor, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_NUMBER, theme.number, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_OPERATOR, theme.op, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_COMMENT, theme.comment, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_COMMENTLINE, theme.comment, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));

    // Misc chars to cover for standard text
    this->SetAStyle(SCE_C_COMMENTDOC, theme.comment, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_STRING, theme.string, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_CHARACTER, theme.string, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_UUID, theme.text, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_IDENTIFIER, theme.text, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_STRINGEOL, theme.text, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_VERBATIM, theme.text, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_REGEX, theme.text, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_COMMENTLINEDOC, theme.text, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_COMMENTDOCKEYWORD, theme.comment, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_COMMENTDOCKEYWORDERROR, theme.comment, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_STRINGRAW, theme.string, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_TRIPLEVERBATIM, theme.string, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_HASHQUOTEDSTRING, theme.string, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_PREPROCESSORCOMMENT, theme.comment, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_PREPROCESSORCOMMENTDOC, theme.comment, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_USERLITERAL, theme.text, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_TASKMARKER, theme.text, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));
    this->SetAStyle(SCE_C_ESCAPESEQUENCE, theme.text, theme.bUseCharBackground ? theme.charBackground : BACKGROUND(0x000000));

    lexState->Colourise(0, -1);

    // WndProc( SCI_COLOURISE, 0, 0 );

    this->vs.Refresh(*this->surface, nTabSize);
  }

  void SetPosition(Scintilla::PRectangle rect) {
    this->wMain.SetPosition(rect);
  }

  void SetAStyle(int style, Scintilla::ColourDesired fore, Scintilla::ColourDesired back = 0xFFFFFFFF, int size = -1, const char *face = 0) {
    this->WndProc(SCI_STYLESETFORE, style, (sptr_t)fore.AsLong());
    this->WndProc(SCI_STYLESETBACK, style, (sptr_t)back.AsLong());
    if (size >= 1)
      this->WndProc(SCI_STYLESETSIZE, style, size);
    if (face)
      this->WndProc(SCI_STYLESETFONT, style, reinterpret_cast<sptr_t>(face));
  }

  void SetReadOnly(bool b) {
    bReadOnly = b;
    this->WndProc(SCI_SETREADONLY, bReadOnly, 0);
    if (bReadOnly) {
      this->WndProc(SCI_SETVIEWWS, SCWS_INVISIBLE, 0);
      this->WndProc(SCI_SETMARGINWIDTHN, 0, 0);
      this->WndProc(SCI_SETMARGINWIDTHN, 1, 0);
      this->WndProc(SCI_SETCARETLINEVISIBLE, 0, 0);
      this->WndProc(SCI_SETCARETFORE, 0, 0);
    } else {
      this->WndProc(SCI_SETMARGINWIDTHN, 0, 40);             //Calculate correct width
      this->WndProc(SCI_SETMARGINWIDTHN, 1, 0);              //Calculate correct width
      this->WndProc(SCI_SETMARGINMASKN, 1, SC_MASK_FOLDERS); //Calculate correct width

      this->WndProc(SCI_SETCARETFORE, 0xFFFFFFFF, 0);
      this->WndProc(SCI_SETCARETLINEVISIBLE, 1, 0);
      this->WndProc(SCI_SETCARETLINEBACK, 0xFFFFFFFF, 0);
      this->WndProc(SCI_SETCARETLINEBACKALPHA, 0x20, 0);
    }
  }

  void SetText(const char *string, size_t length) {
    this->WndProc(SCI_SETREADONLY, false, 0);
    this->WndProc(SCI_CLEARALL, false, 0);
    this->WndProc(SCI_SETUNDOCOLLECTION, 0, 0);
    this->WndProc(SCI_ADDTEXT, length, (sptr_t)string);
    this->WndProc(SCI_SETUNDOCOLLECTION, 1, 0);
    this->WndProc(SCI_SETREADONLY, bReadOnly, 0);
    this->WndProc(SCI_GOTOPOS, 0, 0);
    if (!bReadOnly) {
      this->SetFocusState(true);
    }
  }

  ZigString GetText(void *allocator) {
    int lengthDoc = (int)this->WndProc(SCI_GETLENGTH, 0, 0);

    char *buffer = static_cast<char *>(zero_graphics_alloc(allocator, lengthDoc));
    if (buffer != nullptr) {
      Scintilla::TextRange tr;
      tr.chrg.cpMin = 0;
      tr.chrg.cpMax = lengthDoc;
      tr.lpstrText = buffer;
      this->WndProc(SCI_GETTEXTRANGE, 0, reinterpret_cast<sptr_t>(&tr));
    }
    return ZigString{buffer, size_t(lengthDoc)};
  }

  void ButtonDown(Scintilla::Point pt, unsigned int curTime, bool shift, bool ctrl, bool alt) override {
    Scintilla::Editor::ButtonDown(pt, curTime, shift, ctrl, alt);
  }

  void ButtonMovePublic(Scintilla::Point pt) {
    ButtonMove(pt);
  }

  void ButtonUp(Scintilla::Point pt, unsigned int curTime, bool ctrl) {
    Scintilla::Editor::ButtonUp(pt, curTime, ctrl);
  }

  int KeyDown(int key, bool shift, bool ctrl, bool alt, bool *consumed) {
    return Scintilla::Editor::KeyDown(key, shift, ctrl, alt, consumed);
  }

  void AddCharUTF(const char *s, unsigned int len, bool treatAsDBCS) override {
    Scintilla::Editor::AddCharUTF(s, len, treatAsDBCS);
  }

public:
  sptr_t DefWndProc(unsigned int iMessage, uptr_t wParam, sptr_t lParam) override {
    return 0;
  }

  void SetVerticalScrollPos() override {
    log_debug("SetVerticalScrollPos");
  }
  void SetHorizontalScrollPos() override {
    log_debug("SetHorizontalScrollPos");
  }
  bool ModifyScrollBars(int nMax, int nPage) override {
    log_debug("ModifyScrollBars(nMax=%d,nPage=%d)", nMax, nPage);
    return true;
  }
  void Copy() override {
    if (!sel.Empty()) {
      SelectionText selectedText;
      CopySelectionRange(&selectedText);
      CopyToClipboard(selectedText);
    }
  }
  void Paste() override {

    char tiny_buffer[1024];

    size_t len = current_app->getClipboardContent(current_app, tiny_buffer, sizeof(tiny_buffer));
    if (len == 0)
      return;

    if (len <= sizeof(tiny_buffer)) {
      ClearSelection();
      InsertPaste(tiny_buffer, len);
    } else {
      std::vector<char> clipboard_content;
      clipboard_content.resize(len);

      size_t len2 = current_app->getClipboardContent(current_app, clipboard_content.data(), sizeof(tiny_buffer));
      ZIG_ASSERT(len == len2);

      ClearSelection();
      InsertPaste(clipboard_content.data(), len);
    }
  }
  void ClaimSelection() override {
    log_debug("ClaimSelection");
  }
  void NotifyChange() override {
    log_debug("NotifyChange");
  }
  void NotifyParent(SCNotification scn) override {
    // log_debug("NotifyParent");
    // switch (scn.nmhdr.code) {
    //   case SCN_CHARADDED:
    //     char ch = static_cast<char>(scn.ch);
    //     if(eAutoIndent == aitPreserve) {
    //       PreserveIndentation(ch);
    //     } else if (eAutoIndent == aitSmart) {
    //       AutomaticIndentation(ch);
    //     }
    //     break;
    //   }
  }
  void CopyToClipboard(const SelectionText &selectedText) override {
    current_app->setClipboardContent(current_app, selectedText.Data(), selectedText.Length());
  }
  void SetMouseCapture(bool on) override {
    log_debug("SetMouseCapture(%d)", on);
    bHasMouseCapture = on;
  }
  bool HaveMouseCapture() override {
    return bHasMouseCapture;
  }

  bool FineTickerRunning(TickReason) override {
    return false;
  }

  void FineTickerStart(TickReason, int, int) override {
  }

  void FineTickerCancel(TickReason) override {
  }

  void Tick() {
    Scintilla::Editor::Tick();
  }

  void SetTicking(bool on) override {
  }

  void NotifyStyleToNeeded(int endStyleNeeded) override {
#ifdef SCI_LEXER
    if (lexState->lexLanguage != SCLEX_CONTAINER) {
      int lineEndStyled = pdoc->LineFromPosition(pdoc->GetEndStyled());
      int endStyled = pdoc->LineStart(lineEndStyled);
      lexState->Colourise(endStyled, endStyleNeeded);
      return;
    }
#endif
    Scintilla::Editor::NotifyStyleToNeeded(endStyleNeeded);
  }
};

ScintillaEditor *scintilla_create(ZigEditorInterface *interface) {
  PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack> pseudo_global{interface};
  return new ScintillaEditor(interface);
}

void scintilla_setText(ScintillaEditor *editor, char const *string, size_t length) {
  PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack> pseudo_global{editor->current_app};
  editor->SetText(string, length);
}

void scintilla_tick(ScintillaEditor *editor) {
  PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack> pseudo_global{editor->current_app};
  editor->Tick();
}

void scintilla_render(ScintillaEditor *editor) {
  PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack> pseudo_global{editor->current_app};
  // Renderer::SetTextRenderingViewport( wMain.GetPosition() );
  editor->Render();
}

ZigString scintilla_getText(ScintillaEditor *editor, void *allocator) {
  PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack> pseudo_global{editor->current_app};
  return editor->GetText(allocator);
}

void scintilla_mouseMove(ScintillaEditor *editor, int x, int y) {
  PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack> pseudo_global{editor->current_app};
  editor->ButtonMovePublic(Scintilla::Point(x, y));
}

void scintilla_mouseDown(ScintillaEditor *editor, float time, int x, int y) {
  PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack> pseudo_global{editor->current_app};
  editor->ButtonDown(Scintilla::Point(x, y), time * 1000, false, false, false);
}

void scintilla_mouseUp(ScintillaEditor *editor, float time, int x, int y) {
  PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack> pseudo_global{editor->current_app};
  editor->ButtonUp(Scintilla::Point(x, y), time * 1000, false);
}

static int zigScanToSci(int sc);

bool scintilla_keyDown(ScintillaEditor *editor, int zig_scancode, bool shift, bool ctrl, bool alt) {
  PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack> pseudo_global{editor->current_app};
  int sci_scancode = zigScanToSci(zig_scancode);
  if (sci_scancode != 0) {
    bool consumed = false;
    editor->KeyDown(sci_scancode, shift, ctrl, alt, &consumed);
    return consumed;
  } else {
    return false;
  }
}

void scintilla_enterString(ScintillaEditor *editor, char const *str, size_t len) {
  PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack> pseudo_global{editor->current_app};
  editor->AddCharUTF(str, len, false);
}

void scintilla_setPosition(ScintillaEditor *editor, int x, int y, int w, int h) {
  PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack> pseudo_global{editor->current_app};
  editor->SetPosition(PRectangle{float(x), float(y), float(x + w), float(y + h)});
}

void scintilla_destroy(ScintillaEditor *editor) {
  PseudoGlobal<ZigEditorInterface *, EditorInterfaceHack> pseudo_global{editor->current_app};
  delete editor;
}

void scintilla_init() {
#ifdef SCI_LEXER
  Scintilla_LinkLexers();
#endif
}

void scintilla_deinit() {
}

// switch (key) {
//         case GLFW_KEY_F1:           sciKey = 282;           break;
//         case GLFW_KEY_F2:           sciKey = 283;           break;
//         case GLFW_KEY_F3:           sciKey = 284;           break;
//         case GLFW_KEY_F4:           sciKey = 285;           break;
//         case GLFW_KEY_F5:           sciKey = 286;           break;
//         case GLFW_KEY_F6:           sciKey = 287;           break;
//         case GLFW_KEY_F7:           sciKey = 288;           break;
//         case GLFW_KEY_F8:           sciKey = 289;           break;
//         case GLFW_KEY_F9:           sciKey = 290;           break;
//         case GLFW_KEY_F10:          sciKey = 291;           break;
//         case GLFW_KEY_F11:          sciKey = 292;           break;
//         case GLFW_KEY_F12:          sciKey = 293;           break;
//         case GLFW_KEY_LEFT_SHIFT:
//         case GLFW_KEY_RIGHT_SHIFT:
//         case GLFW_KEY_LEFT_ALT:
//         case GLFW_KEY_RIGHT_ALT:
//         case GLFW_KEY_LEFT_CONTROL:
//         case GLFW_KEY_RIGHT_CONTROL:
//         case GLFW_KEY_LEFT_SUPER:
//         case GLFW_KEY_RIGHT_SUPER:
//           sciKey = 0;
//           break;
//         default:
//           bNormalKey = true;
//           // TODO: Horrible hack to migrate from GLFW (that uses ascii maj for keys) to scintilla min keys
//           if ( (key >= GLFW_KEY_A) && (key <= GLFW_KEY_Z) ) {
//             sciKey = key+32;
//           }
//           else {
//             sciKey = 0;
//           }
//       }

static int zigScanToSci(int sc) {
  switch (sc) {
  case 1:
    return 'A'; // a
  case 2:
    return 'B'; // b
  case 3:
    return 'C'; // c
  case 4:
    return 'D'; // d
  case 5:
    return 'E'; // e
  case 6:
    return 'F'; // f
  case 7:
    return 'G'; // g
  case 8:
    return 'H'; // h
  case 9:
    return 'I'; // i
  case 10:
    return 'J'; // j
  case 11:
    return 'K'; // k
  case 12:
    return 'L'; // l
  case 13:
    return 'M'; // m
  case 14:
    return 'N'; // n
  case 15:
    return 'O'; // o
  case 16:
    return 'P'; // p
  case 17:
    return 'Q'; // q
  case 18:
    return 'R'; // r
  case 19:
    return 'S'; // s
  case 20:
    return 'T'; // t
  case 21:
    return 'U'; // u
  case 22:
    return 'V'; // v
  case 23:
    return 'W'; // w
  case 24:
    return 'X'; // x
  case 25:
    return 'Y'; // y
  case 26:
    return 'Z'; // z
  case 27:
    return '1'; // @"1"
  case 28:
    return '2'; // @"2"
  case 29:
    return '3'; // @"3"
  case 30:
    return '4'; // @"4"
  case 31:
    return '5'; // @"5"
  case 32:
    return '6'; // @"6"
  case 33:
    return '7'; // @"7"
  case 34:
    return '8'; // @"8"
  case 35:
    return '9'; // @"9"
  case 36:
    return '0'; // @"0"
  case 37:
    return SCK_RETURN; // @"return"
  case 38:
    return SCK_ESCAPE; // escape
  case 39:
    return SCK_BACK; // backspace
  case 40:
    return SCK_TAB; // tab
  case 58:
    return SCK_INSERT; // insert
  case 59:
    return SCK_HOME; // home
  case 60:
    return SCK_PRIOR; // page_up
  case 61:
    return SCK_DELETE; // delete
  case 62:
    return SCK_END; // end
  case 63:
    return SCK_NEXT; // page_down
  case 64:
    return SCK_RIGHT; // right
  case 65:
    return SCK_LEFT; // left
  case 66:
    return SCK_DOWN; // down
  case 67:
    return SCK_UP; // up
  case 69:
    return SCK_DIVIDE; // keypad_divide
  case 71:
    return SCK_SUBTRACT; // keypad_minus
  case 72:
    return SCK_ADD; // keypad_plus
  case 73:
    return SCK_RETURN; // keypad_enter
  case 159:
    return SCK_MENU; // menu
  case 41:           // space
  case 42:           // minus
  case 43:           // equals
  case 44:           // left_bracket
  case 45:           // right_bracket
  case 46:           // backslash
  case 47:           // nonushash
  case 48:           // semicolon
  case 49:           // apostrophe
  case 50:           // grave
  case 51:           // comma
  case 52:           // period
  case 53:           // slash
  case 54:           // caps_lock
  case 55:           // print_screen
  case 56:           // scroll_lock
  case 57:           // pause
  case 68:           // num_lock_clear
  case 70:           // keypad_multiply
  case 74:           // keypad_1
  case 75:           // keypad_2
  case 76:           // keypad_3
  case 77:           // keypad_4
  case 78:           // keypad_5
  case 79:           // keypad_6
  case 80:           // keypad_7
  case 81:           // keypad_8
  case 82:           // keypad_9
  case 83:           // keypad_0
  case 84:           // keypad_00
  case 85:           // keypad_000
  case 86:           // keypad_period
  case 87:           // keypad_comma
  case 88:           // keypad_equalsas400
  case 89:           // keypad_leftparen
  case 90:           // keypad_rightparen
  case 91:           // keypad_leftbrace
  case 92:           // keypad_rightbrace
  case 93:           // keypad_tab
  case 94:           // keypad_backspace
  case 95:           // keypad_a
  case 96:           // keypad_b
  case 97:           // keypad_c
  case 98:           // keypad_d
  case 99:           // keypad_e
  case 100:          // keypad_f
  case 101:          // keypad_xor
  case 102:          // keypad_power
  case 103:          // keypad_percent
  case 104:          // keypad_less
  case 105:          // keypad_greater
  case 106:          // keypad_ampersand
  case 107:          // keypad_dblampersand
  case 108:          // keypad_verticalbar
  case 109:          // keypad_dblverticalbar
  case 110:          // keypad_colon
  case 111:          // keypad_hash
  case 112:          // keypad_space
  case 113:          // keypad_at
  case 114:          // keypad_exclam
  case 115:          // keypad_memstore
  case 116:          // keypad_memrecall
  case 117:          // keypad_memclear
  case 118:          // keypad_memadd
  case 119:          // keypad_memsubtract
  case 120:          // keypad_memmultiply
  case 121:          // keypad_memdivide
  case 122:          // keypad_plusminus
  case 123:          // keypad_clear
  case 124:          // keypad_clearentry
  case 125:          // keypad_binary
  case 126:          // keypad_octal
  case 127:          // keypad_decimal
  case 128:          // keypad_hexadecimal
  case 129:          // keypad_equals
  case 130:          // f1
  case 131:          // f2
  case 132:          // f3
  case 133:          // f4
  case 134:          // f5
  case 135:          // f6
  case 136:          // f7
  case 137:          // f8
  case 138:          // f9
  case 139:          // f10
  case 140:          // f11
  case 141:          // f12
  case 142:          // f13
  case 143:          // f14
  case 144:          // f15
  case 145:          // f16
  case 146:          // f17
  case 147:          // f18
  case 148:          // f19
  case 149:          // f20
  case 150:          // f21
  case 151:          // f22
  case 152:          // f23
  case 153:          // f24
  case 154:          // nonusbackslash
  case 155:          // application
  case 156:          // power
  case 157:          // execute
  case 158:          // help
  case 160:          // select
  case 161:          // stop
  case 162:          // again
  case 163:          // undo
  case 164:          // cut
  case 165:          // copy
  case 166:          // paste
  case 167:          // find
  case 168:          // mute
  case 169:          // volumeup
  case 170:          // volumedown
  case 171:          // alterase
  case 172:          // sysreq
  case 173:          // cancel
  case 174:          // clear
  case 175:          // prior
  case 176:          // return2
  case 177:          // separator
  case 178:          // out
  case 179:          // oper
  case 180:          // clearagain
  case 181:          // crsel
  case 182:          // exsel
  case 183:          // thousandsseparator
  case 184:          // decimalseparator
  case 185:          // currencyunit
  case 186:          // currencysubunit
  case 187:          // ctrl_left
  case 188:          // shift_left
  case 189:          // alt_left
  case 190:          // gui_left
  case 191:          // ctrl_right
  case 192:          // shift_right
  case 193:          // alt_right
  case 194:          // gui_right
  case 195:          // mode
  case 196:          // audio_next
  case 197:          // audio_prev
  case 198:          // audio_stop
  case 199:          // audio_play
  case 200:          // audio_mute
  case 201:          // audio_rewind
  case 202:          // audio_fastforward
  case 203:          // media_select
  case 204:          // www
  case 205:          // mail
  case 206:          // calculator
  case 207:          // computer
  case 208:          // ac_search
  case 209:          // ac_home
  case 210:          // ac_back
  case 211:          // ac_forward
  case 212:          // ac_stop
  case 213:          // ac_refresh
  case 214:          // ac_bookmarks
  case 215:          // brightness_down
  case 216:          // brightness_up
  case 217:          // displayswitch
  case 218:          // kbdillumtoggle
  case 219:          // kbdillumdown
  case 220:          // kbdillumup
  case 221:          // eject
  case 222:          // sleep
  case 223:          // app1
  case 224:          // app2
    break;
  }
  return 0;
}