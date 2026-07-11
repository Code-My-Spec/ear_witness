# Ecto.Adapter.Queryable

Specifies the query API required from adapters.

If your adapter is only able to respond to one or a couple of the query functions,
add custom implementations of those functions directly to the Repo
by using `c:Ecto.Adapter.__before_compile__/1` instead.

## prepare_query/3

Plans and prepares a query for the given repo, leveraging its query cache.

This operation uses the query cache if one is available.

## plan_query/3

Plans a query using the given adapter.

This does not expect the repository and therefore does not leverage the cache.