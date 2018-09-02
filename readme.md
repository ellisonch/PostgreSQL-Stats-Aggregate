# PostgreSQL Stats Aggregate (stats_agg)

`stats_agg` is an aggregate function for PostgreSQL that works like pre-existing aggregates (`min(x)`, `max()`, `avg()`, etc.), but computes multiple stats at once and returns them all. The stats returned are `count`, `min`, `max`, `mean`, `variance`, `skewness`, and `kurtosis`, though others could be added.

I needed an aggregate returning skewness and kurtosis, and instead of making separate functions for each requiring multiple passes to compute the mean etc., I thought it would be better to have one aggregate that returns everything in one pass.

Thanks to John D. Cook and [his blog post](https://www.johndcook.com/blog/skewness_kurtosis/) explaining how this could be done.

Tested on PostgreSQL 9.6.6.

## Installation
Just run the `pg_stats_aggregate.sql` file.  This will create a new aggregate function `stats_agg(double precision)` that returns a row type of basic stats.

## Examples
If you just want one of the results, you can grab it:
```sql
with data as (
	select unnest(array[1, 2, 3, 4, 5, 10, 20]) n
)
select (stats_agg(n)).skewness from data
-- "skewness"
-- 1.3687777084534
```
Or, because it returns all the stats as a row, you can get the results as separate columns and do things with them.
```sql
with data as (
	select unnest(array[1, 2, 3, 4, 5, 10, 20]) n
)
select (stats_agg(n)).* from data
-- "count";"min";"max";"mean";"variance";"skewness";"kurtosis"
-- 7;1;20;6.42857142857143;44.2857142857143;1.3687777084534;0.521266042317031
```