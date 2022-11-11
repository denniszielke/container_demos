require('dotenv-extended').load();
const config = require('./config');
const appInsights = require("applicationinsights");

if (config.aicstring){ 
    appInsights.setup(config.aicstring)
    .setAutoDependencyCorrelation(true)
    .setAutoCollectRequests(true)
    .setAutoCollectPerformance(true, true)
    .setAutoCollectExceptions(true)
    .setAutoCollectDependencies(true)
    .setAutoCollectConsole(true)
    .setUseDiskRetryCaching(true)
    .setSendLiveMetrics(true)
    .setDistributedTracingMode(appInsights.DistributedTracingModes.AI_AND_W3C);
    appInsights.defaultClient.context.tags[appInsights.defaultClient.context.keys.cloudRole] = "http-frontend";
    appInsights.start();
    appInsights.defaultClient.commonProperties = {
        slot: config.version
    };
}

const swaggerUi = require('swagger-ui-express'), swaggerDocument = require('./swagger.json');

const express = require('express');
const app = express();
app.use(express.json())
const morgan = require('morgan');
const OS = require('os');
const axios = require('axios');

var publicDir = require('path').join(__dirname, '/public');

app.use(morgan('dev'));
app.use(express.static(publicDir));
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// Routes
app.get('/ping', function(req, res) {
    console.log('received ping');
    const sourceIp = req.connection.remoteAddress;
    const forwardedFrom = (req.headers['x-forwarded-for'] || '').split(',').pop();
    const pong = { response: "pong!", correlation: "", host: OS.hostname(), source: sourceIp, forwarded: forwardedFrom, version: config.version };
    console.log(pong);
    res.status(200).send(pong);
});
app.get('/healthz', function(req, res) {
    const data = {
        uptime: process.uptime(),
        message: 'Ok',
        date: new Date()
      }
    res.status(200).send(data);
});

app.get('/appInsightsConnectionString', function(req, res) {
    console.log('returned app insights connection string');
    if (config.aicstring){ 
        res.send(config.aicstring);
    }
    else{
        res.send('');
    }
});

