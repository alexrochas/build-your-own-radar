FROM node:7.10.1 as source
WORKDIR /src/build-your-own-radar
COPY package.json ./
RUN npm install
COPY . ./
CMD npm run dev
