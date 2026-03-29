# ---- Estágio 1: Build ----
FROM elixir:1.19.5-otp-28-alpine AS builder

RUN apk add --no-cache \
    build-base \
    git \
    npm \
    nodejs

WORKDIR /app

COPY mix.exs mix.lock ./
COPY config config

ENV MIX_ENV=prod
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod && \
    mix deps.compile

COPY assets assets
COPY priv priv
COPY lib lib

RUN mix assets.deploy
RUN mix compile
RUN mix release

# ---- Estágio 2: Runtime ----
FROM elixir:1.19.5-otp-28-alpine AS runtime

# Remove mix/hex desnecessários, mantém apenas o runtime
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    openssl-dev \
    ncurses-libs && \
    mix local.hex --force

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/w_core ./

RUN mkdir -p /app/data

ENV PHX_HOST=localhost
ENV PORT=4000
ENV DATABASE_PATH=/app/data/w_core_prod.db
ENV SECRET_KEY_BASE=SUBSTITUA_POR_UMA_CHAVE_SEGURA_DE_64_CARACTERES

EXPOSE 4000

CMD ["bin/w_core", "start"]