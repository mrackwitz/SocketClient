// === Primitive Faye sample server
// 
// == Channels:
//  * /count:
//    Count numbers messages up, if they don't rely from sender "server", which is used
//    to identify own messages.
//

var http = require('http'),
    faye = require('faye');


// Instantiate Faye server adapter
var bayeux = new faye.NodeAdapter({
    mount:    '/faye',
    timeout:  45,
    ping:     30
});

// Handle non-Bayeux requests
var server = http.createServer(function(request, response) {
    response.writeHead(200, {
        'Content-Type': 'text/plain'
    });
    response.write('Non-Bayeux request');
    response.end();
});

// React to count events
bayeux.getClient().subscribe('/count', function(message) {
    console.log('{ sender: %s, number: %d }',
       message.sender, message.number);
        
    if (message.sender != "server") {
        bayeux.getClient().publish('/count', {
            sender: "server",
            number: message.number + 1
        });
    }
});

bayeux.attach(server);
server.listen(8000);
