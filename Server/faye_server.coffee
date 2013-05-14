# === Primitive Faye sample server
# 
# == Channels:
#  * /count:
#    Count numbers messages up, if they don't rely from sender "server", which is used
#    to identify own messages.
#

http = require 'http',
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
    console.log '{ sender: %s, count: %d }',
      message.sender, message.count
    
    if (message.sender is not 'server')
        message.sender = 'server'
        bayeux.getClient().publish '/count',
             sender: 'server',
             count:  message.count + 1


bayeux.attach server
server.listen 8000
