#!/bin/bash
# Authenticated curl against the running EarWitness app. Establish the session first:
#   ./qa_login.sh <LOGIN_KEY>   (key printed by: mix run --no-halt priv/repo/qa_server.exs)
# Then: ./authenticated_curl.sh /some/path
curl -b /tmp/ew_cookies.txt -sS "http://localhost:${EARWITNESS_PORT:-4848}$1"
