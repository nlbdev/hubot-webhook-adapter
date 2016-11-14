# Description:
#   Webhook adapter for handling messages arriving from other HuBot instances.
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_MASTER_URL - the webhook URL to the master HuBot
#   WEBHOOK_ADAPTER_COMMAND_FORWARD - if set, will forward all requests to this command
#   WEBHOOK_ADAPTER_COMMAND_WHITELIST - use in together with the *_FORWARD variable to exclude certain commands
#
# Notes:
#   This adapter sets up a webhook to receive messages from another "master" HuBot instance,
#   and sends the responses back to that HuBot instance.
#
#   The environment variable HUBOT_MASTER_URL must be set to the webhook URL for this the "master" HuBot instance.
#   The webhook URL for the main instance is also on the form `http://<ip>:8080/hubot/message`.
#
#   All messages can optionally be forwarded to a specific command. The use-case here is for the hubot-script-shellcmd
#   shell command script, where you may want to avoid having to type 'shellcmd' before all the commands. In this case,
#   you can set the WEBHOOK_ADAPTER_COMMAND_WHITELIST environment variable to "adapter echo help ping time shellcmd",
#   and the WEBHOOK_ADAPTER_COMMAND_FORWARD environment variable to "shellcmd". Edit WEBHOOK_ADAPTER_COMMAND_WHITELIST
#   as appropriate if you have additional commands that you don't want automatically forwarded to hubot-script-shellcmd.
#   If this hubot receives a message "x y z", and WEBHOOK_ADAPTER_COMMAND_FORWARD and WEBHOOK_ADAPTER_COMMAND_WHITELIST
#   is set as previously described, then the message will be rewritten as "x shellcmd y z".
#
# Author:
#   josteinaj

{Adapter, Message, TextMessage, EnterMessage, LeaveMessage, TopicMessage, CatchAllMessage} = require 'hubot'

class Webhook extends Adapter
  
  callback: (type, envelope, strings...) ->
    messageType = switch
      when envelope.message instanceof TextMessage then 'TextMessage'
      when envelope.message instanceof EnterMessage then 'EnterMessage'
      when envelope.message instanceof LeaveMessage then 'LeaveMessage'
      when envelope.message instanceof TopicMessage then 'TopicMessage'
      when envelope.message instanceof Message then 'Message'
      else 'CatchAllMessage'
    data = JSON.stringify({
      type: type,
      messageType: messageType
      name: @robot.name,
      envelope: envelope,
      strings: strings
    })
    if process.env.HUBOT_MASTER_URL
      @robot.http(process.env.HUBOT_MASTER_URL)
        .header('Content-Type', 'application/json')
        .post(data) (err, res, body) ->
          if err
            # error
            console.log "Encountered an error while sending message to master: "+err
            return
          
          else if res.statusCode isnt 200
            # error
            console.log "Message sent to master didn't come back with a HTTP 200"
            return
          
          #else
          #  # success
          #  console.log "Message successfully sent to master"
    else
      @robot.logger.warning "HUBOT_MASTER_URL is not defined: try: export HUBOT_MASTER_URL='http://example.net:80/hubot/message'"
      console.log "data:", data
  
  constructor: ->
    super
    @robot.logger.info "Constructor"
  
  send: (envelope, strings...) ->
    @robot.logger.info "Send"
    @callback "send", envelope, strings...
  
  reply: (envelope, strings...) ->
    @robot.logger.info "Reply"
    @callback "reply", envelope, strings...

  emote: (envelope, strings...) ->
    @robot.logger.info "Emote"
    @callback "emote", envelope, strings...
  
  checkCanStart: ->
    if not process.env.HUBOT_MASTER_URL
      throw new Error("HUBOT_MASTER_URL is not defined: try: export HUBOT_MASTER_URL='http://example.net:80/hubot/message'")
  
  run: ->
    @robot.logger.info "Run"
    do @checkCanStart
    
    @robot.router.post '/hubot/message', (req, res) =>
      res.send 'OK'
      
      @robot.logger.debug "Received Request"
      
      if !req.is 'json'
        res.json {status: 'failed', error: "request isn't json"}
        @robot.logger.debug "Error: request isn't json"
        return
      
      messageType = req.body.messageType
      message = req.body.message
      
      if !messageType || !message
        res.json {status: 'failed', error: "request data missing"}
        @robot.logger.debug "Error: request data missing"
        return
      
      user = @robot.brain.userForId message.user.id, name: message.user.name, room: message.user.room
      
      switch messageType
        when "Message" then message = new Message(user, message.done)
        when "TextMessage" then message = new TextMessage(user, message.text, message.id)
        when "EnterMessage" then message = new EnterMessage(user, message.text, message.id)
        when "LeaveMessage" then message = new LeaveMessage(user, message.text, message.id)
        when "TopicMessage" then message = new TopicMessage(user, message.text, message.id)
        else message = new CatchAllMessage(message?.message or message)
      
      for propertyName, propertyValue of req.body.message
        message[propertyName] = propertyValue
      
      @robot.logger.debug "Handling received message"
      
      if process.env.WEBHOOK_ADAPTER_COMMAND_WHITELIST
        if (message.text.replace /^[^\s]+\s+([^\s]+)(\s.*|$)/, "$1") not in process.env.WEBHOOK_ADAPTER_COMMAND_WHITELIST.split " "
          message.text = message.text.replace /^([^\s]+)(\s.*|$)/, "$1 "+process.env.WEBHOOK_ADAPTER_COMMAND_FORWARD+"$2"
      
      @robot.receive(message, (robot) ->
        #console.log "Received message handled"
      )
    
    @emit "connected"
    
  exports.use = (robot) ->
    new Webhook robot
