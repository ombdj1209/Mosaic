# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.4
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base
WORKDIR /rails
RUN apt-get update -qq && apt-get install --no-install-recommends -y curl libjemalloc2 libpq5 && rm -rf /var/lib/apt/lists/*
ENV RAILS_ENV="production" BUNDLE_DEPLOYMENT="1" BUNDLE_PATH="/usr/local/bundle" BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"

FROM base AS build
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config libyaml-dev && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock* ./
RUN bundle install && rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache && bundle exec bootsnap precompile --gemfile
COPY . .
RUN bundle exec bootsnap precompile app/ lib/ packs/ && SECRET_KEY_BASE_DUMMY=1 MOSAIC_KEK_CURRENT=AAAA MOSAIC_BLIND_INDEX_KEY=AAAA ./bin/rails assets:precompile

FROM base
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails
RUN groupadd --system --gid 1000 rails && useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp 2>/dev/null || true
USER 1000:1000
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
