CREATE OR REPLACE VIEW liquidity_point_view
AS
WITH stage1
AS
(
  SELECT
    version,
    chain_id,
    action,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    to_timestamp(block_timestamp)                                                                                    AS date,
    (stablecoin_amount * 2) / POWER(10, env(CONCAT(chain_id, ':', stablecoin, ':decimals'))::numeric)                AS amount,
    ROW_NUMBER() OVER (PARTITION BY account, version, chain_id, pool_address ORDER BY to_timestamp(block_timestamp)) AS row_num,
    LEAD
    (
      to_timestamp(block_timestamp),
      1,
      NOW()
    ) OVER (PARTITION BY account, version, chain_id, pool_address ORDER BY to_timestamp(block_timestamp))            AS next_date
  FROM liquidity_transaction_view
),
balances
AS
(
  SELECT
    version,
    chain_id,
    action,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    date,
    amount,
    next_date,
    CASE
      WHEN action = 'add'
      THEN amount
      ELSE -amount
    END                                                                                                              AS balance_change
  FROM stage1
),
cumulative
AS
(
  SELECT
    version,
    chain_id,
    action,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    date,
    amount,
    next_date,
    SUM(balance_change) OVER (PARTITION BY account, version, chain_id, pool_address ORDER BY date)                   AS balance,
    next_date - date                                                                                                 AS total_duration
  FROM balances
),
daily_points_calculation
AS
(
  SELECT
    version,
    chain_id,
    action,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    amount,
    date,
    GREATEST(balance, 0)                                                                                             AS balance,
    EXTRACT(EPOCH FROM total_duration) / 86400                                                                       AS days,
    GREATEST(balance, 0) * env('liquidity:point')::numeric                                                           AS points_per_day
  FROM cumulative
)
SELECT
  version,
  chain_id,
  action,
  account,
  pool_address,
  pool_name,
  block_timestamp,
  transaction_hash,
  amount,
  date,
  balance,
  days,
  points_per_day * days                                                                                              AS points,
  CASE
    WHEN get_account_by_user_id(get_referrer(account)) IS NULL
    THEN NULL
    ELSE points_per_day * days * env('referral:points')::numeric
  END                                                                                                                AS referral_points,
  get_account_by_user_id(get_referrer(account))                                                                      AS referrer
FROM daily_points_calculation;

ALTER VIEW liquidity_point_view OWNER TO writeuser;

