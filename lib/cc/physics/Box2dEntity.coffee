cc.module('cc.physics.Box2dEntity').requires('cc.physics.Box2dEntityEvents').defines -> @set cc.Class.extend {
  _evHandler: new cc.physics.Box2dEntityEvents
  _events: [] # events to be posted back to game (e.g. stomp/hit)

  isEntity: true

  maxV: { x: 200, y: 100 } # maximum velocity

  groundTouches: 0 # how many elements the foot sensor touches
  standing: false  # is on ground.. when groundTouches == 0

  _onUpdate: null # optional callback to perform on next update

  _setFriction: (val) ->
    @_fix.SetFriction val
    contactEdge =  @_body.GetContactList()
    loop
      break if Box2D.compare(contactEdge, Box2D.NULL)
      contactEdge.get_contact().ResetFriction()
      contactEdge = contactEdge.get_next()
    return

  groundContact: ->
    ++@groundTouches
    if not @standing
      @standing = true
      # groundSensor can fire before actually touching causing the landing
      # force to stop the object sliding on land
      @_onUpdate = ->
        @_setFriction @friction if @standing
    return

  groundLoseContact: ->
    if not --@groundTouches and @standing
      # friction is set to 0 when jumping to avoid sticking to walls
      @standing = false
      @_setFriction 0
    return

  # When adding elements to p make sure to /note:
  init: (p, @world) ->
    @world.entities.push this

    s = @world.scale
    @width = p[7] / s
    @height = p[8] / s
    @friction = p[12]

    @_fixDef = new b2FixtureDef
    filter = new b2Filter
    filter.set_categoryBits p[9]
    filter.set_maskBits p[10]
    @_fixDef.set_filter filter
    @_fixDef.set_restitution p[11]
    @_fixDef.set_friction @friction
    @_fixDef.set_density p[13]
    @maxV.x = p[14] / s
    @maxV.y = p[15] / s

    @a =
      x: p[5] / s
      y: p[6] / s

    @_createBody p[1], p[2], p[3], p[4]

    # note: 16 relates to last non event argument in p
    @_evHandler.updateFrom this, p, 16
    return

  _createBody: (px, py, vx = 0, vy = 0) ->
    s = @world.scale

    @_bodyDef = new b2BodyDef
    @_bodyDef.set_type Box2D.b2_dynamicBody

    width = @width / 2
    height = @height / 2

    # b2 uses centre position so adjust..
    @_bodyDef.set_position new b2Vec2(px / s + width, py / s + height)
    @_bodyDef.set_linearVelocity new b2Vec2(vx / s, vy / s)

    # TODO: support entities without fixed rotation
    @_bodyDef.set_fixedRotation true

    shape = new b2PolygonShape
    shape.SetAsBox width, height
    @_fixDef.set_shape shape

    @_body = @world.b2.CreateBody @_bodyDef
    fix = @_body.CreateFixture @_fixDef
    fix.entity = this
    @_fix = fix

    # scale = make foot height of 1/3rd of a pixel
    # too tall and friction can be disabled before it hits the ground
    # making skidding after a jump not happen, too small and bouncing
    # softly against the ground can disable jumping
    ftHeight = 1 / (s * 3 * 2)

    # space around side of foot, to prevent jumping up walls
    # I've found that setting this any lower than 4/s gives a lot
    # of false stomp events when approaching objects from the side
    ftFree = 4 / s
    # add foot sensor
    @_ftSensorDef = new b2FixtureDef
    ftShape = new b2PolygonShape
    ftShape.SetAsBox(width - ftFree,
                     ftHeight,
                     new b2Vec2(0, height + ftHeight),
                     0.0)
    @_ftSensorDef.set_shape ftShape
    @_ftSensorDef.set_isSensor true
    footFixt = @_body.CreateFixture @_ftSensorDef
    footFixt.entity = this
    footFixt.foot = true
    return

  _step: (tick) ->
    # TODO: handle acceleration
    return

  update: ->
    if @_onUpdate
      @_onUpdate()
      @_onUpdate = null

    s = @world.scale
    v = @_body.GetLinearVelocity()

    if @a.x or @a.y
      newVx = v.get_x() + (@world.tick * @a.x)
      newVy = v.get_y() + (@world.tick * @a.y)

      if @a.x > 0
        newVx = @maxV.x if newVx > @maxV.x
      else if @a.x < 0
        newVx = -@maxV.x if newVx < -@maxV.x

      if @a.y > 0
        newVy = @maxV.y if newVy > @maxV.y
      else if @a.y < 0
        newVy = -@maxV.y if newVy < -@maxV.y

      if newVx isnt v.x or newVy isnt v.y
        m = @_body.GetMass()
        @_body.ApplyLinearImpulse new b2Vec2(
            m * (newVx - v.get_x()),
            m * (newVy - v.get_y())),
          @_body.GetWorldCenter()

    p = @_body.GetPosition()
    ret = [ (p.get_x() - @width / 2) * s,
      (p.get_y() - @height / 2) * s,
      v.get_x() * s, v.get_y() * s,
      @standing ].concat @_events

    @_events.length = 0
    return ret

  uncompressPhysics: (p) ->
    # 1 for E
    if p.length is 1
      @world.b2.DestroyBody @_body
      for ent, idx in @world.entities
        if ent.id is @id
          @world.entities.splice idx, 1
          break
    else
      @_evHandler.update this, p

    return
}
# vim:ts=2 sw=2
