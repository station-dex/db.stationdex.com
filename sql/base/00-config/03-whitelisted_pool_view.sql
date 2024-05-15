CREATE MATERIALIZED VIEW IF NOT EXISTS whitelisted_pool_view
AS
WITH whitelisted_pools
AS
(
  SELECT
    'v2'                                                        AS version,
    'WOKB/USDT'                                                 AS name,
    env('v2:WOKB/USDT')                                         AS pool_address,
    env('USDT')                                                 AS token0,
    env('WOKB')                                                 AS token1,
    true                                                        AS token0_is_stablecoin
  UNION ALL
  SELECT
    'v3'                                                        AS version,
    'WOKB/USDT'                                                 AS name,
    env('v3:WOKB/USDT')                                         AS pool_address,
    env('USDT')                                                 AS token0,
    env('WOKB')                                                 AS token1,
    true                                                        AS token0_is_stablecoin
  UNION ALL
  SELECT
    'v3'                                                        AS version,
    'WETH/USDT'                                                 AS name,
    env('v3:WETH/USDT')                                         AS pool_address,
    env('USDT')                                                 AS token0,
    env('WETH')                                                 AS token1,
    true                                                        AS token0_is_stablecoin
)
SELECT * FROM whitelisted_pools;

ALTER MATERIALIZED VIEW whitelisted_pool_view OWNER TO writeuser;
