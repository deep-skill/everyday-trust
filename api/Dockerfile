FROM mirror.gcr.io/library/elixir:1.18.4-otp-27-slim@sha256:128392372efd16c43a44808f49045f9999e749bb7a25ebd5b22a7523e8cbac17 AS tools
RUN apt-get update -qq && apt-get install -y --no-install-recommends ca-certificates build-essential git && rm -rf /var/lib/apt/lists/*
ENV ERL_FLAGS="+S 2:2"
WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force

FROM tools AS development
CMD ["sleep", "infinity"]

FROM tools AS builder
ENV MIX_ENV=prod
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod --check-locked && mix deps.compile
COPY lib lib
COPY priv priv
RUN mix compile --warnings-as-errors && mix release

FROM mirror.gcr.io/library/elixir:1.18.4-otp-27-slim@sha256:128392372efd16c43a44808f49045f9999e749bb7a25ebd5b22a7523e8cbac17 AS runner
LABEL org.opencontainers.image.source="https://github.com/deep-skill/everyday-trust"
RUN apt-get update -qq && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/* && useradd --uid 10001 --create-home trust
WORKDIR /app
COPY --from=builder --chown=trust:trust /app/_build/prod/rel/everyday_trust ./
ENV MIX_ENV=prod RELEASE_DISTRIBUTION=none RELEASE_TMP=/tmp ERL_FLAGS="+S 2:2"
USER trust
EXPOSE 4000
CMD ["bin/everyday_trust", "start"]
