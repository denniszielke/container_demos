var config = {}

config.instrumentationKey = process.env.INSTRUMENTATIONKEY;
config.port = process.env.PORT || 8080;

module.exports = config;
