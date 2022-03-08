package org.acme.rest.client;

import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;
import org.jboss.resteasy.annotations.jaxrs.HeaderParam;

import javax.ws.rs.POST;
import javax.ws.rs.Path;

import java.util.concurrent.CompletionStage;

@Path("/api")
@RegisterRestClient(configKey="calculation-api")
public interface CalculationService {

    @POST
    @Path("/calculation")
    CalculationResponse Calculate(@HeaderParam String number, @HeaderParam Boolean victim);

    @POST
    @Path("/calculation")
    CompletionStage<CalculationResponse> CalculateAsync(@HeaderParam String number, @HeaderParam Boolean victim);
}