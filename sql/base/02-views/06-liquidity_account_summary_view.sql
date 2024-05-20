CREATE OR REPLACE VIEW liquidity_account_summary_view
AS
SELECT
  account,
  referrer,
  SUM(amount)                   AS amount,
  SUM(points)                   AS points,
  SUM(referral_points)          AS referral_points
FROM liquidity_point_view
GROUP BY account, referrer;

ALTER VIEW liquidity_account_summary_view OWNER TO writeuser;
