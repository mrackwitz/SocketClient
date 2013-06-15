# === Primitive Faye sample server
# 
# == Channels:
#  * /count:
#    Count number messages up, if they don't come from sender "server", which is used
#    to identify own count messages.
#    Published messages SHOULD have a field "sender".
#    Published messages MUST have a field "number".
#

http = require 'http'
faye = require 'faye'


# Instantiate Faye server adapter
bayeux = new faye.NodeAdapter
    mount:    '/faye',
    timeout:  45,
    ping:     30


# Handle non-Bayeux requests
server = http.createServer (request, response) ->
    response.writeHead 200,
        'Content-Type': 'text/plain'
    response.write 'Non-Bayeux request'
    response.end()


# React to count events
bayeux.getClient().subscribe '/count', (message) ->
    console.log '{ sender: %s, number: %d }',
      message.sender, message.number
    
    if (message.sender isnt 'server')
        message.sender = 'server'
        bayeux.getClient().publish '/count',
             sender: 'server',
             number: message.number + 1


bayeux.attach server
server.listen 8000
