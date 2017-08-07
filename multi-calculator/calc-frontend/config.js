var config = {}

config.endpoint = process.env.ENDPOINT;
config.instrumentationKey = process.env.INSTRUMENTATIONKEY;
config.noInsights = process.env.NOINSIGHTS || false;

module.exports = config;
