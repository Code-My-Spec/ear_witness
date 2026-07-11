# Debouncer

Debouncer executes a function call debounced. Debouncing is done one a per key basis:

```
Debouncer.apply(Key, fn() -> IO.puts("Hello World, debounced") end)
```

The third optional parameter is the timeout period in milliseconds

```
Debouncer.apply(Key, fn() -> IO.puts("Hello World, once per minute max") end, 60_000)
```

The variants supported are:

* `apply/3`      => Events are executed after the timeout
* `immediate/3`  => Events are executed immediately, and further events are delayed for the timeout
* `immediate2/3` => Events are executed immediately, and further events are IGNORED for the timeout
* `delay/3`      => Each event delays the execution of the next event

```
EVENT        X1---X2------X3-------X4----------
TIMEOUT      ----------|----------|----------|-
===============================================
apply()      ----------X2---------X3---------X4
immediate()  X1--------X2---------X3---------X4
immediate2() X1-----------X3-------------------
delay()      --------------------------------X4
```

## immediate/3

Executes the function immediately but blocks any further call
under the same key for the given timeout.

## immediate2/3

Executes the function immediately but ignores further calls
under the same key for the given timeout.

## delay/3

Executes the function after the specified timeout t0 + timeout,
when delay is called multipe times the timeout is reset based on the
most recent call (t1 + timeout, t2 + timeout) etc... the fun is also updated

## apply/3

Executes the function after the specified timeout t0 + timeout,
when apply is called multiple times it does not affect the point
in time when the next call is happening (t0 + timeout) but updates the fun

## cancel/1

Deletes the latest event if it hasn't triggered yet.

## worker/1

Returns the pid of an active job worker or nil if no such job is scheduled.
Per key the debouncer never starts more than one process at the same time.

## workers/0

Returns a map of all active job workers.