# Toml.Lexer



## pop/1

Pops the next token from the lexer. This advances the lexer to the next token.

## advance/1

Advances the lexer to the next token, without returning the current token on the stack,
effectively skipping the current token.

## peek/1

Peeks at the next token the lexer will return from `pop/1`.

Always returns the same result until the lexer advances.

## push/2

Pushes a token back on the lexer's stack.

You may push as many tokens back on the stack as desired.

## pos/1

Retrieves the position of the lexer in the current input

## stop/1

Terminates the lexer process.

## stream/1

Converts the lexer in to a `Stream`. Not currently used.