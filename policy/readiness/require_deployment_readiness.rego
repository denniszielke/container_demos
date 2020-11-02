package main

import data.k8s.matches

deny[msg] {
    input.kind == "Deployment" # true
    not input.spec.template.spec.containers[0].livenessProbe # true
    msg = "Deployment container must provide an owner"
}