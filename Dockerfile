FROM mirror.gcr.io/library/node:24-bookworm-slim@sha256:a5f4366e834695d5f363b920c104953a535d3a9864d1bdf74566a0ebe01daee5 AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY svelte.config.js vite.config.ts tsconfig.json ./
COPY src src
COPY static static
COPY docs/design/assets/tokens.css docs/design/assets/tokens.css
COPY docs/design/proposal/style.css docs/design/proposal/style.css
RUN npm run build && npm prune --omit=dev

FROM mirror.gcr.io/library/node:24-bookworm-slim@sha256:a5f4366e834695d5f363b920c104953a535d3a9864d1bdf74566a0ebe01daee5 AS runner
LABEL org.opencontainers.image.source="https://github.com/deep-skill/everyday-trust"
WORKDIR /app
ENV NODE_ENV=production HOST=0.0.0.0 PORT=3000 BODY_SIZE_LIMIT=32768 ADDRESS_HEADER=x-forwarded-for XFF_DEPTH=1
COPY --from=builder --chown=node:node /app/build build
COPY --from=builder --chown=node:node /app/node_modules node_modules
COPY --from=builder /app/package.json ./
COPY --chown=node:node scripts/migrate-web.mjs scripts/start.mjs scripts/
USER node
EXPOSE 3000
CMD ["node", "scripts/start.mjs"]
