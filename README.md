# Tic Tac Toe

This Rails 8.1 application uses Ruby 3.3.6 and PostgreSQL.

Install dependencies with `bundle install`, configure PostgreSQL as needed in
`config/database.yml` or with `DATABASE_URL`, and run `bin/rails db:prepare`.
Set `POSTGRES_PASSWORD` in the environment even when using `DATABASE_URL`;
`DB_USERNAME` and `POSTGRES_HOST` override the default user and host.
Start the app with `bin/rails server`. The homepage is at `/`, account
registration is at `/signup`, and login is at `/login`. New accounts are signed
in automatically; use Logout on the homepage to end the session.

Signed-in users can choose **Play a Friend** to host a room and share its
eight-character code, or join a room with a code. The server validates and
synchronizes moves. X is assigned randomly for the first game, and players
swap marks after both request a rematch. Play pauses when either player is
disconnected. Each room reserves two user slots, including
while a player is disconnected. A room closes after both players have been
disconnected for 10 seconds, and all rooms are lost when the server restarts.
The countdown starts when the server detects the last disconnection, which may
take longer for an unexpected network outage.
Room state is in memory, so use a single server process.

To try this from two computers, start Rails with `bin/rails server -b 0.0.0.0`
on a trusted network, open the host computer's network address and port 3000
on each computer, and sign in with different accounts. Host a room on one
computer and enter the code on the other. The lobby shows each player's
connection status. Do not expose the development server to the public internet.

Login allows five attempts per IP address in a three-minute window, including
successful attempts. The limit uses a file store under `tmp/login-rate-limits`,
shared by processes on the same host; multi-host deployments must use a shared
rate-limit store.

Run the test suite with `bin/rails test`.
