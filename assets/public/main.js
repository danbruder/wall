var flags = null

var app = Elm.Main.init({ flags: flags })

const isProduction = window.location.protocol == "https:"
 
var uri = 'ws://localhost:3030/chat';
if (isProduction) { 
  uri = 'wss://' + window.location.host + '/chat'
}

var socket;

app.ports.sendMessage.subscribe(function(message) {
  socket.send(JSON.stringify(message));
});

function initSocket() { 
  var ws = new WebSocket(uri);

  ws.onopen = function() {
    app.ports.connected.send(true);
  };

  ws.onmessage = function(msg) {
    app.ports.messageReceiver.send(msg.data);
  };

  ws.onclose = function () { 
    app.ports.disconnected.send(true);

    setTimeout(function() {
      socket = initSocket()
    }, 3000);
  }

  return ws
}

socket = initSocket()
