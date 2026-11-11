# syntax=docker/dockerfile:1
FROM nginxinc/nginx-unprivileged:1.31.7-alpine@sha256:b5047b9b76845eac124358373c6852377c52e4b05834a47647e955dd91cb8f1e

# Patch Alpine packages the base image shipped with known fixes for.
USER root
RUN apk upgrade --no-cache

COPY nginx.conf /etc/nginx/conf.d/default.conf

# The image already runs as UID 101 and listens on 8080; stated here so it is visible.
USER 101:101
EXPOSE 8080
