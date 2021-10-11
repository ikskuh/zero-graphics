const utf8decoder = new TextDecoder()

function createPlatformEnvironment(getInstance) {
  const getMemory = () => getInstance().exports.memory

  let log_string = ''
  return {
    wasm_quit() {
      throw 'application exit'
    },
    wasm_panic: (ptr, len) => {
      let msg = utf8decoder.decode(new Uint8Array(getMemory().buffer, ptr, len))
      throw Error(msg)
    },
    wasm_log_write: (ptr, len) => {
      log_string += utf8decoder.decode(
        new Uint8Array(getMemory().buffer, ptr, len),
      )
    },
    wasm_log_flush: () => {
      console.log(log_string)
      log_string = ''
    },

    now_f64() {
      return Date.now()
    },
  }
}

function createInputModule(canvas_element, getInstance, stop_fn) {
  console.log('hi')

  // we don't want to have the default context menu on our canvas.
  // this event handler will prevent the default menu from opening:
  canvas_element.addEventListener('contextmenu', (ev) => ev.preventDefault())

  // add pass through of the mousedown, mouseup and mousemove event into zig:

  canvas_element.addEventListener('mousedown', (ev) => {
    let inst = getInstance()
    inst.exports.app_input_sendMouseDown(ev.clientX, ev.clientY, ev.button)
  })

  canvas_element.addEventListener('mouseup', (ev) => {
    // ev.button: 0=>left, 1=>middle, 2=>right
    let inst = getInstance()
    inst.exports.app_input_sendMouseUp(ev.clientX, ev.clientY, ev.button)
  })

  canvas_element.addEventListener('mousemove', (ev) => {
    let inst = getInstance()
    inst.exports.app_input_sendMouseMotion(ev.clientX, ev.clientY)
  })
}

