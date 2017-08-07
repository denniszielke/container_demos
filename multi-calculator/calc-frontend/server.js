var express = require('express');
var app = express();
var morgan = require('morgan');
var request = require('request');

var config = require('./config');

var appInsights = require('applicationinsights');
appInsights.setup(config.instrumentationKey).setAutoCollectRequests(true).start();

var port = process.env.PORT || 3000;
var publicDir = require('path').join(__dirname, '/public');

// add logging middleware
app.use(morgan('dev'));
app.use(express.static(publicDir));

// Routes
app.get('/ping', function(req, res) {
    console.log('received ping');
    res.send('Pong');
});

app.post('/api/square', function(req, res) {
    console.log("received client request:");
    console.log(req.headers);
    var startDate = new Date();
    insightsClient.trackEvent("square-client-call", { value: req.headers.number });
    var formData = {
        received: new Date().toLocaleString(), 
        number: req.headers.number
    };
    var options = { 
        'url': config.endpoint + '/api/square',
        'form': formData,
        'headers': req.headers
    };    
    request.post(options, function(innererr, innerres, body) {
        var endDate = new Date();
        var duration = endDate - startDate;
        if (innererr){
            console.log("error:");
            console.log(innererr);
            insightsClient.trackException(innererr);
        }
        insightsClient.trackEvent("calculation-client-call-received", { value: body });
        insightsClient.trackMetric("calculation-client-call-duration", duration);
        console.log(body);
        res.send(body);
    });
    
});

app.post('/api/dummy', function(req, res) {
    console.log("received dummy request:");
    console.log(req.headers)
    insightsClient.trackEvent("dummy-data-call");
    res.send('42');
});

// Listen
var insightsClient = appInsights.getClient(config.instrumentationKey);
insightsClient.trackEvent('app-initializing');
app.listen(port);
console.log('Listening on localhost:'+ port);