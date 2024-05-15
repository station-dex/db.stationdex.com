CREATE OR REPLACE VIEW liquidity_transaction_view
AS
SELECT
  'v2'                                                          AS version,
  'remove'                                                      AS action,
  core.v2_pair_burn.transaction_sender                          AS account,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env(CONCAT(whitelisted_pool_view.pool_address, ':name'))      AS pool_name,
  core.v2_pair_burn.block_timestamp,
  core.v2_pair_burn.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v2_pair_burn.amount0)
    ELSE ABS(core.v2_pair_burn.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v2_pair_burn.amount1)
    ELSE ABS(core.v2_pair_burn.amount0)
  END                                                           AS token_amount
FROM core.v2_pair_burn
JOIN whitelisted_pool_view
ON LOWER(core.v2_pair_burn.address) = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version = 'v2'

UNION ALL

SELECT
  'v2'                                                          AS version,
  'add'                                                         AS action,
  core.v2_pair_mint.transaction_sender                          AS account,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env(CONCAT(whitelisted_pool_view.pool_address, ':name'))      AS pool_name,
  core.v2_pair_mint.block_timestamp,
  core.v2_pair_mint.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v2_pair_mint.amount0)
    ELSE ABS(core.v2_pair_mint.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v2_pair_mint.amount1)
    ELSE ABS(core.v2_pair_mint.amount0)
  END                                                           AS token_amount
FROM core.v2_pair_mint
JOIN whitelisted_pool_view
ON LOWER(core.v2_pair_mint.address) = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version = 'v2'

UNION ALL

SELECT
  'v3'                                                          AS version,
  'add'                                                         AS action,
  core.v3_pool_mint.transaction_sender                          AS account,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env(CONCAT(whitelisted_pool_view.pool_address, ':name'))      AS pool_name,
  core.v3_pool_mint.block_timestamp,
  core.v3_pool_mint.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_mint.amount0)
    ELSE ABS(core.v3_pool_mint.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_mint.amount1)
    ELSE ABS(core.v3_pool_mint.amount0)
  END                                                           AS token_amount
FROM core.v3_pool_mint
JOIN whitelisted_pool_view
ON LOWER(core.v3_pool_mint.address) = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version = 'v3'

UNION ALL

SELECT
  'v3'                                                          AS version,
  'remove'                                                      AS action,
  core.v3_pool_burn.transaction_sender                          AS account,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env(CONCAT(whitelisted_pool_view.pool_address, ':name'))      AS pool_name,
  core.v3_pool_burn.block_timestamp,
  core.v3_pool_burn.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_burn.amount0)
    ELSE ABS(core.v3_pool_burn.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_burn.amount1)
    ELSE ABS(core.v3_pool_burn.amount0)
  END                                                           AS token_amount
FROM core.v3_pool_burn
JOIN whitelisted_pool_view
ON LOWER(core.v3_pool_burn.address) = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version = 'v3';

ALTER VIEW liquidity_transaction_view OWNER TO writeuser;
