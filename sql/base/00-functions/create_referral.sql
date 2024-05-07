CREATE OR REPLACE FUNCTION create_referral
(
  _login_id                       uuid,
  _memo                           national character varying(512)
)
RETURNS text
AS
$$
  DECLARE _referral_id            uuid = uuid_generate_v4();
  DECLARE _referrer_id            uuid;
  DECLARE _referral_code          text;
  DECLARE _limit                  integer = 10;
  DECLARE _count                  integer;
BEGIN
  SELECT user_id INTO _referrer_id
  FROM core.logins
  WHERE login_id = _login_id;

  SELECT COUNT(*) INTO _count
  FROM core.referrals
  WHERE 1 = 1
  AND NOT deleted
  AND referrer = _referrer_id;

  IF(_count >= _limit) THEN
    RETURN NULL;
  END IF;

  _referral_code := get_referral_code();

  INSERT INTO core.referrals(referral_id, referrer, memo, referral_code)
  SELECT _referral_id, _referrer_id, _memo, _referral_code;

  RETURN _referral_code;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION create_referral OWNER TO writeuser;
