--A. Pizza Metrics
--How many pizzas were ordered?
select 
  count(*) 
from 
  customer_orders;
--How many unique customer orders were made?
select 
  count(distinct customer_id) as customers 
from 
  customer_orders;
--How many successful orders were delivered by each runner?
select 
  runner_id, 
  count(distinct order_id) as complete_orders 
from 
  runner_orders 
where 
  trim(cancellation) is null 
  or trim(cancellation)= 'null' 
  or trim(cancellation)= '' 
group by 
  runner_id;
--How many of each type of pizza was delivered?
select 
  pizza_name, 
  count(*) as pizzas_orders 
from 
  customer_orders as co 
  inner join pizza_names as pn on pn.pizza_id = co.pizza_id 
  inner join runner_orders as ro on ro.order_id = co.order_id 
where 
  trim(cancellation) is null 
  or trim(cancellation)= 'null' 
  or trim(cancellation)= '' 
group by 
  pizza_name;
--How many Vegetarian and Meatlovers were ordered by each customer?
select 
  customer_id, 
  pizza_name, 
  count(*) as pizzas_orders 
from 
  customer_orders as co 
  inner join pizza_names as pn on pn.pizza_id = co.pizza_id 
where 
  pizza_name = 'Vegetarian' 
  or pizza_name = 'Meatlovers' 
group by 
  customer_id, 
  pizza_name 
order by 
  customer_id desc;
--What was the maximum number of pizzas delivered in a single order?
with Max_delivered as (
  select 
    co.order_id, 
    count(*) as pizzas_orders 
  from 
    customer_orders as co 
    inner join runner_orders as ro on ro.order_id = co.order_id 
  where 
    trim(cancellation) is null 
    or trim(cancellation)= 'null' 
    or trim(cancellation)= '' 
  group by 
    co.order_id 
  order by 
    pizzas_orders desc
) 
select 
  max(pizzas_orders) as largest_delivery 
from 
  max_delivered;
--For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT 
  co.customer_id, 
  iff(
    CASE WHEN TRIM(exclusions) = 'null' THEN 0 WHEN TRIM(exclusions) = '' THEN 0 WHEN TRIM(exclusions) IS NULL THEN 0 ELSE 1 END + CASE WHEN TRIM(extras) = 'null' THEN 0 WHEN TRIM(extras) = '' THEN 0 WHEN TRIM(extras) IS NULL THEN 0 ELSE 1 END = 0, 
    false, 
    true
  ) AS alteration, 
  COUNT(*) AS pizzas_orders 
FROM 
  customer_orders AS co 
  inner join runner_orders as ro on ro.order_id = co.order_id 
where 
  trim(cancellation) is null 
  or trim(cancellation)= 'null' 
  or trim(cancellation)= '' 
group by 
  co.customer_id, 
  alteration 
order by 
  customer_id asc;
--How many pizzas were delivered that had both exclusions and extras?
SELECT 
  iff(
    CASE WHEN TRIM(exclusions) = 'null' THEN 0 WHEN TRIM(exclusions) = '' THEN 0 WHEN TRIM(exclusions) IS NULL THEN 0 ELSE 1 END || CASE WHEN TRIM(extras) = 'null' THEN 0 WHEN TRIM(extras) = '' THEN 0 WHEN TRIM(extras) IS NULL THEN 0 ELSE 1 END = '11', 
    true, 
    false
  ) AS extra_exclusion_alteration, 
  COUNT(*) AS pizzas_orders 
FROM 
  customer_orders AS co 
  inner join runner_orders as ro on ro.order_id = co.order_id 
where 
  trim(cancellation) is null 
  or trim(cancellation)= 'null' 
  or trim(cancellation)= '' 
group by 
  extra_exclusion_alteration;
--What was the total volume of pizzas ordered for each hour of the day?
select 
  hour(order_time) as "Hour", 
  count(*) as orders 
from 
  customer_orders as co 
group by 
  "Hour";
--What was the volume of orders for each day of the week?*/
select 
  dayofweek(order_time) as "Day", 
  count(*) as orders 
from 
  customer_orders as co 
group by 
  "Day";
