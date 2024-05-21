CREATE OR REPLACE VIEW point_summary_view
AS
WITH summary
AS
(
  SELECT
    SUM(points) AS total,
    COUNT(account) AS starfinders
  FROM point_view
),
top_accounts
AS
(
  SELECT * 
  FROM point_view
  ORDER BY rank ASC
  LIMIT 3
)
SELECT * FROM top_accounts
CROSS JOIN summary;

ALTER VIEW point_summary_view OWNER TO writeuser;
