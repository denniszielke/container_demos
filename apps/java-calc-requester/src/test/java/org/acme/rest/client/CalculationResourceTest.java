// package org.acme.rest.client;

// import static io.restassured.RestAssured.given;
// import static org.hamcrest.CoreMatchers.hasItem;
// import static org.hamcrest.CoreMatchers.is;
// import static org.hamcrest.Matchers.greaterThan;

// import org.junit.jupiter.api.Test;

// import org.acme.rest.client.*;
// import org.acme.rest.client.resources.WireMockExtensions;

// import io.quarkus.test.common.QuarkusTestResource;
// import io.quarkus.test.junit.QuarkusTest;

// @QuarkusTest
// @QuarkusTestResource(WireMockExtensions.class)
// public class CalculationResourceTest {

//     @Test
//     public void testExtensionsIdEndpoint() {
//         given()
//             .when().get("/extension/id/io.quarkus:quarkus-rest-client")
//             .then()
//             .statusCode(200)
//             .body("$.size()", is(1),
//                 "[0].id", is("io.quarkus:quarkus-rest-client"),
//                 "[0].name", is("REST Client"),
//                 "[0].keywords.size()", greaterThan(1),
//                 "[0].keywords", hasItem("rest-client"));
//     }
// }