function createWebGlModule(canvas_element, getInstance, stop_fn) {
  const getMemory = () => getInstance().exports.memory

  const readCharStr = (ptr, len) =>
    utf8decoder.decode(new Uint8Array(getMemory().buffer, ptr, len))

  const writeCharStr = (ptr, len, lenRetPtr, text) => {
    const encoder = new TextEncoder()
    const message = encoder.encode(text)
    const zigbytes = new Uint8Array(getMemory().buffer, ptr, len)
    let zigidx = 0
    for (const b of message) {
      if (zigidx >= len - 1) break
      zigbytes[zigidx] = b
      zigidx += 1
    }
    zigbytes[zigidx] = 0
    if (lenRetPtr !== 0) {
      new Uint32Array(getMemory().buffer, lenRetPtr, 1)[0] = zigidx
    }
  }

  const gl = canvas_element.getContext('webgl2', {
    antialias: false,
    preserveDrawingBuffer: true,
  })

  if (!gl) {
    throw new Error('The browser does not support WebGL')
  }

  // Start resources arrays with a null value to ensure the id 0 is never returned
  const glShaders = [null]
  const glPrograms = [null]
  const glBuffers = [null]
  const glVertexArrays = [null]
  const glTextures = [null]
  const glFramebuffers = [null]
  const glUniformLocations = [null]

  return {
    meta_getScreenW() {
      return gl.drawingBufferWidth // canvas_element.clientWidth; //
    },
    meta_getScreenH() {
      return gl.drawingBufferHeight // canvas_element.clientHeight; //
    },

    // GL stuff

    // Documentation
    // WebGL:         https://developer.mozilla.org/en-US/docs/Web/API/WebGLRenderingContext/lineWidth
    // OpenGL ES 2.0: https://www.khronos.org/registry/OpenGL-Refpages/es2.0/

    activeTexture(target) {
      gl.activeTexture(target)
    },
    attachShader(program, shader) {
      gl.attachShader(glPrograms[program], glShaders[shader])
    },
    bindBuffer(type, buffer_id) {
      gl.bindBuffer(type, glBuffers[buffer_id])
    },
    bindVertexArray(vertex_array_id) {
      gl.bindVertexArray(glVertexArrays[vertex_array_id])
    },
    bindFramebuffer(target, framebuffer) {
      gl.bindFramebuffer(target, glFramebuffers[framebuffer])
    },
    bindTexture(target, texture_id) {
      gl.bindTexture(target, glTextures[texture_id])
    },
    blendFunc(x, y) {
      gl.blendFunc(x, y)
    },
    blendEquation(mode) {
      gl.blendEquation(mode)
    },
    bufferData(type, count, data_ptr, draw_type) {
      const bytes = new Uint8Array(getMemory().buffer, data_ptr, count)
      gl.bufferData(type, bytes, draw_type)
    },
    checkFramebufferStatus(target) {
      return gl.checkFramebufferStatus(target)
    },
    clear(mask) {
      gl.clear(mask)
    },
    clearColor(r, g, b, a) {
      gl.clearColor(r, g, b, a)
    },
    compileShader(shader) {
      gl.compileShader(glShaders[shader])
    },
    getShaderiv(shader, pname, outptr) {
      new Int32Array(getMemory().buffer, outptr, 1)[0] = gl.getShaderParameter(
        glShaders[shader],
        pname,
      )
    },
    createBuffer() {
      glBuffers.push(gl.createBuffer())
      return glBuffers.length - 1
    },
    genBuffers(amount, ptr) {
      let out = new Uint32Array(getMemory().buffer, ptr, amount)
      for (let i = 0; i < amount; i += 1) {
        out[i] = glBuffers.length
        glBuffers.push(gl.createBuffer())
      }
    },
    createFramebuffer() {
      glFramebuffers.push(gl.createFramebuffer())
      return glFramebuffers.length - 1
    },
    createProgram() {
      glPrograms.push(gl.createProgram())
      return glPrograms.length - 1
    },
    createShader(shader_type) {
      glShaders.push(gl.createShader(shader_type))
      return glShaders.length - 1
    },
    genTextures(amount, ptr) {
      let out = new Uint32Array(getMemory().buffer, ptr, amount)
      for (let i = 0; i < amount; i += 1) {
        out[i] = glTextures.length
        glTextures.push(gl.createTexture())
      }
    },
    deleteBuffers(amount, ids_ptr) {
      let ids = new Uint32Array(getMemory().buffer, ids_ptr, amount)
      for (let i = 0; i < amount; i += 1) {
        const id = ids[i]
        gl.deleteBuffer(glBuffers[id])
        glBuffers[id] = undefined
      }
    },
    deleteProgram(id) {
      gl.deleteProgram(glPrograms[id])
      glPrograms[id] = undefined
    },
    deleteShader(id) {
      gl.deleteShader(glShaders[id])
      glShaders[id] = undefined
    },
    deleteTexture(id) {
      gl.deleteTexture(glTextures[id])
      glTextures[id] = undefined
    },
    deleteVertexArrays(amount, ids_ptr) {
      let ids = new Uint32Array(getMemory().buffer, ids_ptr, amount)
      for (let i = 0; i < amount; i += 1) {
        const id = ids[i]
        gl.deleteVertexArray(glVertexArrays[id])
        glVertexArrays[id] = undefined
      }
    },
    depthFunc(x) {
      gl.depthFunc(x)
    },
    detachShader(program, shader) {
      gl.detachShader(glPrograms[program], glShaders[shader])
    },
    disable(cap) {
      gl.disable(cap)
    },
    genVertexArrays(amount, ptr) {
      let out = new Uint32Array(getMemory().buffer, ptr, amount)
      for (let i = 0; i < amount; i += 1) {
        out[i] = glVertexArrays.length
        glVertexArrays.push(gl.createVertexArray())
      }
    },
    drawArrays(type, offset, count) {
      gl.drawArrays(type, offset, count)
    },
    drawElements(mode, count, type, offset) {
      gl.drawElements(mode, count, type, offset)
    },
    enable(x) {
      gl.enable(x)
    },
    enableVertexAttribArray(x) {
      gl.enableVertexAttribArray(x)
    },
    bindAttribLocation(x) {
      gl.bindAttribLocation(x)
    },
    framebufferTexture2D(target, attachment, textarget, texture, level) {
      gl.framebufferTexture2D(
        target,
        attachment,
        textarget,
        glTextures[texture],
        level,
      )
    },
    frontFace(mode) {
      gl.frontFace(mode)
    },
    cullFace(face) {
      gl.cullFace(face)
    },
    getAttribLocation_(program_id, name_ptr, name_len) {
      const name = readCharStr(name_ptr, name_len)
      return gl.getAttribLocation(glPrograms[program_id], name)
    },
    getError() {
      return gl.getError()
    },
    getShaderInfoLog(shader, maxLength, length, infoLog) {
      writeCharStr(
        infoLog,
        maxLength,
        length,
        gl.getShaderInfoLog(glShaders[shader]),
      )
    },
    getUniformLocation_(program_id, name_ptr, name_len) {
      const name = readCharStr(name_ptr, name_len)
      glUniformLocations.push(
        gl.getUniformLocation(glPrograms[program_id], name),
      )
      return glUniformLocations.length - 1
    },
    linkProgram(program) {
      gl.linkProgram(glPrograms[program])
    },
    getProgramiv(program, pname, outptr) {
      new Int32Array(getMemory().buffer, outptr, 1)[0] = gl.getProgramParameter(
        glPrograms[program],
        pname,
      )
    },
    getProgramInfoLog(program, maxLength, length, infoLog) {
      writeCharStr(
        infoLog,
        maxLength,
        length,
        gl.getProgramInfoLog(glPrograms[program]),
      )
    },
    pixelStorei(pname, param) {
      gl.pixelStorei(pname, param)
    },
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
    },
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
        [gl.RGBA]: 4,
      }
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
    },
    texParameterf(target, pname, param) {
      gl.texParameterf(target, pname, param)
    },
    texParameteri(target, pname, param) {
      gl.texParameteri(target, pname, param)
    },
    uniform1f(location_id, x) {
      gl.uniform1f(glUniformLocations[location_id], x)
    },
    uniform1i(location_id, x) {
      gl.uniform1i(glUniformLocations[location_id], x)
    },
    uniform2i(location_id, x, y) {
      gl.uniform2i(glUniformLocations[location_id], x, y)
    },
    uniform4f(location_id, x, y, z, w) {
      gl.uniform4f(glUniformLocations[location_id], x, y, z, w)
    },
    uniformMatrix4fv(location_id, data_len, transpose, data_ptr) {
      const floats = new Float32Array(
        getMemory().buffer,
        data_ptr,
        data_len * 16,
      )
      gl.uniformMatrix4fv(glUniformLocations[location_id], transpose, floats)
    },
    useProgram(program_id) {
      gl.useProgram(glPrograms[program_id])
    },
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
    },
    viewport(x, y, width, height) {
      gl.viewport(x, y, width, height)
    },
    scissor(x, y, width, height) {
      gl.scissor(x, y, width, height)
    },
    getStringJs(name) {
      let inst = getInstance()
      let str = gl.getParameter(name)

      const encoder = new TextEncoder()
      const encoded = encoder.encode(str)
      let ptr = inst.exports.getString_alloc(encoded.length)

      const zigbytes = new Uint8Array(getMemory().buffer, ptr, encoded.length)
      let zigidx = 0
      for (const b of encoded) {
        zigbytes[zigidx] = b
        zigidx += 1
      }
    },
    // unimplemented opengl:
    hint() {
      // extern fn hint (_target: GLenum, _mode: GLenum) void;
      throw 'hint not implemented yet'
    },
    bindAttribLocationJs(pgm, idx, name_ptr, name_len) {
      // extern fn bindAttribLocation (_program: GLuint, _index: GLuint, _name: [*c]const GLchar) void;
      gl.bindAttribLocation(
        glPrograms[pgm],
        idx,
        readCharStr(name_ptr, name_len),
      )
    },
    bindRenderbuffer(target, rbuf) {
      // extern fn bindRenderbuffer (_target: GLenum, _renderbuffer: GLuint) void;
      gl.bindRenderbuffer(target, rbuf)
    },
    blendColor() {
      // extern fn blendColor (_red: GLfloat, _green: GLfloat, _blue: GLfloat, _alpha: GLfloat) void;
      throw 'blendColor not implemented yet'
    },
    blendEquationSeparate() {
      // extern fn blendEquationSeparate (_modeRGB: GLenum, _modeAlpha: GLenum) void;
      throw 'blendEquationSeparate not implemented yet'
    },
    blendFuncSeparate() {
      // extern fn blendFuncSeparate (_sfactorRGB: GLenum, _dfactorRGB: GLenum, _sfactorAlpha: GLenum, _dfactorAlpha: GLenum) void;
      throw 'blendFuncSeparate not implemented yet'
    },
    bufferSubData() {
      // extern fn bufferSubData (_target: GLenum, _offset: GLintptr, _size: GLsizeiptr, _data: ?*const c_void) void;
      throw 'bufferSubData not implemented yet'
    },
    clearDepthf(depth) {
      // extern fn clearDepthf (_d: GLfloat) void;
      gl.clearDepth(depth)
    },
    clearStencil(mask) {
      // extern fn clearStencil (_s: GLint) void;
      gl.clearStencil(mask)
    },
    colorMask(r, g, b, a) {
      // extern fn colorMask (_red: GLboolean, _green: GLboolean, _blue: GLboolean, _alpha: GLboolean) void;
      gl.colorMask(r, g, b, a)
    },
    compressedTexImage2D() {
      // extern fn compressedTexImage2D (_target: GLenum, _level: GLint, _internalformat: GLenum, _width: GLsizei, _height: GLsizei, _border: GLint, _imageSize: GLsizei, _data: ?*const c_void) void;
      throw 'compressedTexImage2D not implemented yet'
    },
    compressedTexSubImage2D() {
      // extern fn compressedTexSubImage2D (_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _imageSize: GLsizei, _data: ?*const c_void) void;
      throw 'compressedTexSubImage2D not implemented yet'
    },
    copyTexImage2D() {
      // extern fn copyTexImage2D (_target: GLenum, _level: GLint, _internalformat: GLenum, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _border: GLint) void;
      throw 'copyTexImage2D not implemented yet'
    },
    copyTexSubImage2D() {
      // extern fn copyTexSubImage2D (_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei) void;
      throw 'copyTexSubImage2D not implemented yet'
    },
    deleteFramebuffers() {
      // extern fn deleteFramebuffers (_n: GLsizei, _framebuffers: [*c]const GLuint) void;
      throw 'deleteFramebuffers not implemented yet'
    },
    deleteRenderbuffers() {
      // extern fn deleteRenderbuffers (_n: GLsizei, _renderbuffers: [*c]const GLuint) void;
      throw 'deleteRenderbuffers not implemented yet'
    },
    deleteTextures() {
      // extern fn deleteTextures (_n: GLsizei, _textures: [*c]const GLuint) void;
      throw 'deleteTextures not implemented yet'
    },
    depthMask() {
      // extern fn depthMask (_flag: GLboolean) void;
      throw 'depthMask not implemented yet'
    },
    depthRangef() {
      // extern fn depthRangef (_n: GLfloat, _f: GLfloat) void;
      throw 'depthRangef not implemented yet'
    },
    disableVertexAttribArray(id) {
      // extern fn disableVertexAttribArray (_index: GLuint) void;
      gl.disableVertexAttribArray(id)
    },
    finish() {
      // extern fn finish () void;
      gl.finish()
    },
    flush() {
      // extern fn flush () void;
      gl.flush()
    },
    framebufferRenderbuffer() {
      // extern fn framebufferRenderbuffer (_target: GLenum, _attachment: GLenum, _renderbuffertarget: GLenum, _renderbuffer: GLuint) void;
      throw 'framebufferRenderbuffer not implemented yet'
    },
    generateMipmap(tex) {
      // extern fn generateMipmap (_target: GLenum) void;
      gl.generateMipmap(tex)
    },
    genFramebuffers() {
      // extern fn genFramebuffers (_n: GLsizei, _framebuffers: [*c]GLuint) void;
      throw 'genFramebuffers not implemented yet'
    },
    genRenderbuffers() {
      // extern fn genRenderbuffers (_n: GLsizei, _renderbuffers: [*c]GLuint) void;
      throw 'genRenderbuffers not implemented yet'
    },
    getActiveAttrib() {
      // extern fn getActiveAttrib (_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) void;
      throw 'getActiveAttrib not implemented yet'
    },
    getActiveUniform() {
      // extern fn getActiveUniform (_program: GLuint, _index: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _size: [*c]GLint, _type: [*c]GLenum, _name: [*c]GLchar) void;
      throw 'getActiveUniform not implemented yet'
    },
    getAttachedShaders() {
      // extern fn getAttachedShaders (_program: GLuint, _maxCount: GLsizei, _count: [*c]GLsizei, _shaders: [*c]GLuint) void;
      throw 'getAttachedShaders not implemented yet'
    },
    getBooleanv() {
      // extern fn getBooleanv (_pname: GLenum, _data: [*c]GLboolean) void;
      throw 'getBooleanv not implemented yet'
    },
    getBufferParameteriv() {
      // extern fn getBufferParameteriv (_target: GLenum, _pname: GLenum, _params: [*c]GLint) void;
      throw 'getBufferParameteriv not implemented yet'
    },
    getFloatv() {
      // extern fn getFloatv (_pname: GLenum, _data: [*c]GLfloat) void;
      throw 'getFloatv not implemented yet'
    },
    getFramebufferAttachmentParameteriv() {
      // extern fn getFramebufferAttachmentParameteriv (_target: GLenum, _attachment: GLenum, _pname: GLenum, _params: [*c]GLint) void;
      throw 'getFramebufferAttachmentParameteriv not implemented yet'
    },
    getIntegerv() {
      // extern fn getIntegerv (_pname: GLenum, _data: [*c]GLint) void;
      throw 'getIntegerv not implemented yet'
    },
    getRenderbufferParameteriv() {
      // extern fn getRenderbufferParameteriv (_target: GLenum, _pname: GLenum, _params: [*c]GLint) void;
      throw 'getRenderbufferParameteriv not implemented yet'
    },
    getShaderPrecisionFormat() {
      // extern fn getShaderPrecisionFormat (_shadertype: GLenum, _precisiontype: GLenum, _range: [*c]GLint, _precision: [*c]GLint) void;
      throw 'getShaderPrecisionFormat not implemented yet'
    },
    getShaderSource() {
      // extern fn getShaderSource (_shader: GLuint, _bufSize: GLsizei, _length: [*c]GLsizei, _source: [*c]GLchar) void;
      throw 'getShaderSource not implemented yet'
    },
    getTexParameterfv() {
      // extern fn getTexParameterfv (_target: GLenum, _pname: GLenum, _params: [*c]GLfloat) void;
      throw 'getTexParameterfv not implemented yet'
    },
    getTexParameteriv() {
      // extern fn getTexParameteriv (_target: GLenum, _pname: GLenum, _params: [*c]GLint) void;
      throw 'getTexParameteriv not implemented yet'
    },
    getUniformfv() {
      // extern fn getUniformfv (_program: GLuint, _location: GLint, _params: [*c]GLfloat) void;
      throw 'getUniformfv not implemented yet'
    },
    getUniformiv() {
      // extern fn getUniformiv (_program: GLuint, _location: GLint, _params: [*c]GLint) void;
      throw 'getUniformiv not implemented yet'
    },
    getVertexAttribfv() {
      // extern fn getVertexAttribfv (_index: GLuint, _pname: GLenum, _params: [*c]GLfloat) void;
      throw 'getVertexAttribfv not implemented yet'
    },
    getVertexAttribiv() {
      // extern fn getVertexAttribiv (_index: GLuint, _pname: GLenum, _params: [*c]GLint) void;
      throw 'getVertexAttribiv not implemented yet'
    },
    getVertexAttribPointerv() {
      // extern fn getVertexAttribPointerv (_index: GLuint, _pname: GLenum, _pointer: ?*?*c_void) void;
      throw 'getVertexAttribPointerv not implemented yet'
    },
    isBuffer() {
      // extern fn isBuffer (_buffer: GLuint) GLboolean;
      throw 'isBuffer not implemented yet'
    },
    isEnabled(cap) {
      // extern fn isEnabled (_cap: GLenum) GLboolean;
      return gl.isEnabled(cap)
    },
    isFramebuffer(fb) {
      // extern fn isFramebuffer (_framebuffer: GLuint) GLboolean;
      return gl.isFramebuffer(fb)
    },
    isProgram(pgm) {
      // extern fn isProgram (_program: GLuint) GLboolean;
      return gl.isProgram(glPrograms[pgm])
    },
    isRenderbuffer(rb) {
      // extern fn isRenderbuffer (_renderbuffer: GLuint) GLboolean;
      return gl.isRenderbuffer(rb)
    },
    isShader(shader) {
      // extern fn isShader (_shader: GLuint) GLboolean;
      return gl.isShader(glShaders[shader])
    },
    isTexture(tex) {
      // extern fn isTexture (_texture: GLuint) GLboolean;
      return gl.isTexture(glTextures[tex])
    },
    lineWidth(width) {
      // extern fn lineWidth (_width: GLfloat) void;
      gl.lineWidth(width)
    },
    polygonOffset() {
      // extern fn polygonOffset (_factor: GLfloat, _units: GLfloat) void;
      throw 'polygonOffset not implemented yet'
    },
    readPixels() {
      // extern fn readPixels (_x: GLint, _y: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*c_void) void;
      throw 'readPixels not implemented yet'
    },
    releaseShaderCompiler() {
      // extern fn releaseShaderCompiler () void;
      throw 'releaseShaderCompiler not implemented yet'
    },
    renderbufferStorage() {
      // extern fn renderbufferStorage (_target: GLenum, _internalformat: GLenum, _width: GLsizei, _height: GLsizei) void;
      throw 'renderbufferStorage not implemented yet'
    },
    sampleCoverage() {
      // extern fn sampleCoverage (_value: GLfloat, _invert: GLboolean) void;
      throw 'sampleCoverage not implemented yet'
    },
    shaderBinary() {
      // extern fn shaderBinary (_count: GLsizei, _shaders: [*c]const GLuint, _binaryFormat: GLenum, _binary: ?*const c_void, _length: GLsizei) void;
      throw 'shaderBinary not implemented yet'
    },
    stencilFunc() {
      // extern fn stencilFunc (_func: GLenum, _ref: GLint, _mask: GLuint) void;
      throw 'stencilFunc not implemented yet'
    },
    stencilFuncSeparate() {
      // extern fn stencilFuncSeparate (_face: GLenum, _func: GLenum, _ref: GLint, _mask: GLuint) void;
      throw 'stencilFuncSeparate not implemented yet'
    },
    stencilMask() {
      // extern fn stencilMask (_mask: GLuint) void;
      throw 'stencilMask not implemented yet'
    },
    stencilMaskSeparate() {
      // extern fn stencilMaskSeparate (_face: GLenum, _mask: GLuint) void;
      throw 'stencilMaskSeparate not implemented yet'
    },
    stencilOp() {
      // extern fn stencilOp (_fail: GLenum, _zfail: GLenum, _zpass: GLenum) void;
      throw 'stencilOp not implemented yet'
    },
    stencilOpSeparate() {
      // extern fn stencilOpSeparate (_face: GLenum, _sfail: GLenum, _dpfail: GLenum, _dppass: GLenum) void;
      throw 'stencilOpSeparate not implemented yet'
    },
    texParameterfv() {
      // extern fn texParameterfv (_target: GLenum, _pname: GLenum, _params: [*c]const GLfloat) void;
      throw 'texParameterfv not implemented yet'
    },
    texParameteriv() {
      // extern fn texParameteriv (_target: GLenum, _pname: GLenum, _params: [*c]const GLint) void;
      throw 'texParameteriv not implemented yet'
    },
    texSubImage2D() {
      // extern fn texSubImage2D (_target: GLenum, _level: GLint, _xoffset: GLint, _yoffset: GLint, _width: GLsizei, _height: GLsizei, _format: GLenum, _type: GLenum, _pixels: ?*const c_void) void;
      throw 'texSubImage2D not implemented yet'
    },
    uniform1fv() {
      // extern fn uniform1fv (_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) void;
      throw 'uniform1fv not implemented yet'
    },
    uniform1iv() {
      // extern fn uniform1iv (_location: GLint, _count: GLsizei, _value: [*c]const GLint) void;
      throw 'uniform1iv not implemented yet'
    },
    uniform2f() {
      // extern fn uniform2f (_location: GLint, _v0: GLfloat, _v1: GLfloat) void;
      throw 'uniform2f not implemented yet'
    },
    uniform2fv() {
      // extern fn uniform2fv (_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) void;
      throw 'uniform2fv not implemented yet'
    },
    uniform2iv() {
      // extern fn uniform2iv (_location: GLint, _count: GLsizei, _value: [*c]const GLint) void;
      throw 'uniform2iv not implemented yet'
    },
    uniform3f() {
      // extern fn uniform3f (_location: GLint, _v0: GLfloat, _v1: GLfloat, _v2: GLfloat) void;
      throw 'uniform3f not implemented yet'
    },
    uniform3fv() {
      // extern fn uniform3fv (_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) void;
      throw 'uniform3fv not implemented yet'
    },
    uniform3i() {
      // extern fn uniform3i (_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint) void;
      throw 'uniform3i not implemented yet'
    },
    uniform3iv() {
      // extern fn uniform3iv (_location: GLint, _count: GLsizei, _value: [*c]const GLint) void;
      throw 'uniform3iv not implemented yet'
    },
    uniform4fv() {
      // extern fn uniform4fv (_location: GLint, _count: GLsizei, _value: [*c]const GLfloat) void;
      throw 'uniform4fv not implemented yet'
    },
    uniform4i() {
      // extern fn uniform4i (_location: GLint, _v0: GLint, _v1: GLint, _v2: GLint, _v3: GLint) void;
      throw 'uniform4i not implemented yet'
    },
    uniform4iv() {
      // extern fn uniform4iv (_location: GLint, _count: GLsizei, _value: [*c]const GLint) void;
      throw 'uniform4iv not implemented yet'
    },
    uniformMatrix2fv() {
      // extern fn uniformMatrix2fv (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) void;
      throw 'uniformMatrix2fv not implemented yet'
    },
    uniformMatrix3fv() {
      // extern fn uniformMatrix3fv (_location: GLint, _count: GLsizei, _transpose: GLboolean, _value: [*c]const GLfloat) void;
      throw 'uniformMatrix3fv not implemented yet'
    },
    validateProgram() {
      // extern fn validateProgram (_program: GLuint) void;
      throw 'validateProgram not implemented yet'
    },
    vertexAttrib1f() {
      // extern fn vertexAttrib1f (_index: GLuint, _x: GLfloat) void;
      throw 'vertexAttrib1f not implemented yet'
    },
    vertexAttrib1fv() {
      // extern fn vertexAttrib1fv (_index: GLuint, _v: [*c]const GLfloat) void;
      throw 'vertexAttrib1fv not implemented yet'
    },
    vertexAttrib2f() {
      // extern fn vertexAttrib2f (_index: GLuint, _x: GLfloat, _y: GLfloat) void;
      throw 'vertexAttrib2f not implemented yet'
    },
    vertexAttrib2fv() {
      // extern fn vertexAttrib2fv (_index: GLuint, _v: [*c]const GLfloat) void;
      throw 'vertexAttrib2fv not implemented yet'
    },
    vertexAttrib3f() {
      // extern fn vertexAttrib3f (_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat) void;
      throw 'vertexAttrib3f not implemented yet'
    },
    vertexAttrib3fv() {
      // extern fn vertexAttrib3fv (_index: GLuint, _v: [*c]const GLfloat) void;
      throw 'vertexAttrib3fv not implemented yet'
    },
    vertexAttrib4f() {
      // extern fn vertexAttrib4f (_index: GLuint, _x: GLfloat, _y: GLfloat, _z: GLfloat, _w: GLfloat) void;
      throw 'vertexAttrib4f not implemented yet'
    },
    vertexAttrib4fv() {
      // extern fn vertexAttrib4fv (_index: GLuint, _v: [*c]const GLfloat) void;
      throw 'vertexAttrib4fv not implemented yet'
    },
  }
}

export { createWebGlModule, createPlatformEnvironment, createInputModule }
