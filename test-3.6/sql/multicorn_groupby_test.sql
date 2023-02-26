SET client_min_messages=NOTICE;

CREATE FUNCTION costly_business(arg character varying, other_arg character varying) RETURNS character varying AS $$
BEGIN
  RAISE EXCEPTION 'This must be done by FDW!';
END;
$$ LANGUAGE plpgsql COST 200;

CREATE AGGREGATE public.push_me_down(arg character varying) (
  SFUNC = costly_business,
  STYPE = character varying
);

CREATE EXTENSION multicorn;
CREATE server multicorn_srv foreign data wrapper multicorn options (
    wrapper 'multicorn.testfdw.TestForeignDataWrapper'
);

CREATE foreign table testmulticorn (
    test1 character varying,
    test2 character varying
) server multicorn_srv options (
    option1 'option1',
    pushdown_upper_rel 'true'
);
-- query without upper rel
select test1 from testmulticorn WHERE test1 = 'test1 1 0';
-- simple group by
select test1 from testmulticorn GROUP BY test1;
-- supported agg
select push_me_down(test2) from testmulticorn GROUP BY test1;
-- supported agg with single result
select push_me_down(test2) from testmulticorn;
-- grouped column and aggregation mixed results
select test1, push_me_down(test2) from testmulticorn GROUP BY test1;
-- missing column in select
select test1 from testmulticorn GROUP BY test1, test2;
-- supported qual filter
select push_me_down(test2) from testmulticorn WHERE test1 = 'test1 1 0' GROUP BY test1;

-- Unsupported aggregation function
select test1, array_agg(test2) from testmulticorn GROUP BY test1 ORDER BY 2;
-- Unsupported qual operation
select test1, push_me_down(test2) from testmulticorn WHERE test2 > 'test2 2 9' GROUP BY test1;
-- having clause
select test1, push_me_down(test2) from testmulticorn GROUP BY test1 HAVING push_me_down(test2) = '#synth_column.0 2 0';

DROP EXTENSION multicorn cascade;
DROP AGGREGATE public.push_me_down(arg character varying);
DROP FUNCTION costly_business(arg character varying, other_arg character varying);
