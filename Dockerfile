FROM node:22-alpine

RUN mkdir -p /opt/camo/
WORKDIR /opt/camo/

ADD package.json /opt/camo/
ADD server.js /opt/camo/
ADD mime-types.json /opt/camo/
ADD Procfile /opt/camo/

EXPOSE 8081

RUN npm install --omit=dev
USER nobody
CMD ["node", "server.js"]
