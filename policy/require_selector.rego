package main

deny[msg] {
    input.kind == "Deployment" # true
    not input.spec.selector.matchLabels.app # false
    msg = "Containers must provide app label for pod selectors"
}