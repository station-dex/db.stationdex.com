CREATE OR REPLACE VIEW swap_transaction_view
AS
SELECT
  'v2'                                                          AS version,
  core.v2_pair_swap.transaction_sender                          AS account,
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
  core.v2_pair_swap.block_timestamp,
  core.v2_pair_swap.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS
    (
      CASE
        WHEN core.v2_pair_swap.amount0_in IS NULL
        THEN core.v2_pair_swap.amount0_out
        WHEN core.v2_pair_swap.amount0_in = 0
        THEN core.v2_pair_swap.amount0_out
        ELSE core.v2_pair_swap.amount0_in
      END
    )
    ELSE ABS
    (
      CASE
        WHEN core.v2_pair_swap.amount1_in IS NULL
        THEN core.v2_pair_swap.amount1_out
        WHEN core.v2_pair_swap.amount1_in = 0
        THEN core.v2_pair_swap.amount1_out
        ELSE core.v2_pair_swap.amount1_in
      END
    )
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS
    (
      CASE
        WHEN core.v2_pair_swap.amount1_in IS NULL
        THEN core.v2_pair_swap.amount1_out
        WHEN core.v2_pair_swap.amount1_in = 0
        THEN core.v2_pair_swap.amount1_out
        ELSE core.v2_pair_swap.amount1_in
      END
    )
    ELSE ABS
    (
      CASE
        WHEN core.v2_pair_swap.amount0_in IS NULL
        THEN core.v2_pair_swap.amount0_out
        WHEN core.v2_pair_swap.amount0_in = 0
        THEN core.v2_pair_swap.amount0_out
        ELSE core.v2_pair_swap.amount0_in
      END
    )
  END                                                           AS token_amount
FROM core.v2_pair_swap
INNER JOIN whitelisted_pool_view
ON LOWER(core.v2_pair_swap.address) = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version = 'v2'

UNION ALL

SELECT
  'v3'                                                          AS version,
  core.v3_pool_swap.transaction_sender                          AS account,
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
  core.v3_pool_swap.block_timestamp,
  core.v3_pool_swap.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_swap.amount0)
    ELSE ABS(core.v3_pool_swap.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_swap.amount1)
    ELSE ABS(core.v3_pool_swap.amount0)
  END                                                           AS token_amount
FROM core.v3_pool_swap
JOIN whitelisted_pool_view
ON LOWER(core.v3_pool_swap.address) = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version = 'v3';

ALTER VIEW swap_transaction_view OWNER TO writeuser;
