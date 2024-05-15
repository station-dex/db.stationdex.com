CREATE OR REPLACE VIEW swap_point_view
AS
WITH swap_transactions
AS
(
  SELECT
    version,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    (stablecoin_amount * 2) / POWER(10, env(CONCAT(stablecoin, ':decimals'))::numeric) AS amount
  FROM swap_transaction_view
)
SELECT
  version,
  'swap'                                        AS action,
  account,
  pool_address,
  pool_name,
  block_timestamp,
  transaction_hash,
  amount,
  amount * env('swap:point')::numeric           AS points,
  CASE
    WHEN get_account_by_user_id(get_referrer(account)) IS NULL
    THEN NULL
    ELSE amount * env('swap:point')::numeric * env('referral:points')::numeric
  END                                           AS referral_points,
  get_account_by_user_id(get_referrer(account)) AS referrer
FROM swap_transactions;

ALTER VIEW swap_point_view OWNER TO writeuser;
