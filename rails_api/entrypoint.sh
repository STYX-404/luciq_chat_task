#! /bin/bash
bundle exec rails db:prepare

rm /app/tmp/pids/server.pid

puma -C config/puma.rb
