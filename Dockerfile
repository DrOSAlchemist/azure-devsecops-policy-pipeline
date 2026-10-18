FROM node:26-alpine@sha256:6f08a523443ddedf52941874c203475b0ad503e859ad70cb26ab8be9a517dbd5
# This dependency-free server needs Node, not the bundled package managers.
RUN rm -rf /usr/local/lib/node_modules/npm /opt/yarn-v1.22.22 \
    && rm -f /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/yarn /usr/local/bin/yarnpkg
ENV NODE_ENV=production PORT=8080
WORKDIR /app
COPY --chown=node:node package.json package-lock.json ./
COPY --chown=node:node src/ ./src/
COPY --chown=node:node public/ ./public/
USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8080/healthz').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"
CMD ["node", "src/server.js"]
