var flags = null

var app = Elm.Main.init({ flags: flags })

// Create your WebSocket.
const uri = 'ws://localhost:3030/chat';
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

