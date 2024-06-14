CREATE OR REPLACE VIEW whitelisted_pool_view
AS
WITH whitelisted_pools
AS
(
  SELECT
    196                                                             AS chain_id,
    'v2'                                                            AS version,
    '196:WOKB/USDT'                                                 AS name,
    env('196:v2:WOKB/USDT')                                         AS pool_address,
    env('196:USDT')                                                 AS token0,
    env('196:WOKB')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
  UNION ALL
  SELECT
    196                                                             AS chain_id,
    'v3'                                                            AS version,
    '196:WOKB/USDT'                                                 AS name,
    env('196:v3:WOKB/USDT')                                         AS pool_address,
    env('196:USDT')                                                 AS token0,
    env('196:WOKB')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
  UNION ALL
  SELECT
    196                                                             AS chain_id,
    'v3'                                                            AS version,
    '196:WETH/USDT'                                                 AS name,
    env('196:v3:WETH/USDT')                                         AS pool_address,
    env('196:USDT')                                                 AS token0,
    env('196:WETH')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
  UNION ALL
  SELECT
    195                                                             AS chain_id,
    'v2'                                                            AS version,
    '195:WOKB/USDC'                                                 AS name,
    env('195:v3:WOKB/USDC')                                         AS pool_address,
    env('195:WOKB')                                                 AS token0,
    env('195:USDC')                                                 AS token1,
    false                                                           AS token0_is_stablecoin
  UNION ALL
  SELECT
    195                                                             AS chain_id,
    'v3'                                                            AS version,
    '195:USDC/USDT'                                                 AS name,
    env('195:v2:USDC/USDT')                                         AS pool_address,
    env('195:USDC')                                                 AS token0,
    env('195:USDT')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
  UNION ALL
  SELECT
    195                                                             AS chain_id,
    'v3'                                                            AS version,
    '195:USDC/USDT'                                                 AS name,
    env('195:v3:USDC/USDT')                                         AS pool_address,
    env('195:USDC')                                                 AS token0,
    env('195:USDT')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
)
SELECT * FROM whitelisted_pools;

ALTER VIEW whitelisted_pool_view OWNER TO writeuser;
