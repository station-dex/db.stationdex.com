CREATE OR REPLACE FUNCTION get_referral_summary
(
  _login_id                                       uuid,
  _referral_code                                  text
)
RETURNS TABLE
(
  total_points                                    numeric,
  total_referral_points                           numeric
)
AS
$$
  DECLARE _query                                  text;
  DECLARE _referrer_id                            uuid = get_user_id_by_login_id(_login_id);
BEGIN
  _query := format('
  SELECT
	  SUM(points)               AS total_points,
	  SUM(referral_points)      AS total_referral_points
	FROM referral_point_view
	WHERE 1 = 1
  AND referrer=%s
	AND referral_code=%s', quote_literal(_referrer_id), quote_literal(_referral_code));

  RETURN QUERY EXECUTE _query;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_referral_summary OWNER TO writeuser;