FROM node:22.14.0

WORKDIR /app

RUN corepack enable

# Install dependencies (copy manifests first for layer caching)
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY patches/ ./patches/
COPY workspaces/client/package.json ./workspaces/client/
COPY workspaces/server/package.json ./workspaces/server/
COPY workspaces/schema/package.json ./workspaces/schema/
COPY workspaces/configs/package.json ./workspaces/configs/

RUN pnpm install --frozen-lockfile

# Build
COPY . .
RUN WIREIT_CACHE=none pnpm run build

ENV PORT=8000
ENV API_BASE_URL=http://localhost:8000/api

EXPOSE 8000

WORKDIR /app/workspaces/server
CMD ["node_modules/.bin/tsx", "-r", "./loaders/png.cjs", "./src/index.ts"]
