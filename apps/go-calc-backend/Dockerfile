FROM golang:alpine AS builder
ARG appfolder="app"
RUN apk update && apk add --no-cache git
WORKDIR /go/src/phoenix/go-calc-backend
COPY ${appfolder}/ .
RUN go get -d -v
RUN GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o /go/bin/go-calc-backend 

FROM alpine:latest as go-calc-backend
RUN apk --no-cache add ca-certificates
RUN gouser -D -g '' gouser
RUN mkdir -p /home/gouser/app && chown -R gouser:gouser /home/gouser/app
WORKDIR /home/gouser/app
COPY --from=builder /go/bin/go-calc-backend /home/gouser/app
EXPOSE 8080
USER gouser
ENTRYPOINT ["/home/gouser/app"]