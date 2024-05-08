CREATE OR REPLACE FUNCTION create_referral
(
  _login_id                       uuid,
  _memo                           national character varying(512)
)
RETURNS text
AS
$$
  ----------------------------------------------------------------
  DECLARE _active_limit           integer = 12;
  DECLARE _total_limit            integer = 24;
  ----------------------------------------------------------------
  DECLARE _referral_id            uuid = uuid_generate_v4();
  DECLARE _referrer_id            uuid = get_user_id_by_login_id(_login_id);
  DECLARE _referral_code          text;
  DECLARE _active_count           integer;
  DECLARE _total_count            integer;
BEGIN
  SELECT COUNT(*) INTO _active_count
  FROM core.referrals
  WHERE 1 = 1
  AND NOT deleted
  AND referrer = _referrer_id;

  SELECT COUNT(*) INTO _total_count
  FROM core.referrals
  WHERE 1 = 1
  AND referrer = _referrer_id;

  IF(_active_count >= _active_limit OR _total_count >= _total_limit) THEN
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
