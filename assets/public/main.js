var flags = null

var app = Elm.Main.init({ flags: flags })


const isProduction = window.location.protocol == "https"
var uri = 'ws://localhost:3030/chat';

if (isProduction ) { 
  uri = 'wss://' + window.location.host + '/chat'
}

// Create your WebSocket.
var socket = new WebSocket(uri);

app.ports.sendMessage.subscribe(function(message) {
  console.log('send', message)
  socket.send(message);
});


socket.onopen = function() {
  console.log('open')
  app.ports.connected.send(true);
};

socket.onmessage = function(msg) {
  console.log('recv', msg)
  app.ports.messageReceiver.send(msg.data);
};

socket.onclose = function() {
  console.log('close')
  app.ports.disconnected.send(true);
};

