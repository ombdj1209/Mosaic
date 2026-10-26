FROM ruby:3.4.4-slim
RUN apt-get update -qq && apt-get install -y --no-install-recommends build-essential libpq-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile* ./
RUN bundle install
COPY . .
EXPOSE 4100
CMD ["bundle", "exec", "puma", "-p", "4100", "config.ru"]
