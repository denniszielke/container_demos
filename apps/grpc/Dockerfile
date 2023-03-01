FROM node:alpine
RUN mkdir -p /usr/src/app
COPY ./app/* /usr/src/app/
WORKDIR /usr/src/app
RUN npm install
EXPOSE 9001
CMD node /usr/src/app/server.js