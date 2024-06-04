DROP FUNCTION IF EXISTS get_explorer_stats();

CREATE FUNCTION get_explorer_stats()
RETURNS TABLE
(
  transaction_count                                 integer,
  total_swaps                                       numeric,
  liquidity_added                                   numeric,
  liquidity_removed                                 numeric,
  average_transaction_fee                           numeric
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
    average_transaction_fee                           numeric
  ) ON COMMIT DROP;
  
  INSERT INTO _get_explorer_stats_result(transaction_count)
  SELECT COUNT(*)
  FROM core.transactions;
  
  UPDATE _get_explorer_stats_result
  SET total_swaps = 
  COALESCE((
    SELECT SUM(get_stablecoin_value(swap_transaction_view.chain_id, swap_transaction_view.stablecoin_amount))
    FROM swap_transaction_view
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET liquidity_added =
  COALESCE((
    SELECT SUM(get_stablecoin_value(liquidity_transaction_view.chain_id, liquidity_transaction_view.stablecoin_amount))
    FROM liquidity_transaction_view
    WHERE action='add'
  ), 0);
  
  UPDATE _get_explorer_stats_result
  SET liquidity_removed =
  COALESCE((
    SELECT SUM(get_stablecoin_value(liquidity_transaction_view.chain_id, liquidity_transaction_view.stablecoin_amount))
    FROM liquidity_transaction_view
    WHERE action='remove'
  ), 0);

  UPDATE _get_explorer_stats_result
  SET average_transaction_fee = 
  COALESCE((
    SELECT AVG(get_stablecoin_value(core.transactions.chain_id, core.transactions.gas_price))
    FROM core.transactions
  ), 0);
  
  RETURN QUERY
  SELECT * FROM _get_explorer_stats_result;
END
$$
LANGUAGE plpgsql;