// Platform ENV
export default function getPlatformEnv(canvas_element, getInstance, stop_fn) {
    const getMemory = () => getInstance().exports.memory;
    const utf8decoder = new TextDecoder();
    const readCharStr = (ptr, len) =>
        utf8decoder.decode(new Uint8Array(getMemory().buffer, ptr, len));
    const writeCharStr = (ptr, len, lenRetPtr, text) => {
        const encoder = new TextEncoder();
        const message = encoder.encode(text);
        const zigbytes = new Uint8Array(getMemory().buffer, ptr, len);
        let zigidx = 0;
        for (const b of message) {
            if (zigidx >= len - 1) break;
            zigbytes[zigidx] = b;
            zigidx += 1;
        }
        zigbytes[zigidx] = 0;
        if (lenRetPtr !== 0) {
            new Uint32Array(getMemory().buffer, lenRetPtr, 1)[0] = zigidx;
        }
    };

    const gl = canvas_element.getContext("webgl2", {
        antialias: false,
        preserveDrawingBuffer: true,
    });

    if (!gl) {
        throw new Error("The browser does not support WebGL");
    }

    // Start resources arrays with a null value to ensure the id 0 is never returned
    const glShaders = [null];
    const glPrograms = [null];
    const glBuffers = [null];
    const glVertexArrays = [null];
    const glTextures = [null];
    const glFramebuffers = [null];
    const glUniformLocations = [null];

    let log_string = "";

    return {
        wasm_quit() {
            stop_fn();
        },
        wasm_log_write: (ptr, len) => {
            log_string += utf8decoder.decode(
                new Uint8Array(getMemory().buffer, ptr, len)
            );
        },
        wasm_log_flush: () => {
            console.log(log_string);
            log_string = "";
        },

        wasm_getScreenW() {
            return gl.drawingBufferWidth; // canvas_element.clientWidth; //
        },
        wasm_getScreenH() {
            return gl.drawingBufferHeight; // canvas_element.clientHeight; // 
        },

        now_f64() {
            return Date.now();
        },

        // GL stuff
        activeTexture(target) {
            gl.activeTexture(target);
        },
        attachShader(program, shader) {
            gl.attachShader(glPrograms[program], glShaders[shader]);
        },
        bindBuffer(type, buffer_id) {
            gl.bindBuffer(type, glBuffers[buffer_id]);
        },
        bindVertexArray(vertex_array_id) {
            gl.bindVertexArray(glVertexArrays[vertex_array_id]);
        },
        bindFramebuffer(target, framebuffer) {
            gl.bindFramebuffer(target, glFramebuffers[framebuffer]);
        },
        bindTexture(target, texture_id) {
            gl.bindTexture(target, glTextures[texture_id]);
        },
        blendFunc(x, y) {
            gl.blendFunc(x, y);
        },
        blendEquation(mode) {
            gl.blendEquation(mode);
        },
        bufferData(type, count, data_ptr, draw_type) {
            const bytes = new Uint8Array(getMemory().buffer, data_ptr, count);
            gl.bufferData(type, bytes, draw_type);
        },
        checkFramebufferStatus(target) {
            return gl.checkFramebufferStatus(target);
        },
        clear(mask) {
            gl.clear(mask);
        },
        clearColor(r, g, b, a) {
            gl.clearColor(r, g, b, a);
        },
        compileShader(shader) {
            gl.compileShader(glShaders[shader]);
        },
        getShaderiv(shader, pname, outptr) {
            new Int32Array(
                getMemory().buffer,
                outptr,
                1
            )[0] = gl.getShaderParameter(glShaders[shader], pname);

        },
        createBuffer() {
            glBuffers.push(gl.createBuffer());
            return glBuffers.length - 1;
        },
        genBuffers(amount, ptr) {
            let out = new Uint32Array(getMemory().buffer, ptr, amount);
            for (let i = 0; i < amount; i += 1) {
                out[i] = glBuffers.length;
                glBuffers.push(gl.createBuffer());
            }
        },
        createFramebuffer() {
            glFramebuffers.push(gl.createFramebuffer());
            return glFramebuffers.length - 1;
        },
        createProgram() {
            glPrograms.push(gl.createProgram());
            return glPrograms.length - 1;
        },
        createShader(shader_type) {
            glShaders.push(gl.createShader(shader_type));
            return glShaders.length - 1;
        },
        genTextures(amount, ptr) {
            let out = new Uint32Array(getMemory().buffer, ptr, amount);
            for (let i = 0; i < amount; i += 1) {
                out[i] = glTextures.length;
                glTextures.push(gl.createTexture());
            }
        },
        deleteBuffers(amount, ids_ptr) {
            let ids = new Uint32Array(getMemory().buffer, ids_ptr, amount);
            for (let i = 0; i < amount; i += 1) {
                const id = ids[i];
                gl.deleteBuffer(glBuffers[id]);
                glBuffers[id] = undefined;
            }
        },
        deleteProgram(id) {
            gl.deleteProgram(glPrograms[id]);
            glPrograms[id] = undefined;
        },
        deleteShader(id) {
            gl.deleteShader(glShaders[id]);
            glShaders[id] = undefined;
        },
        deleteTexture(id) {
            gl.deleteTexture(glTextures[id]);
            glTextures[id] = undefined;
        },
        deleteVertexArrays(amount, ids_ptr) {
            let ids = new Uint32Array(getMemory().buffer, ids_ptr, amount);
            for (let i = 0; i < amount; i += 1) {
                const id = ids[i];
                gl.deleteVertexArray(glVertexArrays[id]);
                glVertexArrays[id] = undefined;
            }
        },
        depthFunc(x) {
            gl.depthFunc(x);
        },
        detachShader(program, shader) {
            gl.detachShader(glPrograms[program], glShaders[shader]);
        },
        disable(cap) {
            gl.disable(cap);
        },
        genVertexArrays(amount, ptr) {
            let out = new Uint32Array(getMemory().buffer, ptr, amount);
            for (let i = 0; i < amount; i += 1) {
                out[i] = glVertexArrays.length;
                glVertexArrays.push(gl.createVertexArray());
            }
        },
        drawArrays(type, offset, count) {
            gl.drawArrays(type, offset, count);
        },
        drawElements(mode, count, type, offset) {
            gl.drawElements(mode, count, type, offset);
        },
        enable(x) {
            gl.enable(x);
        },
        enableVertexAttribArray(x) {
            gl.enableVertexAttribArray(x);
        },
        framebufferTexture2D(target, attachment, textarget, texture, level) {
            gl.framebufferTexture2D(
                target,
                attachment,
                textarget,
                glTextures[texture],
                level
            );
        },
        frontFace(mode) {
            gl.frontFace(mode);
        },
        cullFace(face) {
            gl.cullFace(face);
        },
        getAttribLocation_(program_id, name_ptr, name_len) {
            const name = readCharStr(name_ptr, name_len);
            return gl.getAttribLocation(glPrograms[program_id], name);
        },
        getError() {
            return gl.getError();
        },
        getShaderInfoLog(shader, maxLength, length, infoLog) {
            writeCharStr(
                infoLog,
                maxLength,
                length,
                gl.getShaderInfoLog(glShaders[shader])
            );
        },
        getUniformLocation_(program_id, name_ptr, name_len) {
            const name = readCharStr(name_ptr, name_len);
            glUniformLocations.push(
                gl.getUniformLocation(glPrograms[program_id], name)
            );
            return glUniformLocations.length - 1;
        },
        linkProgram(program) {
            gl.linkProgram(glPrograms[program]);
        },
        getProgramiv(program, pname, outptr) {
            new Int32Array(
                getMemory().buffer,
                outptr,
                1
            )[0] = gl.getProgramParameter(glPrograms[program], pname);
        },
        getProgramInfoLog(program, maxLength, length, infoLog) {
            writeCharStr(
                infoLog,
                maxLength,
                length,
                gl.getProgramInfoLog(glPrograms[program])
            );
        },
        pixelStorei(pname, param) {
            gl.pixelStorei(pname, param);
        },
        shaderSource(shader, count, string_ptrs, string_len_array) {
            let string = "";

            let pointers = new Uint32Array(
                getMemory().buffer,
                string_ptrs,
                count
            );
            let lengths = new Uint32Array(
                getMemory().buffer,
                string_len_array,
                count
            );
            for (let i = 0; i < count; i += 1) {
                // TODO: Check if webgl can accept an array of strings
                const string_to_append = readCharStr(pointers[i], lengths[i]);
                string = string + string_to_append;
            }

            gl.shaderSource(glShaders[shader], string);
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
            data_ptr
        ) {
            const PIXEL_SIZES = {
                [gl.RGBA]: 4,
            };
            const pixel_size = PIXEL_SIZES[format];

            // Need to find out the pixel size for more formats
            if (!format) throw new Error("Unimplemented pixel format");

            const data =
                data_ptr != 0
                    ? new Uint8Array(
                        getMemory().buffer,
                        data_ptr,
                        width * height * pixel_size
                    )
                    : null;

            gl.texImage2D(
                target,
                level,
                internal_format,
                width,
                height,
                border,
                format,
                type,
                data
            );
        },
        texParameterf(target, pname, param) {
            gl.texParameterf(target, pname, param);
        },
        texParameteri(target, pname, param) {
            gl.texParameteri(target, pname, param);
        },
        uniform1f(location_id, x) {
            gl.uniform1f(glUniformLocations[location_id], x);
        },
        uniform1i(location_id, x) {
            gl.uniform1i(glUniformLocations[location_id], x);
        },
        uniform2i(location_id, x, y) {
            gl.uniform2i(glUniformLocations[location_id], x, y);
        },
        uniform4f(location_id, x, y, z, w) {
            gl.uniform4f(glUniformLocations[location_id], x, y, z, w);
        },
        uniformMatrix4fv(location_id, data_len, transpose, data_ptr) {
            const floats = new Float32Array(
                getMemory().buffer,
                data_ptr,
                data_len * 16
            );
            gl.uniformMatrix4fv(
                glUniformLocations[location_id],
                transpose,
                floats
            );
        },
        useProgram(program_id) {
            gl.useProgram(glPrograms[program_id]);
        },
        vertexAttribPointer(
            attrib_location,
            size,
            type,
            normalize,
            stride,
            offset
        ) {
            gl.vertexAttribPointer(
                attrib_location,
                size,
                type,
                normalize,
                stride,
                offset
            );
        },
        viewport(x, y, width, height) {
            gl.viewport(x, y, width, height);
        },
        scissor(x, y, width, height) {
            gl.scissor(x, y, width, height);
        },
    };
}
