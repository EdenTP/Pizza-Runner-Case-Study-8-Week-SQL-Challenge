--C. Ingredient Optimisation
-- What are the standard ingredients for each pizza?
select 
  pizza_name, 
  topping_name 
from 
  pizza_names as pn 
  inner join pizza_recipes as pr on pn.pizza_id = pr.pizza_id 
  left join lateral split_to_table(toppings, ',') as S 
  left join pizza_toppings as pt on pt.topping_id = trim(s.value);
-- What was the most commonly added extra?
select 
  topping_name, 
  count(*) as ordered 
from 
  customer_orders 
  left join lateral split_to_table(extras, ',') as ext 
  left join pizza_toppings as pt on pt.topping_id = trim(ext.value) 
where 
  trim(extras) is not null 
  and trim(extras) != 'null' 
  and trim(extras) != '' 
group by 
  topping_name;
-- What was the most common exclusion?
select 
  topping_name, 
  count(*) as ordered 
from 
  customer_orders 
  left join lateral split_to_table(exclusions, ',') as exc 
  left join pizza_toppings as pt on pt.topping_id = trim(exc.value) 
where 
  trim(exclusions) is not null 
  and trim(exclusions) != 'null' 
  and trim(exclusions) != '' 
group by 
  topping_name;
-- Generate an order item for each record in the customers_orders table in the format of one of the following:
-- Meat Lovers
-- Meat Lovers - Exclude Beef
-- Meat Lovers - Extra Bacon
-- Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
with exc_table as (
  select 
    customer_id, 
    order_id, 
    pizza_id, 
    exclusions, 
    co.order_id || co.customer_id || co.pizza_id || exclusions || extras as ind_pizza, 
    trim(exc.value) as exc 
  from 
    customer_orders as co 
    left join lateral split_to_table(exclusions, ',') as exc 
  where 
    trim(exclusions) is not null 
    and trim(exclusions) != 'null' 
    and trim(exclusions) != ''
), 
CTE as (
  select 
    co.customer_id, 
    co.order_id, 
    co.pizza_id, 
    extras, 
    co.order_id || co.customer_id || co.pizza_id || co.exclusions || extras as ext_ind_pizza, 
    exc_table.ind_pizza, 
    exc as topping_excluded, 
    trim(ext.value) as topping_added 
  from 
    customer_orders as co 
    left join lateral split_to_table(extras, ',') as ext 
    left join exc_table on exc_table.ind_pizza = ext_ind_pizza 
  where 
    trim(extras) is not null 
    and trim(extras) != 'null' 
    and trim(extras) != ''
), 
exc_CTE as (
  select 
    order_id, 
    topping_name as excluded_topping, 
    topping_added, 
    customer_id, 
    ext_ind_pizza 
  from 
    CTE 
    left join pizza_toppings as pt on pt.topping_id = topping_excluded
), 
altered_formatting as (
  select 
    order_id, 
    customer_id, 
    ext_ind_pizza, 
    '- Exclude ' || listagg(excluded_topping, ', ') || ' - Extra ' || listagg(topping_name, ', ') as Alterations 
  from 
    exc_CTE 
    left join pizza_toppings as pt on pt.topping_id = topping_added 
  group by 
    customer_id, 
    order_id, 
    ext_ind_pizza
) 
select 
  co.order_id, 
  co.customer_id, 
  co.pizza_id, 
  alterations 
from 
  customer_orders as co 
  left join altered_formatting as af on af.ext_ind_pizza = co.order_id || co.customer_id || co.pizza_id || exclusions || extras --this concat is a pizaa key for lookup
  ;
-- Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
-- For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
with ing_table as (
  select 
    order_id, 
    co.customer_id, 
    co.pizza_id, 
    pr.toppings, 
    CASE WHEN TRIM(exclusions) = 'null' THEN '' WHEN TRIM(exclusions) = '' THEN '' WHEN TRIM(exclusions) IS NULL THEN '' else exclusions END as exclusions_c, 
    CASE WHEN TRIM(extras) = 'null' THEN '' WHEN TRIM(extras) = '' THEN '' WHEN TRIM(extras) IS NULL THEN '' else extras END as extras_c, 
    ROW_NUMBER() over (
      order by 
        1
    ) as CustomerPizzaID, 
    CASE WHEN extras_c = '' then pr.toppings when extras_c != '' then pr.toppings || ',' || extras end as all_ingredients 
  from 
    customer_orders as co 
    left join pizza_recipes as pr on pr.pizza_id = co.pizza_id
), 
ingredient_long as (
  select 
    CustomerPizzaID, 
    trim(split_ing.value) as ingredient, 
    exclusions_c, 
    contains(exclusions_c, ingredient) as excluded 
  from 
    ing_table 
    left join lateral split_to_table(all_ingredients, ',') as split_ing 
  where 
    excluded = false
), 
Pizza_Topping_Names as (
  select 
    CustomerPizzaID, 
    ingredient :: int as ingredient, 
    pt.topping_name 
  from 
    ingredient_long 
    left join pizza_toppings as pt on pt.topping_id = ingredient 
  order by 
    CustomerPizzaID asc, 
    pt.topping_name asc
), 
long_ingredients as (
  select 
    customerpizzaid, 
    topping_name, 
    ingredient, 
    count(ingredient) as amount, 
    CASE when amount > 1 then amount || 'x ' || topping_name else topping_name end as ingredient_list 
  from 
    Pizza_Topping_Names 
  group by 
    customerpizzaid, 
    topping_name, 
    ingredient
), 
list_table as (
  select 
    l.customerpizzaid, 
    listagg(ingredient_list, ', ') within group (
      order by 
        ingredient_list asc
    ) as list_format 
  from 
    long_ingredients as l 
    left join ing_table as i on i.customerpizzaid = l.customerpizzaid 
  group by 
    l.customerpizzaid 
  order by 
    l.customerpizzaid
) 
select 
  i.order_id, 
  i.customer_id, 
  i.pizza_id, 
  p.pizza_name || ': ' || list_format as Pizza_Instructions 
from 
  ing_table as i 
  left join pizza_names as p on i.pizza_id = p.pizza_id 
  left join list_table as l on i.customerpizzaid = l.customerpizzaid;
-- What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
with ing_table as (
  select 
    co.order_id, 
    co.customer_id, 
    co.pizza_id, 
    pr.toppings, 
    CASE WHEN TRIM(exclusions) = 'null' THEN '' WHEN TRIM(exclusions) = '' THEN '' WHEN TRIM(exclusions) IS NULL THEN '' else exclusions END as exclusions_c, 
    CASE WHEN TRIM(extras) = 'null' THEN '' WHEN TRIM(extras) = '' THEN '' WHEN TRIM(extras) IS NULL THEN '' else extras END as extras_c, 
    ROW_NUMBER() over (
      order by 
        1
    ) as CustomerPizzaID, 
    CASE WHEN extras_c = '' then pr.toppings when extras_c != '' then pr.toppings || ',' || extras end as all_ingredients 
  from 
    customer_orders as co 
    left join pizza_recipes as pr on pr.pizza_id = co.pizza_id 
    inner join runner_orders as ro on ro.order_id = co.order_id 
  where 
    trim(cancellation) is null 
    or trim(cancellation)= 'null' 
    or trim(cancellation)= ''
), 
ingredient_long as (
  select 
    CustomerPizzaID, 
    trim(split_ing.value) as ingredient, 
    exclusions_c, 
    contains(exclusions_c, ingredient) as excluded 
  from 
    ing_table 
    left join lateral split_to_table(all_ingredients, ',') as split_ing 
  where 
    excluded = false
), 
Pizza_Topping_Names as (
  select 
    CustomerPizzaID, 
    ingredient :: int as ingredient, 
    pt.topping_name 
  from 
    ingredient_long 
    left join pizza_toppings as pt on pt.topping_id = ingredient 
  order by 
    CustomerPizzaID asc, 
    pt.topping_name asc
) 
select 
  topping_name, 
  count(ingredient) as amount 
from 
  Pizza_Topping_Names 
group by 
  topping_name 
order by 
  amount desc;
