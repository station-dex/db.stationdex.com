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

CREATE SCHEMA IF NOT EXISTS meta;

CREATE TABLE IF NOT EXISTS meta.locks
(
  id                                                BIGSERIAL PRIMARY KEY NOT NULL,
  project_id                                        text,
  created_at                                        TIMESTAMP WITH TIME ZONE DEFAULT (NOW())
);

CREATE UNIQUE INDEX IF NOT EXISTS locks_ensure_unique_uix
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
