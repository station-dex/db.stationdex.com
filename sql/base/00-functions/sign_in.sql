CREATE OR REPLACE FUNCTION sign_in
(
  _account                        text,
  _name                           text,
  _referral_code                  text,
  _ip_address                     text,
  _user_agent                     jsonb,
  _browser                        text
)
RETURNS uuid
AS
$$
  ----------------------------------------------------------------
  DECLARE _window                 interval = '10 minutes';
  DECLARE _ban_duration           interval = '6 hours';
  DECLARE _login_limit            integer = 5;
  ----------------------------------------------------------------
  DECLARE _referral_id            uuid;
  DECLARE _user_id                uuid;
  DECLARE _login_id               uuid = uuid_generate_v4();
  DECLARE _login_count            integer;
  DECLARE _new_user               boolean = false;
BEGIN
  SELECT referral_id INTO _referral_id
  FROM core.referrals
  WHERE NOT deleted
  AND LOWER(referral_code) = LOWER(_referral_code);

  IF (_referral_id IS NULL AND COALESCE(_referral_code, '') <> '') THEN
    RAISE EXCEPTION USING ERRCODE = 'X1892', MESSAGE = 'Invalid referral code';
    RETURN NULL;
  END IF;

  /**
   * ----------------------------------------------------------------
   * If the user is logging in for the first time, add the user.
   * ----------------------------------------------------------------
   */
  IF NOT EXISTS
  (
    SELECT 1 FROM core.users
    WHERE LOWER(account) = LOWER(_account)
  ) THEN
    _new_user := true;

    INSERT INTO core.users(account, name, referral_id)
    SELECT _account, _name, _referral_id;

    /**
     * ----------------------------------------------------------------
     * For valid referrals, increment the referral count.
     * ----------------------------------------------------------------
     */
    IF(_referral_id IS NOT NULL) THEN
      UPDATE core.referrals
      SET total_referrals = total_referrals + 1
      WHERE referral_id = _referral_id;
    END IF;
  END IF;


  IF(NOT _new_user AND COALESCE(_referral_code, '') <> '') THEN
    RAISE EXCEPTION USING ERRCODE = 'X1892', MESSAGE = 'Invalid referral code';
    RETURN NULL;
  END IF;

  SELECT user_id INTO _user_id
  FROM core.users
  WHERE LOWER(account) = LOWER(_account);

  /**
   * ----------------------------------------------------------------
   * Reject the login if the user is banned.
   * ----------------------------------------------------------------
   */
  IF EXISTS
  (
    SELECT 1 FROM core.users
    WHERE user_id = _user_id 
    AND banned_till > NOW()
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'X1891', MESSAGE = 'Soft ban for spamming';
    RETURN NULL;
  END IF;

  /**
   * ----------------------------------------------------------------
   * Prevent spam logins when a user makes more than 
   * 5 login attempts within a 10-minute window.
   * ----------------------------------------------------------------
   */
  SELECT COUNT(*) INTO _login_count
  FROM core.logins
  WHERE user_id = _user_id
  AND created_at > NOW() - _window;

  IF(_login_count >= _login_limit) THEN
    UPDATE core.users
    SET banned_till = NOW() + _ban_duration
    WHERE user_id = _user_id;

    RAISE EXCEPTION USING ERRCODE = 'X1893', MESSAGE = 'Login limit exceeded';
    RETURN NULL;
  END IF;

  INSERT INTO core.logins(login_id, user_id, ip_address, user_agent, browser)
  SELECT _login_id, _user_id, _ip_address, _user_agent, _browser;

  RETURN _login_id;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION sign_in OWNER TO writeuser;
