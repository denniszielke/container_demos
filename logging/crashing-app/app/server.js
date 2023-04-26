require('dotenv-extended').load();
const config = require('./config');

const express = require('express');
const app = express();
const morgan = require('morgan');
const client = require('prom-client');
const OS = require('os');

const register = new client.Registry();
client.collectDefaultMetrics({
    app: 'node-application-monitoring-app',
    prefix: 'node_',
    timeout: 10000,
    gcDurationBuckets: [0.001, 0.01, 0.1, 1, 2, 5],
    register
});

// add logging middleware
app.use(morgan('dev'));

// Routes
app.get('/metrics', async (req, res) => {
    res.setHeader('Content-Type', register.contentType);
    res.send(await register.metrics());
});

app.get('/', function(req, res) {
    console.log('base received request');
    process.stdout.write('base eceived request');
    res.send('base request received!');
});
app.get('/ping', function(req, res) {
    console.log('received ping - send Pong');
    process.stdout.write('received ping - send Pong');
    res.send('Pong');
});

app.get('/crash', function(req, res) {
    console.log('received crash request - crashing');
    process.stdout.write('received crash request - crashing');
    res.send('crashing');
    process.exit(1);
});

function LeakingClass() {
}

app.get('/leak', function(req, res) {
    console.log('received leak request - leaking');
    var leaks = [];
    setInterval(function() {
    for (var i = 0; i < 1000; i++) {
        leaks.push(new LeakingClass);
    }

    console.error('Leaks: %d', leaks.length);
    }, 500);
    process.stdout.write('received leak request - leaking');
    res.send('leaking');
});

console.log(config);
console.log(OS.hostname());
app.listen(config.port);
console.log('Listening on localhost:'+ config.port + ', metrics are exposed on http://localhost:' + config.port  + '/metrics');

if (process.env.LEAK){
    console.log('Leaking automatically');
    var leaks = [];
    setInterval(function() {
    for (var i = 0; i < 1000; i++) {
        leaks.push(new LeakingClass);
    }

    console.error('Leaks: %d', leaks.length);
    }, 1000);
    process.stdout.write('received leak request - leaking');
}