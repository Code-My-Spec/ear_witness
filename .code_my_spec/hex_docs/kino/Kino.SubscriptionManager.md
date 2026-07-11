# Kino.SubscriptionManager



## start_link/1

Starts the manager.

## subscribe/4

Subscribes the given process to events under `topic`.

All events are sent as `{tag, info}`, where `tag` is
the given term used for identifying the messages.

## Options

  * `:notify_clear` - when set to true, sends
    `{tag, :topic_cleared, topic}` when topic is removed

## unsubscribe/2

Unsubscribes the given process from events under `topic`.