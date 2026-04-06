# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20220801-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.17.2-erlang-27.0.1-debian-bookworm-20240612-slim
#
ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=27.3.4.2
ARG DEBIAN_VERSION=bookworm-20250811-slim
ARG SELECTO_ECOSYSTEM_USE_LOCAL=false

#docker pull hexpm/elixir:1.18.4-erlang-25.0.4-debian-bullseye-20250811-slim
#docker pull hexpm/elixir:1.18.4-erlang-27.3.4.2-debian-trixie-20250811-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} as builder

ARG SELECTO_ECOSYSTEM_USE_LOCAL

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# install node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"
ENV SELECTO_ECOSYSTEM_USE_LOCAL=${SELECTO_ECOSYSTEM_USE_LOCAL}

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/

# Get all dependencies
RUN mix deps.get --only $MIX_ENV

COPY priv priv

COPY lib lib

COPY assets assets

# install npm dependencies
RUN cd assets && npm install

# Compile Elixir code, extract colocated hooks, and build digested assets
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/selecto_test ./

RUN apt-get update -y && apt-get install -y postgresql-client \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Appended by flyctl
ENV ECTO_IPV6 true
ENV ERL_AFLAGS "-proto_dist inet6_tcp"

CMD ["/app/bin/server"]
