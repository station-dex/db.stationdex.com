CREATE OR REPLACE VIEW swap_account_summary_view
AS
SELECT
  account,
  referrer,
  SUM(amount)           AS amount,
  SUM(points)           AS points,
  SUM(referral_points)  AS referral_points
FROM swap_point_view
GROUP BY account, referrer;

ALTER VIEW swap_account_summary_view OWNER TO writeuser;
