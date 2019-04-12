FROM node:alpine
RUN mkdir -p /usr/src/app
COPY ./app/* /usr/src/app/
WORKDIR /usr/src/app
RUN npm install
EXPOSE 8080
CMD [ "npm", "start" ]
