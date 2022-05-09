const utf8decoder = new TextDecoder()
const utf8encoder = new TextEncoder()

function getString(getInstance, offset, length) {
  return utf8decoder.decode(new Uint8Array(getInstance().exports.memory.buffer, offset, length))
}

function getU32Array(getInstance, offset, length) {
  return new Uint32Array(getInstance().exports.memory.buffer, offset, length)
}

function
createPlatformEnvironment(getInstance) {
  let log_string = ''
  return {
    wasm_quit() {
      throw 'application exit'
    }
    ,
        wasm_panic: (ptr, len) => {
          let msg = getString(getInstance, ptr, len)
          throw Error(msg)
        }, wasm_log_write: (ptr, len) => {
          log_string += getString(getInstance, ptr, len)
        }, wasm_log_flush: () => {
          console.log(log_string)
          log_string = ''
        },

                          now_f64() {
      return Date.now()
    }
    ,
  }
}

function createWebsocketModule(getInstance) {
  const getMemory = () => getInstance().exports.memory

  let context = {
    next_id : 1,
    instances : {},
  }

  return {
    create(server_ptr, server_len, protocols_str_ptr, protocols_len_ptr, protocols_len) {
      let server = getString(getInstance, server_ptr, server_len)
      let protocols_ptr_arr = getU32Array(getInstance, protocols_str_ptr, protocols_len)
      let protocols_len_arr = getU32Array(getInstance, protocols_len_ptr, protocols_len)
      let protocols = []
      protocols.length = protocols_ptr_arr.length;
      for (const i in protocols_ptr_arr) {
        protocols[i] = getString(getInstance, protocols_ptr_arr[i], protocols_len_arr[i])
      }

      console.log(server, protocols);

      var ws = new WebSocket(server, protocols);

      var id = context.next_id;
      context.next_id += 1;
      context.instances[id] = ws;

      // app_ws_alloc(length: u32) ?[*]u8
      // app_ws_onmessage(handle: Handle, binary: bool, message_ptr: [*]u8, message_len: usize) void
      // app_ws_onopen(handle: Handle) void
      // app_ws_onerror(handle: Handle) void
      // app_ws_onclose(handle: Handle) void

      ws.onopen = function(event) {
        getInstance().exports.app_ws_onopen(id);
      };
      ws.onmessage = async function(event) {
        var binary;
        var array;
        if (typeof (event.data) == "string") {
          binary = false;
          array = utf8encoder.encode(event.data);
        } else {
          binary = true;
          array = new Uint8Array(await event.data.arrayBuffer());
        }

        const api = getInstance().exports;

        const ptr = api.app_ws_alloc(array.length);
        if (ptr == 0) {
          console.error("out of memory when allocating", array.length, "bytes");
          return;
        }

        const view = new Uint8Array(api.memory.buffer, ptr, array.length);
        view.set(array);

        api.app_ws_onmessage(id, binary, ptr, array.length);
      };
      ws.onclose = function(event) {
        getInstance().exports.app_ws_onclose(id);
      };
      ws.onerror = function(event) {
        getInstance().exports.app_ws_onerror(id);
      };

      return id
    }
    , destroy(handle) {
      let instance = context.instances[handle];
      if (!instance) {
        return
      }
      instance.close()
      context.instances[handle] = undefined
    }
    , send(handle, binary, message_ptr, message_len) {
      let instance = context.instances[handle];
      if (!instance) {
        throw 'invalid websocket handle ' + String(handle)
      }
      if (binary) {
        instance.send(new Uint8Array(getInstance().exports.memory.buffer, message_ptr, message_len))
      } else {
        instance.send(getString(getInstance, message_ptr, message_len))
      }
    }
  }
}

