path   = require 'path'
ake    = require 'cc.ake'

do ake.nodeModulePath

task 'web', 'build cc/gamer.js for use in websites', (options) ->
  ake.assert "mkdir -p cc && ccbaker -l -i #{path.join 'node_modules', 'cc.extend', 'cc', 'extend.js'} -m -C lib/cc/gamer.coffee > cc/gamer.js"

task 'clean', 'clean everything generated by build system', (options) ->
  ake.assert "rm -rf `grep '^/' .gitignore | sed 's,^/,,'`"

task 'test', 'test cc.extend', (options) ->
  ake.assert 'ln -sf ../cc test',
    ake.invoke 'web'
    ->
      express = require 'express'
      app     = express.createServer()
      port    = process.env.port or 8014
      app.configure ->
        app.use express.static path.join(process.cwd(), 'test')
      console.log "cc.gamer test server listening on: #{port}"
      console.log "please go to http://localhost:#{port}/"
      app.listen port

# vim:ts=2 sw=2
