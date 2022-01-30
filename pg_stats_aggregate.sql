-- Copyright (c) 2018 Chucky Ellison <cme at freefour.com>
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation 
-- files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
-- modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
-- WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
-- COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
-- ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

-- based on code from John D. Cook's https://www.johndcook.com/blog/skewness_kurtosis/ with permission

-- Notes:
-- All the math is done at double precision; can easily be changed to work with numeric or single, or whatever.
-- Kurtosis and skewness are NOT corrected for statistical bias

--------------------------------------------------
-- MAKE SURE you're not using any of these names!

-- drop aggregate if exists stats_agg(double precision);
-- drop function if exists _stats_agg_accumulator(_stats_agg_accum_type, double precision);
-- drop function if exists _stats_agg_finalizer(_stats_agg_accum_type);
-- drop type if exists _stats_agg_result_type;
-- drop type if exists _stats_agg_accum_type;

create type _stats_agg_accum_type AS (
	n bigint,
	min double precision,
	max double precision,
	m1 double precision,
	m2 double precision,
	m3 double precision,
	m4 double precision
);

create type _stats_agg_result_type AS (
	count bigint,
	min double precision,
	max double precision,
	mean double precision,
	variance double precision,
	skewness double precision,
	kurtosis double precision
);

create or replace function _stats_agg_accumulator(_stats_agg_accum_type, double precision)
returns _stats_agg_accum_type AS '
DECLARE
	a ALIAS FOR $1;
	x alias for $2;
	n1 bigint;
	delta double precision;
	delta_n double precision;
	delta_n2 double precision;
	term1 double precision;
BEGIN
	if x IS NOT NULL then
		n1 = a.n;
		a.n = a.n + 1;
		delta = x - a.m1;
		delta_n = delta / a.n;
		delta_n2 = delta_n * delta_n;
		term1 = delta * delta_n * n1;
		a.m1 = a.m1 + delta_n;
		a.m4 = a.m4 + term1 * delta_n2 * (a.n*a.n - 3*a.n + 3) + 6 * delta_n2 * a.m2 - 4 * delta_n * a.m3;
		a.m3 = a.m3 + term1 * delta_n * (a.n - 2) - 3 * delta_n * a.m2;
		a.m2 = a.m2 + term1;
		a.min = least(a.min, x);
		a.max = greatest(a.max, x);
	end if;
	
	RETURN a;
END;
'
language plpgsql;

create or replace function _stats_agg_finalizer(_stats_agg_accum_type)
returns _stats_agg_result_type AS '
BEGIN
	RETURN row(
		$1.n, 
		$1.min,
		$1.max,
		$1.m1,
		$1.m2 / nullif(($1.n - 1.0), 0), 
		case when $1.m2 = 0 then null else sqrt($1.n) * $1.m3 / nullif(($1.m2 ^ 1.5), 0) end, 
		case when $1.m2 = 0 then null else $1.n * $1.m4 / nullif(($1.m2 * $1.m2) - 3.0, 0) end
	);
END;
'
language plpgsql;

create aggregate stats_agg(double precision) (
	sfunc = _stats_agg_accumulator,
	stype = _stats_agg_accum_type,
	finalfunc = _stats_agg_finalizer,
	initcond = '(0,,, 0, 0, 0, 0)'
);
