FROM ruby:3.2.0-slim-bullseye
WORKDIR /app
COPY rails_api/Gemfile .
COPY rails_api/Gemfile.lock .

RUN gem install bundler -v "$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -n 1)"
RUN apt update && apt install -y curl build-essential less ca-certificates unzip groff default-libmysqlclient-dev && apt clean
RUN bundle install --jobs 20 --retry 5
COPY rails_api/ .

