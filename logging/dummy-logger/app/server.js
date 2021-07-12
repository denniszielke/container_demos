require('dotenv-extended').load();
const config = require('./config');

const express = require('express');
const app = express();
const morgan = require('morgan');

const OS = require('os');

// add logging middleware
app.use(morgan('dev'));

var d = new Date();

var requestStats = { totalRequestNumber :0, totalRequestFailed: 0, totalRequestThrottled: 0, timeslot: 0};
requestStats.timeslot = d.getHours() * 100 + Math.floor(d.getMinutes() / config.metricReset);
var checkStats = function(newValue, incrementer){
    d = new Date();
    var currentTimeSlot = d.getHours() * 100 + Math.floor(d.getMinutes() / config.metricReset);
    if (currentTimeSlot > requestStats.timeslot){
        requestStats.timeslot = currentTimeSlot;
        requestStats.totalRequestNumber = 0;
        requestStats.totalRequestFailed = 0;
        requestStats.totalRequestThrottled = 0;
    }
}

// Routes

app.get('/', function(req, res) {
    console.log('received request');
    requestStats.totalRequestNumber++;
    checkStats();
    res.send('Hi!');
});

app.get('/metrics', function(req, res) {
    console.log('received fail request');
    console.log(requestStats);
    var output = "# HELP http_requests_total Total number of HTTP requests made."  + OS.EOL +
        "# TYPE http_requests_total counter" + OS.EOL +
        "http_requests_total{code=\"200\",handler=\"prometheus\",method=\"get\"} " + requestStats.totalRequestNumber + OS.EOL +
        "# HELP http_requests_throttled Total number of throttled HTTP requests made."  + OS.EOL +
        "# TYPE http_requests_throttled counter" + OS.EOL +
        "http_requests_throttled{code=\"200\",handler=\"prometheus\",method=\"get\"} " + requestStats.totalRequestThrottled + "\n";
    res.send(output);
});

app.get('/fail/500', function(req, res) {
    console.log('received fail request');
    requestStats.totalRequestFailed++;
    checkStats();
    res.status(500);
    res.send('Failed with internal error - 500');
});

app.get('/rate/me', function(req, res) {
    var randomNumber = Math.floor((Math.random() * 4));
    if (randomNumber < 1){
        console.log('randomly sending 429');
        requestStats.totalRequestThrottled++;
        checkStats();
        res.status(429);
        res.send('Please slow down - 429');
    }else
    {
        console.log('randomly sending 200');
        requestStats.totalRequestNumber++;
        checkStats();
        res.status(200);
        res.send('Please continue');
    }
});

app.get('/headers', function(req, res) {
    console.log('received headers');
    console.log(req.headers);
    res.send(req.headers);
});

app.post('/headers', function(req, res) {
    console.log('received headers');
    console.log(req.headers);
    res.send(req.headers);
});

app.get('/ping', function(req, res) {
    console.log('received ping');
    var startDate = new Date();
    var month = (((startDate.getMonth()+1)<10) ? '0' + (startDate.getMonth()+1) : (startDate.getMonth()+1));
    var day = (((startDate.getDate())<10) ? '0' + (startDate.getDate()) : (startDate.getDate()));
    var hour = (((startDate.getHours())<10) ? '0' + (startDate.getHours()) : (startDate.getHours()));
    var minute = (((startDate.getMinutes())<10) ? '0' + (startDate.getMinutes()) : (startDate.getMinutes()));
    var seconds = (((startDate.getSeconds())<10) ? '0' + (startDate.getSeconds()) : (startDate.getSeconds()));
    var logDate = startDate.getFullYear() + "-" +
        month+  "-" + day + " " + hour + ":" + minute + ":" + seconds; 
    var sourceIp = req.connection.remoteAddress;
    
    var forwardedFrom = (req.headers['x-forwarded-for'] || '').split(',').pop();
        
    var logObject = { timestamp: logDate, host: OS.hostname(), source: sourceIp, forwarded: forwardedFrom, message: "Pong!"};
    var serverResult = JSON.stringify(logObject );
    requestStats.totalRequestNumber++;
    checkStats();
    console.log(serverResult.toString());
    res.send(serverResult.toString());
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
    var sourceIp = //(req.headers['x-forwarded-for'] || '').split(',').pop() || 
        req.connection.remoteAddress || 
        req.socket.remoteAddress || 
        req.connection.socket.remoteAddress;
    var logObject = { timestamp: logDate, value: randomNumber, host: OS.hostname(), source: sourceIp, message: messageReceived};
    var serverResult = JSON.stringify(logObject );
    console.log("string:");
    console.log(serverResult.toString());
    console.log(logDate + "," + randomNumber + "," + OS.hostname() + "," + sourceIp + "," + messageReceived);
    // console.log("json object:");
    // console.log(logObject);
    res.send(serverResult.toString());
});

console.log(config);
console.log(OS.hostname());
app.listen(config.port);
console.log('Listening on localhost:'+ config.port);