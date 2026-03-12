# syntax=docker/dockerfile:1
FROM node:20-alpine AS build

WORKDIR /app/console

COPY console/package*.json ./
RUN npm ci

COPY console/ ./
RUN npm run build -- --configuration production

FROM nginx:alpine
COPY --from=build /app/console/dist/ /usr/share/nginx/html
