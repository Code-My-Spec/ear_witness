# Anubis.Logging



## message/5

Log protocol messages with automatic formatting and context.

## Parameters
  * direction - "incoming" or "outgoing"
  * type - message type (e.g., "request", "response", "notification", "error")
  * id - message ID (can be nil)
  * data - the message content
  * metadata - additional metadata to include with level option (:debug, :info, :warning, :error, etc.)

## server_event/3

Log server events with structured format.

## Options
  * metadata - Additional metadata including:
    * :level - The log level (:debug, :info, :warning, :error, etc.)

## client_event/3

Log client events with structured format.

## Options
  * metadata - Additional metadata including:
    * :level - The log level (:debug, :info, :warning, :error, etc.)

## transport_event/3

Log transport events with structured format.

## Options
  * metadata - Additional metadata including:
    * :level - The log level (:debug, :info, :warning, :error, etc.)