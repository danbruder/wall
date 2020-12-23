var flags = null

var app = Elm.Main.init({ flags: flags })

const isProduction = window.location.protocol == "https:"
 
var uri = 'ws://localhost:3030/chat';
if (isProduction) { 
  uri = 'wss://' + window.location.host + '/chat'
}

var socket;

app.ports.sendMessage.subscribe(function(message) {
  console.log('send', message)
  socket.send(message);
});

function initSocket() { 
  var ws = new WebSocket(uri);

  ws.onopen = function() {
    console.log('open')
    app.ports.connected.send(true);
  };

  ws.onmessage = function(msg) {
    console.log('recv', msg)
    app.ports.messageReceiver.send(msg.data);
  };

  ws.onclose = function () { 
    app.ports.disconnected.send(true);

    console.log('Socket is closed. Reconnect will be attempted in 1 second.');
    setTimeout(function() {
      socket = initSocket()
    }, 1000);
  }

  ws.onerror=function(event){
    console.log("Error");
  }

  return ws
}

socket = initSocket()
