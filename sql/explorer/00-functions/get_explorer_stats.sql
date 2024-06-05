DROP FUNCTION IF EXISTS get_explorer_stats();

CREATE FUNCTION get_explorer_stats()
RETURNS TABLE
(
  transaction_count                                   integer,
  total_swaps                                         numeric,
  liquidity_added                                     numeric,
  liquidity_removed                                   numeric,
  average_gas_price                                   numeric,
  average_gas_price_today                             numeric
)
AS
$$
BEGIN
  DROP TABLE IF EXISTS _get_explorer_stats_result;
  CREATE TEMPORARY TABLE _get_explorer_stats_result
  (
    transaction_count                                 integer,
    total_swaps                                       numeric,
    liquidity_added                                   numeric,
    liquidity_removed                                 numeric,
    average_gas_price                                 numeric,
    average_gas_price_today                           numeric
  ) ON COMMIT DROP;
  
  INSERT INTO _get_explorer_stats_result(transaction_count)
  SELECT COUNT(*)
  FROM core.transactions;
  
  UPDATE _get_explorer_stats_result
  SET total_swaps = 
  COALESCE((
    SELECT COUNT(*)
    FROM swap_transaction_view
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET liquidity_added =
  COALESCE((
    SELECT COUNT(*)
    FROM liquidity_transaction_view
    WHERE action='add'
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET liquidity_removed =
  COALESCE((
    SELECT COUNT(*)
    FROM liquidity_transaction_view
    WHERE action='remove'
  ), 0);

  UPDATE _get_explorer_stats_result
  SET average_gas_price = 
  COALESCE((
    SELECT AVG(core.transactions.gas_price)
    FROM core.transactions
  ), 0);

  UPDATE _get_explorer_stats_result
  SET average_gas_price_today = 
  COALESCE((
    SELECT AVG(core.transactions.gas_price)
    FROM core.transactions
    WHERE block_timestamp > CEILING(EXTRACT(EPOCH FROM NOW()) - 86400) -- last 24h only
  ), 0);
  
  RETURN QUERY
  SELECT * FROM _get_explorer_stats_result;
END
$$
LANGUAGE plpgsql;