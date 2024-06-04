CREATE OR REPLACE VIEW referral_point_view
AS
WITH consolidated
AS
(
  SELECT
    account,
    get_name_by_account(account) AS moniker,
    SUM(points) as points,
    SUM(referral_points) as referral_points
  FROM liquidity_point_view
  GROUP BY account
  
  UNION ALL
  
  SELECT
    account,
    get_name_by_account(account) AS moniker,
    SUM(points) as points,
    SUM(referral_points) as referral_points
  FROM swap_point_view
  GROUP BY account  
),
with_referral_code
AS
(
  SELECT
    moniker,
    account,
    points::numeric(20, 2),
    referral_points::numeric(20, 2),
    (
      SELECT
        referral_code
      FROM core.referrals 
      WHERE 1 = 1
      AND referral_id=(
        SELECT
          referral_id
        FROM core.users
        WHERE 1 = 1
        AND core.users.account=consolidated.account
      )
    ),
	(
      SELECT
        referrer
      FROM core.referrals 
      WHERE 1 = 1
      AND referral_id=(
        SELECT
          referral_id
        FROM core.users
        WHERE 1 = 1
        AND core.users.account=consolidated.account
      )
    )
  FROM consolidated
  ORDER BY points DESC 
)
SELECT * FROM with_referral_code;

ALTER VIEW referral_point_view OWNER TO writeuser;