ARG BASE_IMAGE
FROM ${BASE_IMAGE}

USER root
COPY server.mjs /app/server.mjs
USER node

WORKDIR /workspace/group
EXPOSE 3000
CMD ["node", "/app/server.mjs"]
