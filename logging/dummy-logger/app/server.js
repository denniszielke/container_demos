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
    var messageReceived = "no";
    if (req.headers.message){
        console.log(req.headers.message);
        messageReceived = req.headers.message;
    }
    var startDate = new Date();
    var month = (((startDate.getMonth()+1)<10) ? '0' + (startDate.getMonth()+1) : (startDate.getMonth()+1));
    var day = (((startDate.getDate())<10) ? '0' + (startDate.getDate()) : (startDate.getDate()));
    var hour = (((startDate.getHours())<10) ? '0' + (startDate.getHours()) : (startDate.getHours()));
    var minute = (((startDate.getMinutes())<10) ? '0' + (startDate.getMinutes()) : (startDate.getMinutes()));
    var seconds = (((startDate.getSeconds())<10) ? '0' + (startDate.getSeconds()) : (startDate.getSeconds()));
    var logDate = startDate.getFullYear() + "-" +
        month+  "-" + day + " " + hour + ":" + minute + ":" + seconds; 
    var randomNumber = Math.floor((Math.random() * 100) + 1);
    var sourceIp = (req.headers['x-forwarded-for'] || '').split(',').pop() || 
        req.connection.remoteAddress || 
        req.socket.remoteAddress || 
        req.connection.socket.remoteAddress;
    var logObject = { timestamp: logDate, value: randomNumber, host: OS.hostname(), source: sourceIp, message: messageReceived};
    var serverResult = JSON.stringify(logObject );
    console.log("string:");
    console.log(serverResult);
    console.log("json object:");
    console.log(logObject);
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