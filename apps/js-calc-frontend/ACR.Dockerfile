ARG appfolder="apps/js-calc-frontend/app"
FROM node:alpine
ENV NPM_CONFIG_PREFIX=/home/node/.npm-global
ENV NODE_ENV=production
RUN mkdir -p /usr/src/app
COPY ${appfolder}/* /usr/src/app/
WORKDIR /usr/src/app
RUN npm install
EXPOSE 8080
CMD [ "npm", "start" ]