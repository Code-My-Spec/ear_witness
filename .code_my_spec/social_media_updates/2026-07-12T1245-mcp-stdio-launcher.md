# The MCP server was built — it just never got started

Story 868 gives EarWitness a local MCP surface: an AI assistant (Claude
Code, Claude Desktop) can search your transcripts and read what was said,
read-only, revocable, no network port. QA found the tools were all correct
— but nothing ever *started* the server, so no client could actually
connect. The code even had a comment resigning itself to needing "a
dedicated launch path (a release command / escript)."

Turns out, with Anubis, you basically add one line to your supervision
tree:

    {EarWitnessWeb.McpServer.Server, transport: :stdio}

The wrinkle for a *desktop* app: the stdio transport reads stdin and stops
on EOF, and a normal double-click launch has no attached client — dead
stdin would EOF-loop it. So it's gated on an env var the AI client's launch
command sets. In that mode the app boots just the DB + the MCP server over
stdin/stdout — no window, no web endpoint. Everyday launches are untouched.

Verified the honest way — piped a real `initialize` + `tools/list`
handshake straight in:

    {"result":{"serverInfo":{"name":"ear_witness","version":"1.2.0"}...}}
    {"result":{"tools":[search_transcripts, read_transcript, attach_summary]}}

A real client connects and sees exactly the three tools, then the process
exits clean on disconnect. Sometimes the "hard deferred problem" is one
supervision child and an env guard.

#buildinpublic #elixir #mcp #anthropic #claude #localfirst
