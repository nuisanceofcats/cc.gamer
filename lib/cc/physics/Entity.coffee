# Represents physics of an entity.
# Shared by Web Worker and main thread.
# The physics updating part of the code is only used by the main thread in
# case Web Workers aren't available (IE9, some mobile browsers).
# Deriving class must define "_mark"
cc.module('cc.physics.Entity').defines -> @set cc.Class.extend {
  pos: { x: 0, y: 0, z: 0 } # position
  width:  0
  height: 0
  v:    { x: 0, y: 0 }     # velocity
  maxV: { x: 200, y: 100 } # maximum velocity
  a:    { x: 0, y: 0 }     # acceleration
  bounciness: 0            # box2d restitution
  standing: false          # whether standing on ground
  friction:   0.5
  density:    1.0
  # optional - hitbox: { width, height, offset { x, y } }
  _knownByPhysicsServer: false
  _events: [] # physics update events to be sent to physics thread
  facingLeft: true # whether the entity is facing left

  # compress physics for new entity
  _compressedPhysicsForNew: ->
    x      = @pos.x
    y      = @pos.y
    width  = @width
    height = @height
    if @hitbox
      x     += @hitbox.offset.x
      y     += @hitbox.offset.y
      width  = @hitbox.width
      height = @hitbox.height
    [ 'E', x, y, @v.x, @v.y, @a.x, @a.y, width, height, @category,
      @mask, @bounciness, @friction, @density, @maxV.x, @maxV.y ].concat @_events

  # compressed physics for update
  # TODO: rotation
  compressedPhysics: ->
    if @_knownByPhysicsServer
      ev = @_events
    else
      if @_deletePhysics
        return ['E']
      else
        @_knownByPhysicsServer = true
        ev = @_compressedPhysicsForNew()

    @_events = []
    return ev

  # uncompress physics sent from worker, always for update as physics engine
  # can't create new entity
  uncompressPhysics: (p) ->
    [ @pos.x, @pos.y, @v.x, @v.y, @standing ] = p  # :)
    if @hitbox
      @pos.x -= @hitbox.offset.x
      @pos.y -= @hitbox.offset.y

    # scan optional events
    if p.length > 5
      i = 5
      loop
        break if i >= p.length
        if p[i] is 's'
          if @_onStomp
            stompee = @game.entitiesById[p[i + 1]]
            @_onStomp stompee if stompee
        else if p[i] is 'h'
          if @_onHit
            hit = @game.entitiesById[p[i + 1]]
            @_onHit hit if hit
        i += 2

    @update()
    return

  _detectFacing: ->
    if (@facingLeft and @v.x > 1) or (not @facingLeft and @v.x < -1)
      @facingLeft = not @facingLeft
    return

  _setV: (t, vx, vy) ->
    @v.x = vx
    @v.y = vy
    @_detectFacing()
    @_events.push t, vx, vy
    @_mark()

  setV: (vx, vy) ->
    @_setV 'v', vx, vy

  jump: (vx, vy) ->
    @_setV 'j', vx, vy

  setA: (ax, ay) ->
    @a.x = ax
    @a.y = ay
    @_events.push 'a', ax, ay
    @_mark()

  _getHitEvents: ->
    @_events.push 'h'
    @_mark() if @id # if @id .. so can call in constructor
    return

  _getStompEvents: ->
    @_events.push 's'
    @_mark() if @id
    return

  setPos: (px, py) ->
    @pos.x = px
    @pos.y = py
    if @hitbox
      px += @hitbox.offset.x
      py += @hitbox.offset.y
    @_events.push 'p', px, py
    @_mark()

  removeFromPhysicsServer: ->
    return unless @_knownByPhysicsServer
    @_knownByPhysicsServer = false
    @_deletePhysics = true
    @_mark()
}
# vim:ts=2 sw=2