const keyCodeToScancodeMap = {
  KeyA : 1,            //  => SC.a,
  KeyB : 2,            //  => SC.b,
  KeyC : 3,            //  => SC.c,
  KeyD : 4,            //  => SC.d,
  KeyE : 5,            //  => SC.e,
  KeyF : 6,            //  => SC.f,
  KeyG : 7,            //  => SC.g,
  KeyH : 8,            //  => SC.h,
  KeyI : 9,            //  => SC.i,
  KeyJ : 10,           //  => SC.j,
  KeyK : 11,           //  => SC.k,
  KeyL : 12,           //  => SC.l,
  KeyM : 13,           //  => SC.m,
  KeyN : 14,           //  => SC.n,
  KeyO : 15,           //  => SC.o,
  KeyP : 16,           //  => SC.p,
  KeyQ : 17,           //  => SC.q,
  KeyR : 18,           //  => SC.r,
  KeyS : 19,           //  => SC.s,
  KeyT : 20,           //  => SC.t,
  KeyU : 21,           //  => SC.u,
  KeyV : 22,           //  => SC.v,
  KeyW : 23,           //  => SC.w,
  KeyX : 24,           //  => SC.x,
  KeyY : 25,           //  => SC.y,
  KeyZ : 26,           //  => SC.z,
  Digit1 : 27,         //  => SC.@"1",
  Digit2 : 28,         //  => SC.@"2",
  Digit3 : 29,         //  => SC.@"3",
  Digit4 : 30,         //  => SC.@"4",
  Digit5 : 31,         //  => SC.@"5",
  Digit6 : 32,         //  => SC.@"6",
  Digit7 : 33,         //  => SC.@"7",
  Digit8 : 34,         //  => SC.@"8",
  Digit9 : 35,         //  => SC.@"9",
  Digit0 : 36,         //  => SC.@"0",
  Enter : 37,          //  => SC.@"return",
  Escape : 38,         //  => SC.escape,
  Backspace : 39,      //  => SC.backspace,
  Tab : 40,            //  => SC.tab,
  Space : 41,          //  => SC.space,
  Minus : 42,          //  => SC.minus,
  Equal : 43,          //  => SC.equals,
  BracketLeft : 44,    //  => SC.left_bracket,
  RightBracket : 45,   //  => SC.right_bracket,
  Backslash : 46,      //  => SC.backslash,
  Unknown : 47,        //  => SC.nonushash,
  Semicolon : 48,      //  => SC.semicolon,
  Unknown : 49,        //  => SC.apostrophe,
  Unknown : 50,        //  => SC.grave,
  Comma : 51,          //  => SC.comma,
  Period : 52,         //  => SC.period,
  Slash : 53,          //  => SC.slash,
  CapsLock : 54,       //  => SC.caps_lock,
  PrintScreen : 55,    //  => SC.print_screen,
  Unknown : 56,        //  => SC.scroll_lock,
  Unknown : 57,        //  => SC.pause,
  Insert : 58,         //  => SC.insert,
  Home : 59,           //  => SC.home,
  PageUp : 60,         //  => SC.page_up,
  Delete : 61,         //  => SC.delete,
  End : 62,            //  => SC.end,
  PageDown : 63,       //  => SC.page_down,
  ArrowRight : 64,     //  => SC.right,
  ArrowLeft : 65,      //  => SC.left,
  ArrowDown : 66,      //  => SC.down,
  ArrowUp : 67,        //  => SC.up,
  NumLock : 68,        //  => SC.num_lock_clear,
  NumpadDivide : 69,   //  => SC.keypad_divide,
  NumpadMultiply : 70, //  => SC.keypad_multiply,
  NumpadSubtract : 71, //  => SC.keypad_minus,
  NumpadAdd : 72,      //  => SC.keypad_plus,
  Unknown : 73,        //  => SC.keypad_enter,
  Numpad1 : 74,        //  => SC.keypad_1,
  Numpad2 : 75,        //  => SC.keypad_2,
  Numpad3 : 76,        //  => SC.keypad_3,
  Numpad4 : 77,        //  => SC.keypad_4,
  Numpad5 : 78,        //  => SC.keypad_5,
  Numpad6 : 79,        //  => SC.keypad_6,
  Numpad7 : 80,        //  => SC.keypad_7,
  Numpad8 : 81,        //  => SC.keypad_8,
  Numpad9 : 82,        //  => SC.keypad_9,
  Numpad0 : 83,        //  => SC.keypad_0,
  Unknown : 84,        //  => SC.keypad_00,
  Unknown : 85,        //  => SC.keypad_000,
  Unknown : 86,        //  => SC.keypad_period,
  NumpadDecimal : 87,  //  => SC.keypad_comma,
  Unknown : 88,        //  => SC.keypad_equalsas400,
  Unknown : 89,        //  => SC.keypad_leftparen,
  Unknown : 90,        //  => SC.keypad_rightparen,
  Unknown : 91,        //  => SC.keypad_leftbrace,
  Unknown : 92,        //  => SC.keypad_rightbrace,
  Unknown : 93,        //  => SC.keypad_tab,
  Unknown : 94,        //  => SC.keypad_backspace,
  Unknown : 95,        //  => SC.keypad_a,
  Unknown : 96,        //  => SC.keypad_b,
  Unknown : 97,        //  => SC.keypad_c,
  Unknown : 98,        //  => SC.keypad_d,
  Unknown : 99,        //  => SC.keypad_e,
  Unknown : 100,       //  => SC.keypad_f,
  Unknown : 101,       //  => SC.keypad_xor,
  Unknown : 102,       //  => SC.keypad_power,
  Unknown : 103,       //  => SC.keypad_percent,
  Unknown : 104,       //  => SC.keypad_less,
  Unknown : 105,       //  => SC.keypad_greater,
  Unknown : 106,       //  => SC.keypad_ampersand,
  Unknown : 107,       //  => SC.keypad_dblampersand,
  Unknown : 108,       //  => SC.keypad_verticalbar,
  Unknown : 109,       //  => SC.keypad_dblverticalbar,
  Unknown : 110,       //  => SC.keypad_colon,
  Unknown : 111,       //  => SC.keypad_hash,
  Unknown : 112,       //  => SC.keypad_space,
  Unknown : 113,       //  => SC.keypad_at,
  Unknown : 114,       //  => SC.keypad_exclam,
  Unknown : 115,       //  => SC.keypad_memstore,
  Unknown : 116,       //  => SC.keypad_memrecall,
  Unknown : 117,       //  => SC.keypad_memclear,
  Unknown : 118,       //  => SC.keypad_memadd,
  Unknown : 119,       //  => SC.keypad_memsubtract,
  Unknown : 120,       //  => SC.keypad_memmultiply,
  Unknown : 121,       //  => SC.keypad_memdivide,
  Unknown : 122,       //  => SC.keypad_plusminus,
  Unknown : 123,       //  => SC.keypad_clear,
  Unknown : 124,       //  => SC.keypad_clearentry,
  Unknown : 125,       //  => SC.keypad_binary,
  Unknown : 126,       //  => SC.keypad_octal,
  Unknown : 127,       //  => SC.keypad_decimal,
  Unknown : 128,       //  => SC.keypad_hexadecimal,
  Unknown : 129,       //  => SC.keypad_equals,
  F1 : 130,            //  => SC.f1,
  F2 : 131,            //  => SC.f2,
  F3 : 132,            //  => SC.f3,
  F4 : 133,            //  => SC.f4,
  F5 : 134,            //  => SC.f5,
  F6 : 135,            //  => SC.f6,
  F7 : 136,            //  => SC.f7,
  F8 : 137,            //  => SC.f8,
  F9 : 138,            //  => SC.f9,
  F10 : 139,           //  => SC.f10,
  F11 : 140,           //  => SC.f11,
  F12 : 141,           //  => SC.f12,
  F13 : 142,           //  => SC.f13,
  F14 : 143,           //  => SC.f14,
  F15 : 144,           //  => SC.f15,
  F16 : 145,           //  => SC.f16,
  F17 : 146,           //  => SC.f17,
  F18 : 147,           //  => SC.f18,
  F19 : 148,           //  => SC.f19,
  F20 : 149,           //  => SC.f20,
  F21 : 150,           //  => SC.f21,
  F22 : 151,           //  => SC.f22,
  F23 : 152,           //  => SC.f23,
  F24 : 153,           //  => SC.f24,
  Unknown : 154,       //  => SC.nonusbackslash,
  Unknown : 155,       //  => SC.application,
  Unknown : 156,       //  => SC.power,
  Unknown : 157,       //  => SC.execute,
  Unknown : 158,       //  => SC.help,
  Unknown : 159,       //  => SC.menu,
  Unknown : 160,       //  => SC.select,
  Unknown : 161,       //  => SC.stop,
  Unknown : 162,       //  => SC.again,
  Unknown : 163,       //  => SC.undo,
  Unknown : 164,       //  => SC.cut,
  Unknown : 165,       //  => SC.copy,
  Unknown : 166,       //  => SC.paste,
  Unknown : 167,       //  => SC.find,
  Unknown : 168,       //  => SC.mute,
  Unknown : 169,       //  => SC.volumeup,
  Unknown : 170,       //  => SC.volumedown,
  Unknown : 171,       //  => SC.alterase,
  Unknown : 172,       //  => SC.sysreq,
  Unknown : 173,       //  => SC.cancel,
  Unknown : 174,       //  => SC.clear,
  Unknown : 175,       //  => SC.prior,
  Unknown : 176,       //  => SC.return2,
  Unknown : 177,       //  => SC.separator,
  Unknown : 178,       //  => SC.out,
  Unknown : 179,       //  => SC.oper,
  Unknown : 180,       //  => SC.clearagain,
  Unknown : 181,       //  => SC.crsel,
  Unknown : 182,       //  => SC.exsel,
  Unknown : 183,       //  => SC.thousandsseparator,
  Unknown : 184,       //  => SC.decimalseparator,
  Unknown : 185,       //  => SC.currencyunit,
  Unknown : 186,       //  => SC.currencysubunit,
  ControlLeft : 187,   //  => SC.ctrl_left,
  ShiftLeft : 188,     //  => SC.shift_left,
  AltLeft : 189,       //  => SC.alt_left,
  MetaLeft : 190,      //  => SC.gui_left,
  ControlRight : 191,  //  => SC.ctrl_right,
  ShiftRight : 192,    //  => SC.shift_right,
  AltRight : 193,      //  => SC.alt_right,
  MetaRight : 194,     //  => SC.gui_right,
  Unknown : 195,       //  => SC.mode,
  Unknown : 196,       //  => SC.audio_next,
  Unknown : 197,       //  => SC.audio_prev,
  Unknown : 198,       //  => SC.audio_stop,
  Unknown : 199,       //  => SC.audio_play,
  Unknown : 200,       //  => SC.audio_mute,
  Unknown : 201,       //  => SC.audio_rewind,
  Unknown : 202,       //  => SC.audio_fastforward,
  Unknown : 203,       //  => SC.media_select,
  Unknown : 204,       //  => SC.www,
  Unknown : 205,       //  => SC.mail,
  Unknown : 206,       //  => SC.calculator,
  Unknown : 207,       //  => SC.computer,
  Unknown : 208,       //  => SC.ac_search,
  Unknown : 209,       //  => SC.ac_home,
  Unknown : 210,       //  => SC.ac_back,
  Unknown : 211,       //  => SC.ac_forward,
  Unknown : 212,       //  => SC.ac_stop,
  Unknown : 213,       //  => SC.ac_refresh,
  Unknown : 214,       //  => SC.ac_bookmarks,
  Unknown : 215,       //  => SC.brightness_down,
  Unknown : 216,       //  => SC.brightness_up,
  Unknown : 217,       //  => SC.displayswitch,
  Unknown : 218,       //  => SC.kbdillumtoggle,
  Unknown : 219,       //  => SC.kbdillumdown,
  Unknown : 220,       //  => SC.kbdillumup,
  Unknown : 221,       //  => SC.eject,
  Unknown : 222,       //  => SC.sleep,
  Unknown : 223,       //  => SC.app1,
  Unknown : 224,       // => SC.app2,
}

