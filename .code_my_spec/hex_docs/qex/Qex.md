# Qex



## new/1

Create a new queue from a range

    iex> inspect Qex.new(1..3)
    "#Qex<[1, 2, 3]>"

Create a new queue from a list

    iex> inspect Qex.new([1, 2, 3])
    "#Qex<[1, 2, 3]>"

## push/2

Add an element to the back of the queue

    iex> q = Qex.new([:mid])
    iex> Enum.to_list Qex.push(q, :back)
    [:mid, :back]

## push_front/2

Add an element to the front of the queue

    iex> q = Qex.new([:mid])
    iex> Enum.to_list Qex.push_front(q, :front)
    [:front, :mid]

## pop/1

Get and remove an element from the front of the queue

    iex> q = Qex.new([:front, :mid])
    iex> {{:value, item}, _q} = Qex.pop(q)
    iex> item
    :front

    iex> q = Qex.new
    iex> {empty, _q} = Qex.pop(q)
    iex> empty
    :empty

## pop_back/1

Get and remove an element from the back of the queue

    iex> q = Qex.new([:mid, :back])
    iex> {{:value, item}, _q} = Qex.pop_back(q)
    iex> item
    :back

    iex> q = Qex.new
    iex> {empty, _q} = Qex.pop_back(q)
    iex> empty
    :empty

## reverse/1

Reverse a queue

    iex> q = Qex.new(1..3)
    iex> Enum.to_list q
    [1, 2, 3]
    iex> Enum.to_list Qex.reverse(q)
    [3, 2, 1]

## split/2

Split a queue into two, the front n items are put in the first queue

    iex> q = Qex.new 1..5
    iex> {q1, q2} = Qex.split(q, 3)
    iex> Enum.to_list q1
    [1, 2, 3]
    iex> Enum.to_list q2
    [4, 5]

## join/2

Join two queues together

    iex> q1 = Qex.new 1..3
    iex> q2 = Qex.new 4..5
    iex> Enum.to_list Qex.join(q1, q2)
    [1, 2, 3, 4, 5]

## first/1

Return the first item in the queue in {:value, term} tuple,
return :empty if the queue is empty

    iex> q1 = Qex.new 1..3
    iex> Qex.first(q1)
    {:value, 1}
    iex> q2 = Qex.new []
    iex> Qex.first(q2)
    :empty

## first!/1

Return the first item in the queue, raise if it's empty

    iex> q1 = Qex.new 1..3
    iex> Qex.first!(q1)
    1

## last/1

Return the last item in the queue in {:value, term} tuple,
return :empty if the queue is empty

    iex> q1 = Qex.new 1..3
    iex> Qex.last(q1)
    {:value, 3}
    iex> q2 = Qex.new []
    iex> Qex.last(q2)
    :empty

## last!/1

Return the last item in the queue, raise if it's empty

    iex> q1 = Qex.new 1..3
    iex> Qex.last!(q1)
    3

## len/1

Return the number of elements in the queue.
This operation takes linear time.

    iex> q1 = Qex.new 1..3
    iex> Qex.len(q1)
    3