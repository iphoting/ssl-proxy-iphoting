FROM node:22-alpine

WORKDIR /opt/camo/

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY server.js mime-types.json ./

EXPOSE 8081

USER nobody
CMD ["node", "server.js"]