function
translateKeyEventToScancode(ev) {
  const sc = keyCodeToScancodeMap[ev.code];
  if (sc !== undefined) {
    return sc
  }
  return null // no scancode mapping found
}

function
createInputModule(canvas_element, getInstance, stop_fn) {
  // we don't want to have the default context menu on our canvas.
  // this event handler will prevent the default menu from opening:
  canvas_element.addEventListener('contextmenu', (ev) => ev.preventDefault())

  // add pass through of the mousedown, mouseup and mousemove event into zig:

  canvas_element.addEventListener('mousedown', (ev) => {
    let inst = getInstance()
    if (inst !== undefined) {
      inst.exports.app_input_sendMouseDown(ev.clientX, ev.clientY, ev.button)
    }
  })

  canvas_element.addEventListener('mouseup', (ev) => {
    // ev.button: 0=>left, 1=>middle, 2=>right
    let inst = getInstance()
    if (inst !== undefined) {
      inst.exports.app_input_sendMouseUp(ev.clientX, ev.clientY, ev.button)
    }
  })

  canvas_element.addEventListener('mousemove', (ev) => {
    let inst = getInstance()
    if (inst !== undefined) {
      inst.exports.app_input_sendMouseMotion(ev.clientX, ev.clientY)
    }
  })

  // process keyboard input
  canvas_element.addEventListener('keydown', (ev) => {
    let inst = getInstance()
    if (inst === undefined) {
      return
    }

    if (ev.repeat == false) {
      let sc = translateKeyEventToScancode(ev)
      if (sc !== null) {
        inst.exports.app_input_sendKeyDown(sc)
      }
      else {
        console.log('untranslated key code:', ev.code, ev)
      }
    }
  })

  canvas_element.addEventListener('keypress', (ev) => {
    let inst = getInstance()
    if (inst === undefined) {
      return
    }

    if (ev.isComposing || ev.keyCode === 229) {
      // this is a pure key-down event
      return
    }

    if (ev.charCode != 0) {
      inst.exports.app_input_sendTextInput(
          ev.charCode,
          ev.shiftKey,
          ev.altKey,
          ev.ctrlKey,
          ev.metaKey,
      )
    }
  })

  canvas_element.addEventListener('keyup', (ev) => {
    let inst = getInstance()
    if (inst === undefined) {
      return
    }

    if (ev.repeat == false) {
      let sc = translateKeyEventToScancode(ev)
      if (sc !== null) {
        inst.exports.app_input_sendKeyUp(sc)
      }
      else {
        console.log('untranslated key code:', ev.code, ev)
      }
    }
  })
}

