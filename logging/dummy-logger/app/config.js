var config = {}

config.port = process.env.PORT || 80;
config.metricReset = process.env.METRICRESET || 2;

module.exports = config;
