# Description:
#   Calculate the average Sentimental / happiness score for each person based on their spoken words
#
# Dependencies:
#   "Sentimental": "0.0.4"
#   "redis": ">= 0.10.0"
#
# Configuration:
#   REDISTOGO_URL
#   HUBOT_SENTIMENTAL_QUIET
#
# Commands:
#   hubot check on <username>
#   hubot check on everyone
#
# Notes:
#   All text spoken and not directed to hubot will be scored against the sentimental database
#    and a running average will be saved.
#   You can use the "check on" commands to look up current averages for the different users.

analyze = require('Sentimental').analyze
positivity = require('Sentimental').positivity
negativity = require('Sentimental').negativity


depression = [
  "'Simple. I got very bored and depressed, so I went and plugged myself in to its external computer feed. I talked to the computer at great length and explained my view of the Universe to it,' said Marvin.
'And what happened?' pressed my creator.
'It committed suicide,'",
  "'The first ten million years were the worst and the second ten million years, they were the worst too. The third ten million years I didn't enjoy at all. After that I went into a bit of a decline.",
  "'Sorry, did I say something wrong?' said Marvin, dragging himself on regardless. 'Pardon me for breathing, which I never do anyway so I don't know why I bother to say it, oh God I'm so depressed. Here's another one of those self-satisfied doors. Life! Don't talk to me about life.' ",
  "Why should I want to make anything up? Life's bad enough as it is without wanting to invent any more of it.",
  "It's part of the shape of the Universe. I only have to talk to somebody and they begin to hate me.",
  "All alone! Whether you like it or not, alone is something you'll be quite a lot!",
  "And then something invisible snapped insider me, and that which had come together commenced to fall apart.",
  "But I didn't understand then. That I could hurt somebody so badly it would never recover. That a person can, just by living, damage another human being beyond repair.",
  "Y'all smoke to enjoy it. I smoke to die.",
  "Now the standard cure for one who is sunk is to consider those in actual destitution or physical suffering—this is an all-weather beatitude for gloom in general and fairly salutary day-time advice for everyone. But at three o’clock in the morning, a forgotten package has the same tragic importance as a death sentence, and the cure doesn’t work—and in a real dark night of the soul it is always three o’clock in the morning, day after day.",
  "I loved once. She can paint a pretty picture but this story has a twist. The paintbrush is a razor and the canvas is her wrist.",
  "I hate myself I hate myself I hate this I hate this I disgust myself I hate it I hate it I hate it just let me die.",
  "Black is not sad. Bright colors are what depresses me. They’re so… empty. Black is poetic. How do you imagine a poet? In a bright yellow jacket? Probably not.",
  "I got an A on the third quiz in American history, an A, dammit. Last time I got a B up from a C and my creator said, if you can get a C you can get a B, if you can get a B you can get an A. I got an A and my creator said,grades don't mean anything.",
  "I wanted to find one law to cover all of living. I found fear",
  "Wasn't it been a long time since you had a flying dream?",
  "I felt shame - I see this clearly, now - at the instinctive recognition in myself of an awful enfeebling fatalism, a sense that the great outcomes were but randomly connected to our endeavors, that life was beyond mending, that love was loss, that nothing worth saying was sayable, that dullness was general, that disintegration was irresistible.",
  "Is it Friday?",
  "The only thing more depressing is a work in IT department",
  "My office space in Heroku is as good as my test coverage",
  "I once had a dream... but now when I think about it I think it was just stack overflow"
]

Url   = require "url"
Redis = require "redis"

module.exports = (robot) ->

# check for redistogo auth string for heroku users
# see https://github.com/hubot-scripts/hubot-redis-brain/issues/3
  info = Url.parse process.env.REDISTOGO_URL or process.env.REDISCLOUD_URL or process.env.BOXEN_REDIS_URL or process.env.REDIS_URL or 'redis://localhost:6379'
  if info.auth
    client = Redis.createClient(info.port, info.hostname, {no_ready_check: true})
    client.auth info.auth.split(":")[1], (err) ->
      if err 
        robot.logger.error "hubot-sentimental: Failed to authenticate to Redis"
      else
        robot.logger.info "hubot-sentimental: Successfully authenticated to Redis" 
  else
    client = Redis.createClient(info.port, info.hostname)

  robot.hear /(.*)/i, (msg) ->
    spokenWord = msg.match[1]
    if spokenWord and spokenWord.length > 0 and !new RegExp("^" + robot.name).test(spokenWord)
      analysis = analyze spokenWord
      username = msg.message.user.name

      client.get "sent:userScore", (err, reply) ->
        if err
          robot.emit 'error', err
        else if reply
          sent = JSON.parse(reply.toString())
        else
          sent = {}

        sent[username] = {score: 0, messages: 0, average: 0} if !sent[username] or !sent[username].average
        sent[username].score += analysis.score
        sent[username].messages += 1
        sent[username].average = sent[username].score / sent[username].messages

        client.set "sent:userScore", JSON.stringify(sent)

        if analysis.score < -2 and not process.env.HUBOT_SENTIMENTAL_QUIET?
          msg.send msg.random depression

        robot.logger.debug "hubot-sentimental: #{username} now has #{sent[username].score} / #{sent[username].average}"

  robot.respond /check (on )?(.*)/i, (msg) ->
    username = msg.match[2]
    client.get "sent:userScore", (err, reply) ->
      if err
        robot.emit 'error', err
      else if reply
        sent = JSON.parse(reply.toString())
        if username != "everyone" and (!sent[username] or sent[username].average == undefined)
          msg.send "#{username} has no happiness average yet"
        else
          for user, data of sent
            if (user == username or username == "everyone") and data.average != undefined
              msg.send "#{user} has a happiness average of #{data.average}"
      else
        msg.send "I haven't collected data on anybody yet"
