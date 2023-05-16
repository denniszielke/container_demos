package qdapr.acme;

import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.HEAD;
import jakarta.ws.rs.DELETE;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import java.util.Set;

@Path("/extensions")
@RegisterRestClient(configKey = "invoke")
public interface InvokeService {

    @GET
    @Path("/messages")
    Set<String> all();

    @GET
    @Path("/messages/{id}")
    Set<String> getById(@PathParam("id") String stream);

    @HEAD
    @Path("/messages/{id}")
    Set<String> headById(@PathParam("id") String stream);

    @POST
    @Path("/messages/{id}")
    Set<String> postById(@PathParam("id") String stream);

    @DELETE
    @Path("/messages/{id}")
    Set<String> deleteById(@PathParam("id") String stream);
}
