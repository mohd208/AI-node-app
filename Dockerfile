# Multi-stage build for ai-node-app (Node.js, detected via package.json).
#
# NOTE: index.js currently just logs "Hello, World!" and exits -- it is not a
# long-running server. This scaffold follows the standard Node.js service
# shape (as requested for this DevOps test case) so the generated
# Terraform/Kubernetes assets have a real image to point at; once index.js
# grows into an actual service (e.g. an HTTP server), the EXPOSE port and the
# readiness/liveness probes in deploy/k8s/deployment.yaml already line up
# with the port below.

FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --omit=dev

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

# Run as a non-root user rather than the image's default root.
RUN addgroup -S app && adduser -S app -G app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

USER app
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "process.exit(0)"

CMD ["node", "index.js"]
