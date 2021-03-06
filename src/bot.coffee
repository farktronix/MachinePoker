fs = require 'fs'
request = require 'request'
util = require 'util'
vm = require 'vm'
{Pitboss} = require 'pitboss'

class Bot
  
  constructor: (@opts) ->
    @opts ||= {}
    @name = @opts['name'] || "Unnamed"
    @opts['brainSize'] ||= 4096
    @brain = {}
    @loaded = false
    
  getOptions: (code, callback) ->
    myCode = """
     var module = {};
     var exports = module.exports = {};
     #{code};
     var result = {};
      
     var checkAndAssign = function (func) {
       if (func !== undefined && typeof func == 'function') { 
          return func();
       }
       return null;
     }
      
     result.name = checkAndAssign(exports.name);
     result.debug = checkAndAssign(exports.debug);
      
     result
    """
    nameFetcher = new Pitboss(myCode)
    nameFetcher.run {}, (err, result) =>
      console.log(err) if (err) 
      if (result?.name?)
        @name = result.name || @name
      if (result?.debug?)
        @debug = result.debug || @debug
      callback()
      
  setupFinished: =>
    @loaded = true
    @loadedCallback?(this)

  setup: (code) ->
    @getOptions(code, @setupFinished)
    
    code = """
       // Debug setup
       var debug = [];
       var console = {};
       console.log = function(txt){debug.push(txt)};

       // CommonJS compat
       var module = {};
       var exports = module.exports = {};
       #{code};
       var result = {}
       var bet = exports.play(game);
       result = {
         bet: bet,
         brain: game.self.brain,
         debug: debug
       }
       result // Return results to Pitboss
    """
    @player = new Pitboss(code, @opts)

  update: (game, callback) ->
    if (@opts.debug?)
      startTime = Date.now()
    game.self.brain = @brain
    @player.run {game: game}, (err, result) =>
      if (@opts.debug?)
        console.log("Execution of \"" + @name + "\" took " + (Date.now() - startTime) + " ms.")
      if err
        callback(err)
      else
        if @opts['debug']
          for debug in result['debug']
            console.log util.inspect(debug, false, 6)
        @saveBrain(result['brain'])
        callback?(null, result['bet'])

  saveBrain: (brainObj) ->
    length = JSON.stringify(brainObj || {})
    if length > @opts['brainSize']
      # Brain too big! Poof, new brain!
      @brain = {}
    else
      @brain = brainObj

exports.create = (id, opts, callback) ->
  bot = new Bot(opts)
  bot.loadedCallback = callback
  console.log "Creating bot for - #{id}"
  retrieveBot id, (err, code) ->
    bot.setup(code)
  bot

retrieveBot = (id, callback) ->
  if id.match(/^http/)
    request id, (err, response, body) ->
      if err
        callback?(err)
      else
        callback?(null, body.toString())
  else
    fs.readFile id, (err, data) ->
      if err
        callback?(err)
      else
        callback?(null, data.toString())