function
createWebGlModule(canvas_element, getInstance, stop_fn) {
  const getMemory = () => getInstance().exports.memory

  const readCharStr = (ptr, len) =>
      utf8decoder.decode(new Uint8Array(getMemory().buffer, ptr, len))

  const writeCharStr = (ptr, len, lenRetPtr, text) => {
    const message = utf8encoder.encode(text)
    const zigbytes = new Uint8Array(getMemory().buffer, ptr, len)
    let zigidx = 0
    for (const b of message) {
      if (zigidx >= len - 1) {
        break;
      }
      zigbytes[zigidx] = b
      zigidx += 1
    }
    zigbytes[zigidx] = 0
    if (lenRetPtr !== 0) {
      new Uint32Array(getMemory().buffer, lenRetPtr, 1)[0] = zigidx
    }
  }

  const gl = canvas_element.getContext('webgl2', {
    antialias : false,
    preserveDrawingBuffer : true,
  })

  if (!gl) {
    throw new Error('The browser does not support WebGL')
  }

  // Start resources arrays with a null value to ensure the id 0 is never returned
  const glShaders = [ null ];
  const glPrograms = [ null ];
  const glBuffers = [ null ];
  const glVertexArrays = [ null ];
  const glTextures = [ null ];
  const glFramebuffers = [ null ];
  const glUniformLocations = [ null ]

      return {
    meta_getScreenW() {
      return gl.drawingBufferWidth; // canvas_element.clientWidth; //
    }
    ,
        meta_getScreenH() {
      return gl.drawingBufferHeight; // canvas_element.clientHeight; //
    }
    ,

        // GL stuff

        // Documentation
        // WebGL:         https://developer.mozilla.org/en-US/docs/Web/API/WebGLRenderingContext/lineWidth
        // OpenGL ES 2.0: https://www.khronos.org/registry/OpenGL-Refpages/es2.0/

        activeTexture(target) {
      gl.activeTexture(target)
    }
    ,
        attachShader(program, shader) {
      gl.attachShader(glPrograms[program], glShaders[shader])
    }
    ,
        bindBuffer(type, buffer_id) {
      gl.bindBuffer(type, glBuffers[buffer_id])
    }
    ,
        bindVertexArray(vertex_array_id) {
      gl.bindVertexArray(glVertexArrays[vertex_array_id])
    }
    ,
        bindFramebuffer(target, framebuffer) {
      gl.bindFramebuffer(target, glFramebuffers[framebuffer])
    }
    ,
        bindTexture(target, texture_id) {
      gl.bindTexture(target, glTextures[texture_id])
    }
    ,
        blendFunc(x, y) {
      gl.blendFunc(x, y)
    }
    ,
        blendEquation(mode) {
      gl.blendEquation(mode)
    }
    ,
        bufferData(type, count, data_ptr, draw_type) {
      const bytes = new Uint8Array(getMemory().buffer, data_ptr, count)
      gl.bufferData(type, bytes, draw_type)
    }
    ,
        checkFramebufferStatus(target) {
      return gl.checkFramebufferStatus(target)
    }
    ,
        clear(mask) {
      gl.clear(mask)
    }
    ,
        clearColor(r, g, b, a) {
      gl.clearColor(r, g, b, a)
    }
    ,
        compileShader(shader) {
      gl.compileShader(glShaders[shader])
    }
    ,
        getShaderiv(shader, pname, outptr) {
      new Int32Array(getMemory().buffer, outptr, 1)[0] = gl.getShaderParameter(
          glShaders[shader],
          pname,
      )
    }
    ,
        createBuffer() {
      glBuffers.push(gl.createBuffer())
      return glBuffers.length - 1
    }
    ,
        genBuffers(amount, ptr) {
      let out = new Uint32Array(getMemory().buffer, ptr, amount)
      for (let i = 0; i < amount; i += 1) {
        out[i] = glBuffers.length
        glBuffers.push(gl.createBuffer())
      }
    }
    ,
        createFramebuffer() {
      glFramebuffers.push(gl.createFramebuffer())
      return glFramebuffers.length - 1
    }
    ,
        createProgram() {
      glPrograms.push(gl.createProgram())
      return glPrograms.length - 1
    }
    ,
        createShader(shader_type) {
      glShaders.push(gl.createShader(shader_type))
      return glShaders.length - 1
    }
    ,
        genTextures(amount, ptr) {
      let out = new Uint32Array(getMemory().buffer, ptr, amount)
      for (let i = 0; i < amount; i += 1) {
        out[i] = glTextures.length
        glTextures.push(gl.createTexture())
      }
    }
    ,
        deleteBuffers(amount, ids_ptr) {
      let ids = new Uint32Array(getMemory().buffer, ids_ptr, amount)
      for (let i = 0; i < amount; i += 1) {
        const id = ids[i]
        gl.deleteBuffer(glBuffers[id])
        glBuffers[id] = undefined
      }
    }
    ,
        deleteProgram(id) {
      gl.deleteProgram(glPrograms[id])
      glPrograms[id] = undefined
    }
    ,
        deleteShader(id) {
      gl.deleteShader(glShaders[id])
      glShaders[id] = undefined
    }
    ,
        deleteTexture(id) {
      gl.deleteTexture(glTextures[id])
      glTextures[id] = undefined
    }
    ,
        deleteVertexArrays(amount, ids_ptr) {
      let ids = new Uint32Array(getMemory().buffer, ids_ptr, amount)
      for (let i = 0; i < amount; i += 1) {
        const id = ids[i]
        gl.deleteVertexArray(glVertexArrays[id])
        glVertexArrays[id] = undefined
      }
    }
    ,
        depthFunc(x) {
      gl.depthFunc(x)
    }
    ,
        detachShader(program, shader) {
      gl.detachShader(glPrograms[program], glShaders[shader])
    }
    ,
        disable(cap) {
      gl.disable(cap)
    }
    ,
        genVertexArrays(amount, ptr) {
      let out = new Uint32Array(getMemory().buffer, ptr, amount)
      for (let i = 0; i < amount; i += 1) {
        out[i] = glVertexArrays.length
        glVertexArrays.push(gl.createVertexArray())
      }
    }
    ,
        drawArrays(type, offset, count) {
      gl.drawArrays(type, offset, count)
    }
    ,
        drawElements(mode, count, type, offset) {
      gl.drawElements(mode, count, type, offset)
    }
    ,
        enable(x) {
      gl.enable(x)
    }
    ,
        enableVertexAttribArray(x) {
      gl.enableVertexAttribArray(x)
    }
    ,
        bindAttribLocation(x) {
      gl.bindAttribLocation(x)
    }
    ,
        framebufferTexture2D(target, attachment, textarget, texture, level) {
      gl.framebufferTexture2D(
          target,
          attachment,
          textarget,
          glTextures[texture],
          level,
      )
    }
    ,
        frontFace(mode) {
      gl.frontFace(mode)
    }
    ,
        cullFace(face) {
      gl.cullFace(face)
    }
    ,
        getAttribLocation_(program_id, name_ptr, name_len) {
      const name = readCharStr(name_ptr, name_len)
      return gl.getAttribLocation(glPrograms[program_id], name)
    }
    ,
        getError() {
      return gl.getError()
    }
    ,
        getShaderInfoLog(shader, maxLength, length, infoLog) {
      writeCharStr(
          infoLog,
          maxLength,
          length,
          gl.getShaderInfoLog(glShaders[shader]),
      )
    }
    ,
        getUniformLocation_(program_id, name_ptr, name_len) {
      const name = readCharStr(name_ptr, name_len)
      glUniformLocations.push(
          gl.getUniformLocation(glPrograms[program_id], name),
      )
      return glUniformLocations.length - 1
    }
    ,
        linkProgram(program) {
      gl.linkProgram(glPrograms[program])
    }
    ,
        getProgramiv(program, pname, outptr) {
      new Int32Array(getMemory().buffer, outptr, 1)[0] = gl.getProgramParameter(
          glPrograms[program],
          pname,
      )
    }
    ,
        getProgramInfoLog(program, maxLength, length, infoLog) {
      writeCharStr(
          infoLog,
          maxLength,
          length,
          gl.getProgramInfoLog(glPrograms[program]),
      )
    }
    ,
        pixelStorei(pname, param) {
      gl.pixelStorei(pname, param)
    }
    ,
        shaderSource(shader, count, string_ptrs, string_len_array) {
      let string = ''

      let pointers = new Uint32Array(getMemory().buffer, string_ptrs, count)
      let lengths = new Uint32Array(getMemory().buffer, string_len_array, count)
      for (let i = 0; i < count; i += 1) {
        // TODO: Check if webgl can accept an array of strings
        const string_to_append = readCharStr(pointers[i], lengths[i])
        string = string + string_to_append
      }

      gl.shaderSource(glShaders[shader], string)
    }
    ,
        texImage2D(
            target,
            level,
            internal_format,
            width,
            height,
            border,
            format,
            type,
            data_ptr,
        ) {
      const PIXEL_SIZES = {
        [gl.RGBA] : 4,
      };
      const pixel_size = PIXEL_SIZES[format]

          // Need to find out the pixel size for more formats
          if (!format) throw new Error('Unimplemented pixel format')

      const data =
          data_ptr != 0
              ? new Uint8Array(
                    getMemory().buffer,
                    data_ptr,
                    width * height * pixel_size,
                    )
              : null

      gl.texImage2D(
          target,
          level,
          internal_format,
          width,
          height,
          border,
          format,
          type,
          data,
      )
    }
    ,
        texParameterf(target, pname, param) {
      gl.texParameterf(target, pname, param)
    }
    ,
        texParameteri(target, pname, param) {
      gl.texParameteri(target, pname, param)
    }
    ,
        uniform1f(location_id, x) {
      gl.uniform1f(glUniformLocations[location_id], x)
    }
    ,
        uniform1i(location_id, x) {
      gl.uniform1i(glUniformLocations[location_id], x)
    }
    ,
        uniform2i(location_id, x, y) {
      gl.uniform2i(glUniformLocations[location_id], x, y)
    }
    ,
        uniform4f(location_id, x, y, z, w) {
      gl.uniform4f(glUniformLocations[location_id], x, y, z, w)
    }
    ,
        uniformMatrix4fv(location_id, data_len, transpose, data_ptr) {
      const floats = new Float32Array(
          getMemory().buffer,
          data_ptr,
          data_len * 16,
      )
      gl.uniformMatrix4fv(glUniformLocations[location_id], transpose, floats)
    }
    ,
        useProgram(program_id) {
      gl.useProgram(glPrograms[program_id])
    }
    ,
        vertexAttribPointer(
            attrib_location,
            size,
            type,
            normalize,
            stride,
            offset,
        ) {
      gl.vertexAttribPointer(
          attrib_location,
          size,
          type,
          normalize,
          stride,
          offset,
      )
    }
    ,
        viewport(x, y, width, height) {
      gl.viewport(x, y, width, height)
    }
    ,
        scissor(x, y, width, height) {
      gl.scissor(x, y, width, height)
    }
    ,
        getStringJs(name) {
      let inst = getInstance()
      let str = gl.getParameter(name)

      const encoded = utf8encoder.encode(str)
      let ptr = inst.exports.getString_alloc(encoded.length)

      const zigbytes = new Uint8Array(getMemory().buffer, ptr, encoded.length)
      let zigidx = 0
      for (const b of encoded) {
        zigbytes[zigidx] = b
        zigidx += 1
      }
    }
    ,
        // unimplemented opengl:
        hint() {
      // extern fn hint (_target: GLenum, _mode: GLenum) void;
      throw 'hint not implemented yet'
    }
    ,
        bindAttribLocationJs(pgm, idx, name_ptr, name_len) {
      // extern fn bindAttribLocation (_program: GLuint, _index: GLuint, _name: [*c]const GLchar) void;
      gl.bindAttribLocation(
          glPrograms[pgm],
          idx,
          readCharStr(name_ptr, name_len),
      )
    }
    ,
        bindRenderbuffer(target, rbuf) {
      // extern fn bindRenderbuffer (_target: GLenum, _renderbuffer: GLuint) void;
      gl.bindRenderbuffer(target, rbuf)
    }
    ,
        blendColor() {
      // extern fn blendColor (_red: GLfloat, _green: GLfloat, _blue: GLfloat, _alpha: GLfloat) void;
      throw 'blendColor not implemented yet'
    }
    ,
        blendEquationSeparate() {
      // extern fn blendEquationSeparate (_modeRGB: GLenum, _modeAlpha: GLenum) void;
      throw 'blendEquationSeparate not implemented yet'
    }
    ,
        blendFuncSeparate() {
      // extern fn blendFuncSeparate (_sfactorRGB: GLenum, _dfactorRGB: GLenum, _sfactorAlpha: GLenum, _dfactorAlpha: GLenum) void;
      throw 'blendFuncSeparate not implemented yet'
    }
    ,
        bufferSubData() {
      // extern fn bufferSubData (_target: GLenum, _offset: GLintptr, _size: GLsizeiptr, _data: ?*const c_void) void;
      throw 'bufferSubData not implemented yet'
    }
    ,
        clearDepthf(depth) {
      // extern fn clearDepthf (_d: GLfloat) void;
      gl.clearDepth(depth)
    }
    ,
        clearStencil(mask) {
      // extern fn clearStencil (_s: GLint) void;
      gl.clearStencil(mask)
    }
    ,
        colorMask(r, g, b, a) {
      // extern fn colorMask (_red: GLboolean, _green: GLboolean, _blue: GLboolean, _alpha: GLboolean) void;
      gl.colorMask(r, g, b, a)
    }
    ,
        compressedTexImage2D() {
      // extern fn compressedTexImage2D (_target: GLenum, _level: GLint, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _border: GLint, _imageSize: GLsizei, _data: ?*const c_void) void;
      throw 'compressedTexImage2D not implemented yet'
    }
    ,
        compressedTexSubImage2D() {
      // extern fn compressedTexSubImage2D (_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _imageSize: GLsizei, _data: ?*const c_void) void;
      throw 'compressedTexSubImage2D not implemented yet'
    }
    ,
        copyTexImage2D() {
      // extern fn copyTexImage2D (_target: GLenum, _level: GLint, _internalformat: GLenum, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _border: GLint) void;
      throw 'copyTexImage2D not implemented yet'
    }
    ,
        copyTexSubImage2D() {
      // extern fn copyTexSubImage2D (_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) void;
      throw 'copyTexSubImage2D not implemented yet'
    }
    ,
        deleteFramebuffers() {
      // extern fn deleteFramebuffers (_n: GLsizei, _framebuffers: [*c]const GLuint) void;
      throw 'deleteFramebuffers not implemented yet'
    }
    ,
        deleteRenderbuffers() {
      // extern fn deleteRenderbuffers (_n: GLsizei, _renderbuffers: [*c]const GLuint) void;
      throw 'deleteRenderbuffers not implemented yet'
    }
    ,
        deleteTextures() {
      // extern fn deleteTextures (_n: GLsizei, _textures: [*c]const GLuint) void;
      throw 'deleteTextures not implemented yet'
    }
    ,
        depthMask() {
      // extern fn depthMask (_flag: GLboolean) void;
      throw 'depthMask not implemented yet'
    }
    ,
        depthRangef() {
      // extern fn depthRangef (_n: GLfloat, _f: GLfloat) void;
      throw 'depthRangef not implemented yet'
    }
    ,
        disableVertexAttribArray(id) {
      // extern fn disableVertexAttribArray (_index: GLuint) void;
      gl.disableVertexAttribArray(id)
    }
    ,
        finish() {
      // extern fn finish () void;
      gl.finish()
    }
    ,
        flush() {
      // extern fn flush () void;
      gl.flush()
    }
    ,
        framebufferRenderbuffer() {
      // extern fn framebufferRenderbuffer (_target: GLenum, _attachment: GLenum, _renderbuffertarget: GLenum, _renderbuffer: GLuint) void;
      throw 'framebufferRenderbuffer not implemented yet'
    }
    ,
        generateMipmap(tex) {
      // extern fn generateMipmap (_target: GLenum) void;
      gl.generateMipmap(tex)
    }
    ,
        genFramebuffers() {
      // extern fn genFramebuffers (_n: GLsizei, _framebuffers: [*c]GLuint) void;
      throw 'genFramebuffers not implemented yet'
    }
    ,
        genRenderbuffers() {
      // extern fn genRenderbuffers (_n: GLsizei, _renderbuffers: [*c]GLuint) void;
      throw 'genRenderbuffers not implemented yet'
    }
    ,
        getActiveAttrib() {
      // extern fn getActiveAttrib (_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) void;
      throw 'getActiveAttrib not implemented yet'
    }
    ,
        getActiveUniform() {
      // extern fn getActiveUniform (_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) void;
      throw 'getActiveUniform not implemented yet'
    }
    ,
        getAttachedShaders() {
      // extern fn getAttachedShaders (_program: GLuint, _maxCount: GLsizei, _count: [*c]GLsizei, _shaders: [*c]GLuint) void;
      throw 'getAttachedShaders not implemented yet'
    }
    ,
        getBooleanv() {
      // extern fn getBooleanv (_pname: GLenum, _data: [*c]GLboolean) void;
      throw 'getBooleanv not implemented yet'
    }
    ,
        getBufferParameteriv() {
      // extern fn getBufferParameteriv (_target: GLenum, _pname: GLenum, _params: [*c]GLint) void;
      throw 'getBufferParameteriv not implemented yet'
    }
    ,
        getFloatv() {
      // extern fn getFloatv (_pname: GLenum, _data: [*c]GLfloat) void;
      throw 'getFloatv not implemented yet'
    }
    ,
        getFramebufferAttachmentParameteriv() {
      // extern fn getFramebufferAttachmentParameteriv (_target: GLenum, _attachment: GLenum, _pname: GLenum, _params: [*c]GLint) void;
      throw 'getFramebufferAttachmentParameteriv not implemented yet'
    }
    ,
        getIntegerv() {
      // extern fn getIntegerv (_pname: GLenum, _data: [*c]GLint) void;
      throw 'getIntegerv not implemented yet'
    }
    ,
        getRenderbufferParameteriv() {
      // extern fn getRenderbufferParameteriv (_target: GLenum, _pname: GLenum, _params: [*c]GLint) void;
      throw 'getRenderbufferParameteriv not implemented yet'
    }
    ,
        getShaderPrecisionFormat() {
      // extern fn getShaderPrecisionFormat (_shadertype: GLenum, _precisiontype: GLenum, _range: [*c]GLint, _precision: [*c]GLint) void;
      throw 'getShaderPrecisionFormat not implemented yet'
    }
    ,
        getShaderSource() {
      // extern fn getShaderSource (_shader: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _source: [*c]GLchar) void;
      throw 'getShaderSource not implemented yet'
    }
    ,
        getTexParameterfv() {
      // extern fn getTexParameterfv (_target: GLenum, _pname: GLenum, _params: [*c]GLfloat) void;
      throw 'getTexParameterfv not implemented yet'
    }
    ,
        getTexParameteriv() {
      // extern fn getTexParameteriv (_target: GLenum, _pname: GLenum, _params: [*c]GLint) void;
      throw 'getTexParameteriv not implemented yet'
    }
    ,
        getUniformfv() {
      // extern fn getUniformfv (_program: GLuint, _location: GLint, _params: [*c]GLfloat) void;
      throw 'getUniformfv not implemented yet'
    }
    ,
        getUniformiv() {
      // extern fn getUniformiv (_program: GLuint, _location: GLint, _params: [*c]GLint) void;
      throw 'getUniformiv not implemented yet'
    }
    ,
        getVertexAttribfv() {
      // extern fn getVertexAttribfv (_index: GLuint, _pname: GLenum, _params: [*c]GLfloat) void;
      throw 'getVertexAttribfv not implemented yet'
    }
    ,
        getVertexAttribiv() {
      // extern fn getVertexAttribiv (_index: GLuint, _pname: GLenum, _params: [*c]GLint) void;
      throw 'getVertexAttribiv not implemented yet'
    }
    ,
        getVertexAttribPointerv() {
      // extern fn getVertexAttribPointerv (_index: GLuint, _pname: GLenum, _pointer: ?*?*c_void) void;
      throw 'getVertexAttribPointerv not implemented yet'
    }
    ,
        isBuffer() {
      // extern fn isBuffer (_buffer: GLuint) GLboolean;
      throw 'isBuffer not implemented yet'
    }
    ,
        isEnabled(cap) {
      // extern fn isEnabled (_cap: GLenum) GLboolean;
      return gl.isEnabled(cap)
    }
    ,
        isFramebuffer(fb) {
      // extern fn isFramebuffer (_framebuffer: GLuint) GLboolean;
      return gl.isFramebuffer(fb)
    }
    ,
        isProgram(pgm) {
      // extern fn isProgram (_program: GLuint) GLboolean;
      return gl.isProgram(glPrograms[pgm])
    }
    ,
        isRenderbuffer(rb) {
      // extern fn isRenderbuffer (_renderbuffer: GLuint) GLboolean;
      return gl.isRenderbuffer(rb)
    }
    ,
        isShader(shader) {
      // extern fn isShader (_shader: GLuint) GLboolean;
      return gl.isShader(glShaders[shader])
    }
    ,
        isTexture(tex) {
      // extern fn isTexture (_texture: GLuint) GLboolean;
      return gl.isTexture(glTextures[tex])
    }
    ,
        lineWidth(width) {
      // extern fn lineWidth (_width: GLfloat) void;
      gl.lineWidth(width)
    }
    ,
        polygonOffset() {
      // extern fn polygonOffset (_factor: GLfloat, _units: GLfloat) void;
      throw 'polygonOffset not implemented yet'
    }
    ,
        readPixels() {
      // extern fn readPixels (_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*c_void) void;
      throw 'readPixels not implemented yet'
    }
    ,
        releaseShaderCompiler() {
      // extern fn releaseShaderCompiler () void;
      throw 'releaseShaderCompiler not implemented yet'
    }
    ,
        renderbufferStorage() {
      // extern fn renderbufferStorage (_target: GLenum, _internalformat: GLenum, _width: GLsizei, _height: GLsizei) void;
      throw 'renderbufferStorage not implemented yet'
    }
    ,
        sampleCoverage() {
      // extern fn sampleCoverage (_value: GLfloat, _invert: GLboolean) void;
      throw 'sampleCoverage not implemented yet'
    }
    ,
        shaderBinary() {
      // extern fn shaderBinary (_count: GLsizei, _shaders: [*c]const GLuint, _binaryFormat: GLenum, _binary: ?*const c_void, _length: GLsizei) void;
      throw 'shaderBinary not implemented yet'
    }
    ,
        stencilFunc() {
      // extern fn stencilFunc (_func: GLenum, _ref: GLint, _mask: GLuint) void;
      throw 'stencilFunc not implemented yet'
    }
    ,
        stencilFuncSeparate() {
      // extern fn stencilFuncSeparate (_face: GLenum, _func: GLenum, _ref: GLint, _mask: GLuint) void;
      throw 'stencilFuncSeparate not implemented yet'
    }
    ,
        stencilMask() {
      // extern fn stencilMask (_mask: GLuint) void;
      throw 'stencilMask not implemented yet'
    }
    ,
        stencilMaskSeparate() {
      // extern fn stencilMaskSeparate (_face: GLenum, _mask: GLuint) void;
      throw 'stencilMaskSeparate not implemented yet'
    }
    ,
        stencilOp() {
      // extern fn stencilOp (_fail: GLenum, _zfail: GLenum, _zpass: GLenum) void;
      throw 'stencilOp not implemented yet'
    }
    ,
        stencilOpSeparate() {
      // extern fn stencilOpSeparate (_face: GLenum, _sfail: GLenum, _dpfail: GLenum, _dppass: GLenum) void;
      throw 'stencilOpSeparate not implemented yet'
    }
    ,
        texParameterfv() {
      // extern fn texParameterfv (_target: GLenum, _pname: GLenum, _params: [*c]const GLfloat) void;
      throw 'texParameterfv not implemented yet'
    }
    ,
        texParameteriv() {
      // extern fn texParameteriv (_target: GLenum, _pname: GLenum, _params: [*c]const GLint) void;
      throw 'texParameteriv not implemented yet'
    }
    ,
        texSubImage2D() {
      // extern fn texSubImage2D (_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*const c_void) void;
      throw 'texSubImage2D not implemented yet'
    }
    ,
        uniform1fv() {
      // extern fn uniform1fv (_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) void;
      throw 'uniform1fv not implemented yet'
    }
    ,
        uniform1iv() {
      // extern fn uniform1iv (_location: GLint, _count: GLsizei, _value: [*c]const GLint) void;
      throw 'uniform1iv not implemented yet'
    }
    ,
        uniform2f() {
      // extern fn uniform2f (_location: GLint, _v0: GLfloat, _v1: GLfloat) void;
      throw 'uniform2f not implemented yet'
    }
    ,
        uniform2fv() {
      // extern fn uniform2fv (_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) void;
      throw 'uniform2fv not implemented yet'
    }
    ,
        uniform2iv() {
      // extern fn uniform2iv (_location: GLint, _count: GLsizei, _value: [*c]const GLint) void;
      throw 'uniform2iv not implemented yet'
    }
    ,
        uniform3f() {
      // extern fn uniform3f (_location: GLint, _v0: GLfloat, _v1: GLfloat, _v2: GLfloat) void;
      throw 'uniform3f not implemented yet'
    }
    ,
        uniform3fv() {
      // extern fn uniform3fv (_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) void;
      throw 'uniform3fv not implemented yet'
    }
    ,
        uniform3i() {
      // extern fn uniform3i (_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint) void;
      throw 'uniform3i not implemented yet'
    }
    ,
        uniform3iv() {
      // extern fn uniform3iv (_location: GLint, _count: GLsizei, _value: [*c]const GLint) void;
      throw 'uniform3iv not implemented yet'
    }
    ,
        uniform4fv() {
      // extern fn uniform4fv (_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) void;
      throw 'uniform4fv not implemented yet'
    }
    ,
        uniform4i() {
      // extern fn uniform4i (_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint, _v3: GLint) void;
      throw 'uniform4i not implemented yet'
    }
    ,
        uniform4iv() {
      // extern fn uniform4iv (_location: GLint, _count: GLsizei, _value: [*c]const GLint) void;
      throw 'uniform4iv not implemented yet'
    }
    ,
        uniformMatrix2fv() {
      // extern fn uniformMatrix2fv (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) void;
      throw 'uniformMatrix2fv not implemented yet'
    }
    ,
        uniformMatrix3fv() {
      // extern fn uniformMatrix3fv (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) void;
      throw 'uniformMatrix3fv not implemented yet'
    }
    ,
        validateProgram() {
      // extern fn validateProgram (_program: GLuint) void;
      throw 'validateProgram not implemented yet'
    }
    ,
        vertexAttrib1f() {
      // extern fn vertexAttrib1f (_index: GLuint, _x: GLfloat) void;
      throw 'vertexAttrib1f not implemented yet'
    }
    ,
        vertexAttrib1fv() {
      // extern fn vertexAttrib1fv (_index: GLuint, _v: [*c]const GLfloat) void;
      throw 'vertexAttrib1fv not implemented yet'
    }
    ,
        vertexAttrib2f() {
      // extern fn vertexAttrib2f (_index: GLuint, _x: GLfloat, _y: GLfloat) void;
      throw 'vertexAttrib2f not implemented yet'
    }
    ,
        vertexAttrib2fv() {
      // extern fn vertexAttrib2fv (_index: GLuint, _v: [*c]const GLfloat) void;
      throw 'vertexAttrib2fv not implemented yet'
    }
    ,
        vertexAttrib3f() {
      // extern fn vertexAttrib3f (_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat) void;
      throw 'vertexAttrib3f not implemented yet'
    }
    ,
        vertexAttrib3fv() {
      // extern fn vertexAttrib3fv (_index: GLuint, _v: [*c]const GLfloat) void;
      throw 'vertexAttrib3fv not implemented yet'
    }
    ,
        vertexAttrib4f() {
      // extern fn vertexAttrib4f (_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat, _w: GLfloat) void;
      throw 'vertexAttrib4f not implemented yet'
    }
    ,
        vertexAttrib4fv() {
      // extern fn vertexAttrib4fv (_index: GLuint, _v: [*c]const GLfloat) void;
      throw 'vertexAttrib4fv not implemented yet'
    }
    ,
  }
}

export { createWebGlModule, createPlatformEnvironment, createInputModule, createWebsocketModule }