app.post('/api/calculate', async (req, res, next) => {
    console.log("received frontend request:");
    console.log(req.headers);
    console.log(req.body);
    console.log(req.body.number);
    const requestId = req.headers['traceparent'] || '';
    let victim = false;
    var targetNumber = 0;
    const endDate = new Date();
    const remoteAddress = req.connection.remoteAddress;
    const forwardedFrom = (req.headers['x-forwarded-for'] || '').split(',').pop();

    try{
        targetNumber = req.body.number.toString();
    }catch(e){
        console.log("correlation: " + requestId);
        console.log(e);
        res.status(500).send({ timestamp: endDate, values: [ 'e', 'r', 'r'], host: OS.hostname(), remote: remoteAddress, forwarded: forwardedFrom, version: config.version });
    }

    const randomvictim = Math.floor((Math.random() * 20) + 1);
    if (config.buggy && randomvictim > 19){
        victim = true;
        console.log("request is randomly selected as victim");
    }

    if (config.cacheEndPoint){
        console.log("calling caches:");
        axios({
            method: 'get',
            url: config.cacheEndPoint + '/' + targetNumber,
            headers: {    
                'dapr-app-id': 'js-calc-frontend'
            }})
            .then(function (response) {
                console.log("received cache response:");
                console.log(response.data);
                const cacheBody = response.data;
                if (cacheBody != null && cacheBody.toString().length > 0 )
                {   
                    console.log("cache hit");
                    console.log(cacheBody);
                    const serverResult = { timestamp: endDate, correlation: requestId, values: "[" + cacheBody + "]", host: OS.hostname(), remote: "cache", forwarded: forwardedFrom, version: config.version };
                    console.log(serverResult);
                    res.status(200).send(serverResult);

                } else
                {
                    console.log("cache miss");
                    
                    axios({
                        method: 'post',
                        url: config.endpoint + '/api/calculate',
                        headers: {    
                            'Content-Type': 'application/json',
                            'dapr-app-id': 'js-calc-frontend'
                        },
                        data: {
                            number: targetNumber,
                            randomvictim: victim,
                        }})
                        .then(function (response) {
                            console.log("received backend response:");
                            console.log(response.data);
                            const appResponse = {
                                timestamp: endDate, correlation: requestId,
                                host: OS.hostname(), version: config.version, 
                                backend: { 
                                    host: response.data.host, 
                                    version: response.data.version, 
                                    values: response.data.values, 
                                    remote: response.data.remote, 
                                    timestamp: response.data.timestamp } 
                            };
                            
                            console.log("updating cache:");
                            const cacheData = '[{"key":"' + targetNumber + '","value":"'+ response.data.values.toString() + '"}]';
                            console.log(cacheData);
                            axios({
                                method: 'post',
                                url: config.cacheEndPoint,
                                headers: {    
                                    'Content-Type': 'application/json',
                                    'dapr-app-id': 'js-calc-frontend'
                                },
                                data: cacheData
                            }).then(function (response) {
                                console.log("updated cache");
                                console.log(response.data);
                            }).catch(function (error) {
                                console.log("failed to update cache:");
                                console.log(error.response.data);
                            });

                            res.status(200).send(appResponse);
        
                        }).catch(function (error) {
                            console.log("error:");
                            console.log(error);
                            const backend = { 
                                host: error.response.data.host || "frontend", 
                                version: error.response.data.version || "red", 
                                values: error.response.data.values || [ 'b', 'u', 'g'], 
                                timestamp: error.response.data.timestamp || ""
                            };
                            res.send({ backend: backend, correlation: requestId, host: OS.hostname(), version: config.version });
                        });
                }
                            
                }).catch(function (error) {
                    console.log("error:");
                    console.log(error.response);
                    console.log("data:");
                    console.log(error.response.data);
                    const backend = { 
                        host: error.response.data.host || "frontend", 
                        version: error.response.data.version || "red", 
                        values: error.response.data.values || [ 'b', 'u', 'g'], 
                        timestamp: error.response.data.timestamp || ""
                    };
                    res.send({ backend: backend, error: "looks like " + error.response.status + " from " + error.response.statusText, host: OS.hostname(), version: config.version });
                });         

    }
    else{

        axios({
            method: 'post',
            url: config.endpoint + '/api/calculate',
            headers: {    
                'Content-Type': 'application/json',
                'dapr-app-id': 'js-calc-frontend'
            },
            data: {
                number: targetNumber,
                randomvictim: victim,
            }})
            .then(function (response) {
                console.log("received backend response:");
                console.log(response.data);
                const appResponse = {
                    timestamp: endDate, correlation: requestId,
                    host: OS.hostname(), 
                    version: config.version, 
                    backend: { 
                        host: response.data.host, 
                        version: response.data.version, 
                        values: response.data.values, 
                        remote: response.data.remote, 
                        timestamp: response.data.timestamp } 
                };
                res.send(appResponse);
            }).catch(function (error) {
                console.log("error:");
                console.log(error.response);
                console.log("data:");
                console.log(error.response.data);
                const backend = { 
                    timestamp: endDate, correlation: requestId,
                    host: error.response.data.host || "frontend", 
                    version: error.response.data.version || "red", 
                    values: error.response.data.values || [ 'b', 'u', 'g'], 
                    timestamp: error.response.data.timestamp || ""
                };
                res.send({ backend: backend, error: "looks like " + error.response.status + " from " + error.response.statusText, host: OS.hostname(), version: config.version });
            });
    }
    
});

app.post('/api/dummy', function(req, res) {
    console.log("received dummy request:");
    console.log(req.headers);
    res.send({ values: "[ 42 ]", host: OS.hostname(), version: config.version });
});

console.log(config);
console.log(OS.hostname());
app.listen(config.port);
console.log('Listening on localhost:'+ config.port);