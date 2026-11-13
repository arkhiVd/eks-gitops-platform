# syntax=docker/dockerfile:1
FROM python:3.15.2-slim@sha256:65a65fc7b30b06cb6df4930fd4650697cb23f4c2698ab81fc87e4b031bc36928

ARG APP_VERSION=dev
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 APP_VERSION=${APP_VERSION}

# Patch OS packages, then drop pip and setuptools: the service uses only the standard
# library, and their vendored packages carried the HIGH CVEs trivy found in the base image.
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && rm -rf /var/lib/apt/lists/* \
 && python -m pip uninstall -y pip setuptools wheel \
 && rm -rf /root/.cache
WORKDIR /app
COPY server.py .

# Fixed non-root UID so the pod securityContext can require it.
USER 10001:10001
EXPOSE 8081
ENTRYPOINT ["python", "server.py"]
