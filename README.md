# Tic Tac Toe

This Rails 8.1 application uses Ruby 3.3.6 and PostgreSQL.

Install dependencies with `bundle install`, configure PostgreSQL as needed in
`config/database.yml` or with `DATABASE_URL`, and run `bin/rails db:prepare`.
Start the app with `bin/rails server`. The homepage is at `/`, account
registration is at `/signup`, and login is at `/login`. New accounts are signed
in automatically; use Logout on the homepage to end the session. The game and
guide links are placeholders.

Login allows five attempts per IP address in a three-minute window, including
successful attempts. The limit uses a file store under `tmp/login-rate-limits`,
shared by processes on the same host; multi-host deployments must use a shared
rate-limit store.

Run the test suite with `bin/rails test`.
