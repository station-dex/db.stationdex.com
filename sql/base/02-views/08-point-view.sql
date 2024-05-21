CREATE OR REPLACE VIEW point_view
AS
WITH consolidated
AS
(
  SELECT
    account,
    get_name_by_account(account) AS moniker,
    SUM(points) as points
  FROM liquidity_point_view
  GROUP BY account
  
  UNION ALL
  
  SELECT
    account,
    get_name_by_account(account) AS moniker,
    SUM(points) as points
  FROM swap_point_view
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
