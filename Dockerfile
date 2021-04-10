FROM node:15.14.0

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install

COPY bin ./bin
COPY public ./public
COPY index.coffee ./

ENTRYPOINT ["/app/bin/tosr0x-http"]
EXPOSE 8020
