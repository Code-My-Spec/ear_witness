#!/bin/bash
# Establish the QA session cookie. Usage: ./qa_login.sh <LOGIN_KEY>
curl -c /tmp/ew_cookies.txt -sS -o /dev/null -w "login: %{http_code}\n" "http://localhost:${EARWITNESS_PORT:-4848}/?k=$1"
