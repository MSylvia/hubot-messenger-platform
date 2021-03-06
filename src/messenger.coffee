{Adapter,TextMessage,User} = require 'hubot'

FB_MESSAGING_ENDPOINT = "https://graph.facebook.com/v2.6/me/messages"

class Messenger extends Adapter

  constructor: (@robot) ->
    super @robot

  send: (envelope, messages...) ->
    for msg in messages
      data = JSON.stringify({
        recipient : {
          id: envelope.user.id
        },
        message : {
          text : msg
        }
      })
      @robot.http(FB_MESSAGING_ENDPOINT + "?access_token=" + @options.pageAccessToken)
        .header('Content-Type', 'application/json')
        .post(data) (err, res, body) =>
          if err
            @robot.logger.error "Failed to send response : " + err
          else if res.statusCode != 200
            @robot.logger.error "Failed to send response : " + body

  reply: @prototype.send

  run: ->
    @options =
      verificationToken : process.env.HUBOT_MESSENGER_VERIFICATION_TOKEN
      pageAccessToken : process.env.HUBOT_MESSENGER_PAGE_ACCESS_TOKEN

    return @robot.logger.error "No messenger verification token was provided" unless @options.verificationToken
    return @robot.logger.error "No messenger page access token was provided" unless @options.pageAccessToken

    @emit 'connected'

    @robot.router.get '/webhook', (req, res) =>
      @robot.logger.debug "Received a validation request"
      if req.query['hub.verify_token'] == @options.verificationToken
        res.send req.query['hub.challenge']
      else
        res.send "Error, wrong validation token"

    @robot.router.post '/webhook', (req,res) =>
      messaging_events = req.body.entry[0].messaging
      i = 0
      while i < messaging_events.length
        event = req.body.entry[0].messaging[i]
        senderId = event.sender.id
        if event.message and event.message.text
          text = event.message.text.substring(0,317) + "..."
          user = new User senderId, room: senderId
          @robot.logger.info "Received message: '#{text}' from '#{senderId}'"
          @robot.receive new TextMessage(user, text)
        i++
      res.send 'OK'

    @robot.logger.info "Ready to receive messages .."

exports.use = (robot) ->
  new Messenger robot
