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

CREATE OR REPLACE FUNCTION get_name_by_login_id(_login_id uuid)
RETURNS uuid
STABLE
AS
$$
BEGIN
  RETURN get_name_by_user_id(get_user_id_by_login_id(_login_id));
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_name_by_login_id OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_name_by_user_id(_user_id uuid)
RETURNS uuid
STABLE
AS
$$
BEGIN
  RETURN core.users.name
  FROM core.users
  WHERE 1 = 1
  AND core.users.user_id = _user_id;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_name_by_user_id OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_referral_code()
RETURNS text
STABLE
AS
$$
  DECLARE _prefixes text[] = '{Zum,Pix,Fei,Ras,Fozz,Quix,Zeb,Mop,Glip,Vun,Dax,Jiv,Kex,Bop,Yuz,Nix,Pev,Lox,Ruv,Zep,Quaz,Drix,Yop,Wix,Ziv,Kip,Gox,Vex,Jaz,Qux,Blip,Fex,Piz,Jux,Voz,Zix,Gep,Quip,Pox,Ziv,Fip,Xux,Koz,Vep,Lix,Zox,Mux,Quex,Ziz,Diz,Zup,Vix,Pox,Tix,Zun,Qip,Vux,Zem,Bux,Nux,Zat,Vop,Zob,Xix,Zav,Qev,Zut,Zop,Vez,Zil,Quem,Zim,Zul,Vub,Zik,Zed,Vez,Zor,Xax,Zun,Zay,Quem,Zad,Zol,Vex,Ziv,Zob,Quam,Zol,Zix,Zop,Vez,Zup,Zep,Zog,Zev,Zin,Zab,Zof,Zem,Zuz,Zav,Zul,Zor}';
  DECLARE _suffix text = array_to_string(ARRAY(SELECT chr((48 + round(random() * 9)) :: integer) FROM generate_series(1,7)), '');
  DECLARE _code text;
BEGIN
  _code := CONCAT
  (
    UPPER(_prefixes[1 + floor((random() * array_length(_prefixes, 1)))::int]),
    '-',
    _suffix
  );

  IF EXISTS(SELECT 1 FROM core.referrals WHERE referral_code = _code) THEN
    RETURN get_referral_code();
  END IF;

  RETURN _code;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_referral_code OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_user_id_by_login_id(_login_id uuid)
RETURNS uuid
STABLE
AS
$$
BEGIN
  RETURN user_id
  FROM core.logins
  WHERE 1 = 1
  AND core.logins.login_id = _login_id;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_user_id_by_login_id OWNER TO writeuser;

CREATE OR REPLACE FUNCTION sign_in
(
  _account                        text,
  _name                           text,
  _referral_code                  text,
  _ip_address                     text,
  _user_agent                     text,
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

CREATE SCHEMA IF NOT EXISTS meta;

CREATE TABLE IF NOT EXISTS meta.locks
(
  id                                                BIGSERIAL PRIMARY KEY NOT NULL,
  project_id                                        text,
  created_at                                        TIMESTAMP WITH TIME ZONE DEFAULT (NOW())
);

CREATE UNIQUE INDEX IF NOT EXISTS locks_project_id_uix
ON meta.locks (LOWER(project_id));

-- SELECT * FROM meta.locks;

CREATE TABLE IF NOT EXISTS meta.progress_tracker
(
  project_id                    text PRIMARY KEY NOT NULL,
  synced_upto_block_number      integer,
  synced_upto_log_index         integer
);

CREATE UNIQUE INDEX IF NOT EXISTS progress_tracker_project_id_uix
ON meta.progress_tracker (LOWER(project_id));

CREATE OR REPLACE FUNCTION meta.update_progress
(
  _project_id                   text,
  _block_number                 integer,
  _log_index                    integer
)
RETURNS void
AS
$$
BEGIN
  INSERT INTO meta.progress_tracker
    (
      project_id,
      synced_upto_block_number,
      synced_upto_log_index
    )
    VALUES
    (
      _project_id,
      _block_number,
      _log_index
    ) 
    ON CONFLICT (project_id)
    DO UPDATE
    SET
      synced_upto_block_number = _block_number,
      synced_upto_log_index = _log_index;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM meta.progress_tracker;

--
