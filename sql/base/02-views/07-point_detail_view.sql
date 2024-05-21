CREATE OR REPLACE VIEW point_detail_view
AS
SELECT version, chain_id, action, account, pool_name, block_timestamp, transaction_hash, amount, points
FROM swap_point_view
UNION ALL
SELECT version, chain_id, action, account, pool_name, block_timestamp, transaction_hash, amount, points
FROM liquidity_point_view;

ALTER VIEW point_detail_view OWNER TO writeuser;
