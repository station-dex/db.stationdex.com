CREATE OR REPLACE FUNCTION get_explorer_stats()
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
  SELECT COUNT(DISTINCT transaction_hash)
  FROM core.transactions;
  
  WITH
  v2_result
  AS
  (
    SELECT count(*) as total_count 
    FROM core.v2_pair_swap
  ),
  v3_result
  AS
  (
    SELECT count(*) as total_count
    FROM core.v3_pool_swap
  )
  UPDATE _get_explorer_stats_result
  SET total_swaps = 
  (
    SELECT v2_result.total_count + v3_result.total_count
    FROM v2_result, v3_result
  );

  WITH
  v2_result
  AS
  (
    SELECT count(*) as total_count 
    FROM core.v2_pair_mint
  ),
  v3_result
  AS
  (
    SELECT count(*) as total_count
    FROM core.v3_pool_mint
  )
  UPDATE _get_explorer_stats_result
  SET liquidity_added = 
  (
    SELECT v2_result.total_count + v3_result.total_count
    FROM v2_result, v3_result
  );
  
  WITH
  v2_result
  AS
  (
    SELECT count(*) as total_count 
    FROM core.v2_pair_burn
  ),
  v3_result
  AS
  (
    SELECT count(*) as total_count
    FROM core.v3_pool_burn
  )
  UPDATE _get_explorer_stats_result
  SET liquidity_removed = 
  (
    SELECT v2_result.total_count + v3_result.total_count
    FROM v2_result, v3_result
  );

  UPDATE _get_explorer_stats_result
  SET average_gas_price = COALESCE
    (
      (
        SELECT AVG(core.transactions.gas_price)
        FROM core.transactions
        WHERE block_timestamp 
        BETWEEN 
          CEILING(EXTRACT(EPOCH FROM NOW() - INTERVAL '2 days')) 
          AND CEILING(EXTRACT(EPOCH FROM NOW() - INTERVAL '1 day'))
      ), 
    0
    );

  UPDATE _get_explorer_stats_result
  SET average_gas_price_today = COALESCE
    (
      (
        SELECT AVG(core.transactions.gas_price)
        FROM core.transactions
        WHERE block_timestamp > CEILING(EXTRACT(EPOCH FROM NOW() - INTERVAL '1 day'))
      ), 
    0
    );
  
  RETURN QUERY
  SELECT * FROM _get_explorer_stats_result;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_explorer_stats OWNER TO writeuser;