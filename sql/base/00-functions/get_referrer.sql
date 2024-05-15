CREATE OR REPLACE FUNCTION get_referrer(_account text)
RETURNS uuid
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN core.referrals.referrer
  FROM core.referrals
  INNER JOIN core.users
  ON core.users.referral_id = core.referrals.referral_id
  AND core.users.account = _account;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_referrer(_account text) OWNER TO writeuser;
