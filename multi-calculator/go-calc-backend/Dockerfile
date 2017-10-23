FROM golang:latest 
RUN mkdir -p /usr/src/app
COPY ./app/* /usr/src/app/
WORKDIR /usr/src/app
RUN go build -o main . 
CMD ["/usr/src/app/main"]