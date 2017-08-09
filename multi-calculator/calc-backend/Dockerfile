FROM node:8.2.0-alpine
RUN mkdir -p /usr/src/app
COPY . /usr/src/app
WORKDIR /usr/src/app
RUN npm install
EXPOSE 3001
CMD [ "npm", "start" ]
