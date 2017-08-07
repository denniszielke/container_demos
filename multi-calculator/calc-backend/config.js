var config = {}

config.instrumentationKey = process.env.INSTRUMENTATIONKEY;
config.noInsights = process.env.NOINSIGHTS || false;

module.exports = config;
