package org.acme.rest.client;

import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.resteasy.annotations.jaxrs.PathParam;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.ThreadLocalRandom;
import javax.inject.Inject;
import javax.ws.rs.GET;
import javax.ws.rs.Path;
import java.util.Random;
import java.util.HashMap;
import java.util.Map;
import org.jboss.logging.Logger;

@Path("/api")
public class CalculationResource {

    @Inject
    @RestClient
    CalculationService calculationService;

    // // @AutoWired
    // // TelemetryClient telemetryClient;
    // static final TelemetryClient telemetryClient = new TelemetryClient();

    @Inject
    Logger log;

    @GET
    @Path("/ping")
    public Boolean ping() {
        return true;
    }
    
    @GET
    @Path("/trigger/{count}")
    public Boolean trigger(@PathParam Integer count) {
        Random rand = new Random();

        log.info("received trigger for " + count + " requests.");

        for (int i = 0; i < count; i++) {
            Integer randInt = rand.nextInt(1000);
            String randString = randInt.toString();
            CalculationResponse response = calculationService.Calculate(randString, false);
            log.info("received trigger response for " + response.toString() + ".");
        }
        
        // Map<String, String> properties = new HashMap<>();
        // properties.put("properties", "PROPERTIES OF PROPERTIES");

        // Map<String, Double> metrics = new HashMap<>();
        // metrics.put("metrics", 10.0);
        // telemetryClient.trackEvent("telemetryClient trackEvent test", properties, metrics);
        // Boolean isdisabled = telemetryClient.isDisabled();
        // telemetryClient.flush();
        return true;
    }

    @GET
    @Path("/triggerasync/{count}")
    public CompletionStage<CalculationResponse> triggerAsync(@PathParam Integer count) {
        Random rand = new Random();
        Integer randInt = rand.nextInt(1000);
        String randString = randInt.toString();

        log.info("received trigger async for " + count + " requests.");

        for (int i = 0; i < count; i++) {
            CompletionStage<CalculationResponse> response = calculationService.CalculateAsync(randString, false);
            log.info("received trigger async response for " + response.toString() + ".");
            randInt = rand.nextInt(1000);
            randString = randInt.toString();
        }
        
        CompletionStage<CalculationResponse> response = calculationService.CalculateAsync(randString, false);
        System.out.println(response.toString());

        return response;
    }
}