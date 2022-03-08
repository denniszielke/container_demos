package org.acme.rest.client;

import java.util.List;

public class CalculationResponse {

    public String timestamp;
    public String value;
    public String error;
    public String host;
    public String remote;

    public String toString() {
        return this.timestamp + " " + this.value + " " + this.host + " " + this.remote + " " + this.error;
    }

}