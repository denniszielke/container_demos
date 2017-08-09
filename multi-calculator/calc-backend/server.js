var express = require('express');
var app = express();
var morgan = require('morgan');

var config = require('./config');

if (config.insights){ 
    var appInsights = require('applicationinsights');   
    appInsights.setup(config.instrumentationKey).setAutoCollectRequests(true).start();
}

var port = process.env.PORT || 3001;

// add logging middleware
app.use(morgan('dev'));

// Routes
app.get('/ping', function(req, res) {
    console.log('received ping');
    res.send('Pong');
});

app.post('/api/square', function(req, res) {
    console.log("received client request:");
    console.log(req.headers);
    if (config.insights){ 
        var startDate = new Date();
        insightsClient.trackEvent("square-server-call", { value: req.headers.number });
    }
    var resultValue = 0;
    try{
        var number = parseInt(req.headers.number);
        resultValue = number * number;
    }catch(e){
        console.log(e);
        if (config.insights){ 
            insightsClient.trackException(e);
        }
        resultValue = 0;
    }
    if (config.insights){ 
        var endDate = new Date();
        var duration = endDate - startDate;
        insightsClient.trackEvent("calculation-server-call", { value: resultValue });
        insightsClient.trackMetric("calculation-call-duration", duration);
    }
    console.log(resultValue);
    res.send(resultValue.toString());
});

app.post('/api/dummy', function(req, res) {
    console.log("received dummy request:");
    console.log(req.headers)
    if (config.insights){ 
        insightsClient.trackEvent("dummy-data-call");
    }
    res.send('42');
});

// Listen
if (config.insights){ 
    var insightsClient = appInsights.getClient(config.instrumentationKey);
    insightsClient.trackEvent('app-initializing');
}
app.listen(port);
console.log('Listening on localhost:'+ port);