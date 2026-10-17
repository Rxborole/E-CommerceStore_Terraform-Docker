FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY --chown=node:node server.js ./
COPY --chown=node:node models ./models
COPY --chown=node:node routes ./routes

USER node
EXPOSE 3002
CMD ["node", "server.js"]
