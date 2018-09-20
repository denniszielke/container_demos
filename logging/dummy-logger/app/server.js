require('dotenv-extended').load();
const config = require('./config');

const express = require('express');
const app = express();
const morgan = require('morgan');

const OS = require('os');

// add logging middleware
app.use(morgan('dev'));

// Routes

app.get('/', function(req, res) {
    console.log('received request');
    res.send('Hi!');
});
app.get('/ping', function(req, res) {
    console.log('received ping');
    res.send('Pong');
});

app.post('/api/log', function(req, res) {
    console.log("received client request:");
    console.log(req.headers.message);
    var startDate = new Date();
    var randomNumber = Math.floor((Math.random() * 10000000) + 1);
    var serverResult = JSON.stringify({ timestamp: startDate, value: randomNumber, host: OS.hostname() } );
    console.log(serverResult);
    res.send(serverResult.toString());
});

console.log(config);
console.log(OS.hostname());
// Listen
if (config.instrumentationKey){ 
    client.trackEvent({ name: "dummy-logger-initializing"});
}
app.listen(config.port);
console.log('Listening on localhost:'+ config.port);