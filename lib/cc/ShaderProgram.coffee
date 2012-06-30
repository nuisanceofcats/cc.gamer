cc.module('cc.ShaderProgram').defines -> @set cc.Class.extend {
  init: (gl) ->
    @gl = gl
    @prgrm = @gl.createProgram()
    @u = {} # uniforms
    @a = {} # attributes

  _attachShader: (shader, content) ->
    @gl.shaderSource shader, content
    @gl.compileShader shader

    if not @gl.getShaderParameter shader, @gl.COMPILE_STATUS
      alert @gl.getShaderInfoLog shader
    else
      @gl.attachShader @prgrm, shader
    return

  _attribVertices: (names...) ->
    for name in names
      @gl.enableVertexAttribArray(@a[name] = @gl.getAttribLocation @prgrm, name)
    return

  _uniforms: (names...) ->
    for name in names
      @u[name] = @gl.getUniformLocation @prgrm, name
    return

  # override this to attach fragment shaders first
  link: ->
    @gl.linkProgram @prgrm
    if not @gl.getProgramParameter @prgrm, @gl.LINK_STATUS
      alert "Could not initialise shaders"
    @gl.useProgram @prgrm
}

cc.module('cc.SpriteShaderProgram').defines -> @set cc.ShaderProgram.extend {
  init: (gl, options) ->
    @parent gl
    @pMatrix = mat4.create()
    @scale = options?.scale or 1

    # this ensures that an object of maximum height will fit exactly in the screen
    zDistance = -@gl.viewportHeight / (2 * @scale)

    # reference point at bottom left corner of screen
    @refPoint = mat4.create()
    mat4.identity @refPoint
    mat4.translate @refPoint, [-gl.viewportWidth / (2 * @scale), zDistance, zDistance]

    @mvMatrix = mat4.create()
    mat4.set @refPoint, @mvMatrix

  _attachSpriteFragmentShader: ->
    content = """
        precision mediump float;

        varying vec2 vTextureCoord;

        uniform vec2 tileSize;
        uniform vec2 tileOffset;
        uniform vec2 tileCoord;
        uniform sampler2D sampler;

        void main(void) {
          // gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
          gl_FragColor = texture2D(sampler,
              vec2(vTextureCoord.s, vTextureCoord.t) * tileSize +
              (tileSize * tileOffset) + tileCoord);
        }"""
    shader = @gl.createShader @gl.FRAGMENT_SHADER
    @_attachShader shader, content

  _attachSpriteVertexShader: ->
    content = """
        attribute vec3 vertexPosition;
        attribute vec2 textureCoord;

        uniform mat4 mvMatrix;
        uniform mat4 pMatrix;

        varying vec2 vTextureCoord;

        void main(void) {
          gl_Position = pMatrix * mvMatrix * vec4(vertexPosition, 1.0);
          vTextureCoord = textureCoord;
        }"""
    shader = @gl.createShader @gl.VERTEX_SHADER
    @_attachShader shader, content

  perspective: (deg) ->
    # TODO: set min/max based on current scale
    mat4.perspective(deg, @gl.viewportWidth / @gl.viewportHeight, 1.0, 300.0, @pMatrix)
    @gl.uniformMatrix4fv @u.pMatrix, false, @pMatrix

  drawAt: (x, y) ->
    mat4.translate @refPoint, [x, y, 0.0], @mvMatrix
    @gl.uniformMatrix4fv @u.mvMatrix, false, @mvMatrix

  link: ->
    do @_attachSpriteFragmentShader
    do @_attachSpriteVertexShader
    do @parent
    @_attribVertices "vertexPosition", "textureCoord"
    @_uniforms "tileSize", "tileOffset", "tileCoord", "sampler",
               "pMatrix", "mvMatrix"

    @gl.uniformMatrix4fv @u.mvMatrix, false, @mvMatrix
    return
}
# vim:ts=2 sw=2
