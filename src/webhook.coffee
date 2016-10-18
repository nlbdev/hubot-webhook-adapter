{Adapter, Message, TextMessage, EnterMessage, LeaveMessage, TopicMessage, CatchAllMessage} = require 'hubot'

class Webhook extends Adapter
  
  callback: (type, envelope, strings...) ->
    data = JSON.stringify({
      type: type,
      envelope: envelope,
      strings: strings
    })
    if process.env.HUBOT_MASTER_URL
      robot.http(process.env.HUBOT_MASTER_URL)
        .header('Content-Type', 'application/json')
        .post(data) (err, res, body) ->
          if err
            @robot.logger.error "Encountered an error while sending message to master: {err}"
            return
          
          else if res.statusCode isnt 200
            @robot.logger.error "Message sent to master didn't come back with a HTTP 200"
            return
          
          else
            @robot.logger.debug "Message successfully sent to master"
    else
      @robot.logger.warning "HUBOT_MASTER_URL is not defined: try: export HUBOT_MASTER_URL='http://example.net:80/hubot/message'"
      console.log "data:", data
  
  constructor: ->
    super
    @robot.logger.info "Constructor"
  
  send: (envelope, strings...) ->
    @robot.logger.info "Send"
    @callback "send", envelope, strings
  
  reply: (envelope, strings...) ->
    @robot.logger.info "Reply"
    @callback "reply", envelope, strings

  emote: (envelope, strings...) ->
    @robot.logger.info "Emote"
    @callback "emote", envelope, strings
  
  checkCanStart: ->
    if not process.env.HUBOT_MASTER_URL
      throw new Error("HUBOT_MASTER_URL is not defined: try: export HUBOT_MASTER_URL='http://example.net:80/hubot/message'")
  
  run: ->
    @robot.logger.info "Run"
    #do @checkCanStart
    
    options =
      name:     process.env.HUBOT_SLAVE_NAME or @robot.name
      port:     process.env.HUBOT_MASTER_PORT or 3000
      server:   process.env.HUBOT_MASTER_URL
      token:    process.env.HUBOT_MASTER_TOKEN or ''
      debug:    process.env.HUBOT_MASTER_DEBUG?
    
    @robot.name = options.name
    
    @robot.router.post '/hubot/message', (req, res) =>
      res.send 'OK'
      
      @robot.logger.info "Received Request"
      
      if !req.is 'json'
        res.json {status: 'failed', error: "request isn't json"}
        console.log "Error: request isn't json"
        return
      
      type = req.body.type
      message = req.body.message
      
      if !type || !message
        res.json {status: 'failed', error: "request data missing"}
        console.log "Error: request data missing"
        return
      
      user = @userForId message.user.id, name: message.user.name, room: message.user.room
      
      switch type
        when "Message" then message = new Message(user, message.done)
        when "TextMessage" then message = new TextMessage(user, message.text, message.id)
        when "EnterMessage" then message = new EnterMessage(user, message.text, message.id)
        when "LeaveMessage" then message = new LeaveMessage(user, message.text, message.id)
        when "TopicMessage" then message = new TopicMessage(user, message.text, message.id)
        else message = new CatchAllMessage(message?.message or message)
      
      @robot.logger.info "Handling received message"
      
      @robot.receive(message, (robot) ->
        console.log "Received message handled"
      )
    
    @emit "connected"
    
  exports.use = (robot) ->
    new Webhook robot
