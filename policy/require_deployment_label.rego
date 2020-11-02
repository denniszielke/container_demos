package main

deny[msg] {
    input.kind == "Deployment" # true
    not input.metadata.labels.owner # true
    msg = "Deployment container must provide an owner"
}