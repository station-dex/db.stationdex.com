CREATE OR REPLACE FUNCTION check_referral_code
(
  _referral_code                                  text
)
RETURNS BOOLEAN
AS
$$
  DECLARE _valid                                  boolean;
  DECLARE _query                                  text;
BEGIN
  _query := format('SELECT
	  COUNT(*) > 0
  FROM core.referrals
  WHERE 1=1
  AND referral_code=%s', quote_literal(_referral_code));

  EXECUTE _query INTO _valid;

  RETURN _valid;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION check_referral_code OWNER TO writeuser;
