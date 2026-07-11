# QA server helper — run with:
#
#     mix run --no-halt priv/repo/qa_server.exs
#
# Boots the full app (including the desktop window) and prints the
# authenticated URL. Desktop.Auth generates a fresh random key each boot;
# the first GET to /?k=<key> sets the session cookie, after which the
# session is authenticated for subsequent requests.

url = EarWitnessWeb.Endpoint.url()
key = Desktop.Auth.login_key()

IO.puts("""

=== EarWitness QA server ===
Base URL:  #{url}
Login URL: #{url}/?k=#{key}

curl session:
  curl -c /tmp/ew_cookies.txt -sS "#{url}/?k=#{key}" -o /dev/null
  curl -b /tmp/ew_cookies.txt -sS "#{url}/"

Vibium: navigate to the Login URL once, then browse normally.
============================
""")
