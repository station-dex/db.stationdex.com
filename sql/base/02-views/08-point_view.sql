CREATE OR REPLACE VIEW point_view
AS
WITH combined
AS
(
  SELECT account, points FROM liquidity_point_view
  UNION ALL
  SELECT account, points FROM swap_point_view
),
consolidated
AS
(
  SELECT
    account,
    get_name_by_account(account)  AS moniker,
    SUM(points)                   AS points
  FROM combined
  GROUP BY account
),
ranked
AS
(
  SELECT
    DENSE_RANK() OVER(ORDER BY points DESC, account ASC) AS rank,
    moniker,
    account,
    points::numeric(20, 2)
  FROM consolidated
  ORDER BY points DESC
)
SELECT * FROM ranked;

ALTER VIEW point_view OWNER TO writeuser;
