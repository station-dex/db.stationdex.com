CREATE TABLE IF NOT EXISTS environment_variables
(
  key                                            text NOT NULL PRIMARY KEY,
  value                                          text NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS environment_variables_key_uix
ON environment_variables(LOWER(key));

ALTER TABLE environment_variables OWNER TO writeuser;

CREATE OR REPLACE FUNCTION env(_key text, _value text)
RETURNS void
AS
$$
BEGIN
  IF(_value IS NULL) THEN
    DELETE FROM environment_variables
    WHERE LOWER(key) = LOWER(_key);
    RETURN;
  END IF;

  INSERT INTO environment_variables(key, value)
  VALUES (_key, _value)
  ON CONFLICT (key)
  DO UPDATE SET value = _value;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION env(_key text, _value text) OWNER TO writeuser;

CREATE OR REPLACE FUNCTION env(_key text)
RETURNS text
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN value FROM environment_variables
  WHERE LOWER(key) = LOWER(_key);
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION env(_key text) OWNER TO writeuser;

DELETE FROM environment_variables;

-- common

SELECT env('swap:point',                                                '15');
SELECT env('liquidity:point',                                           '1');
SELECT env('referral:points',                                           '0.1');

-- X Layer Mainnet: 196

SELECT env('196:USDT',                                                  '0x1e4a5963abfd975d8c9021ce480b42188849d41d');
SELECT env('196:WOKB',                                                  '0xe538905cf8410324e03a5a23c1c177a474d59b2b');
SELECT env('196:WETH',                                                  '0x5a77f1443d16ee5761d310e38b62f77f726bc71c');
SELECT env('196:v2:WOKB/USDT',                                          '0xfcf21d9dcf4f6a5abcc04176cddbd1414f4a3798');
SELECT env('196:v3:WOKB/USDT',                                          '0x11e7c6ff7ad159e179023bb771aec61db6d9234d');
SELECT env('196:v3:WETH/USDT',                                          '0xdd26d766020665f0e7c0d35532cf11ee8ed29d5a');

SELECT env('196:0x1e4a5963abfd975d8c9021ce480b42188849d41d:name',       'USDT');
SELECT env('196:0xe538905cf8410324e03a5a23c1c177a474d59b2b:name',       'WOKB');
SELECT env('196:0x5a77f1443d16ee5761d310e38b62f77f726bc71c:name',       'WETH');
SELECT env('196:0xfcf21d9dcf4f6a5abcc04176cddbd1414f4a3798:name',       'v2:WOKB/USDT');
SELECT env('196:0x11e7c6ff7ad159e179023bb771aec61db6d9234d:name',       'v3:WOKB/USDT');
SELECT env('196:0xdd26d766020665f0e7c0d35532cf11ee8ed29d5a:name',       'v3:WETH/USDT');

SELECT env('196:0x1e4a5963abfd975d8c9021ce480b42188849d41d:decimals',   '6');
SELECT env('196:0xe538905cf8410324e03a5a23c1c177a474d59b2b:decimals',   '18');
SELECT env('196:0x5a77f1443d16ee5761d310e38b62f77f726bc71c:decimals',   '18');

SELECT env('196:contracts', '{0xa91f3e6935859d3333c4e528e74f3284124dcf51,0x90Abedb3F1d1ea4f945153440Db7AC8B74e81BAc ,0xf89f39e39cf07f6862c084c2e1dbc913b521263a ,0xfcf21d9dcf4f6a5abcc04176cddbd1414f4a3798 ,0x11e7c6ff7ad159e179023bb771aec61db6d9234d ,0xdd26d766020665f0e7c0d35532cf11ee8ed29d5a}');

-- X Layer Testnet: 195

SELECT env('195:WOKB',                                                  '0x0f532a02503bce28444ce6d4ccc163cc1e2e56a6');
SELECT env('195:USDT',                                                  '0xeb45D32425a02a5A9d8500375932f1cCe5781b96');
SELECT env('195:USDC',                                                  '0x7bba099eb3050880dbbc1b42eb7ef8a3ff1eb248');
SELECT env('195:v3:WOKB/USDC',                                          '0x725b0caa0a38564b90e9ce608e037e2556de4f87');
SELECT env('195:v2:USDC/USDT',                                          '0x388c8ca45bccf0c430ef6955a526b1dc1bab765a');
SELECT env('195:v3:USDC/USDT',                                          '0x26f007e7c978856a70f8d2e8a79300496e96a1ba');

SELECT env('195:0x0f532a02503bce28444ce6d4ccc163cc1e2e56a6:name',       'WOKB');
SELECT env('195:0xeb45D32425a02a5A9d8500375932f1cCe5781b96:name',       'USDT');
SELECT env('195:0x7bba099eb3050880dbbc1b42eb7ef8a3ff1eb248:name',       'USDC');
SELECT env('195:0x725b0caa0a38564b90e9ce608e037e2556de4f87:name',       'v3:WOKB/USDC');
SELECT env('195:0x388c8ca45bccf0c430ef6955a526b1dc1bab765a:name',       'v2:USDC/USDT');
SELECT env('195:0x26f007e7c978856a70f8d2e8a79300496e96a1ba:name',       'v3:USDC/USDT');

SELECT env('195:0x0f532a02503bce28444ce6d4ccc163cc1e2e56a6:decimals',   '18');
SELECT env('195:0xeb45D32425a02a5A9d8500375932f1cCe5781b96:decimals',   '18');
SELECT env('195:0x7bba099eb3050880dbbc1b42eb7ef8a3ff1eb248:decimals',   '6');

SELECT env('195:contracts', '{0x5182e0fcb8619f41c0f40da342b4dc82c088f5e5, 0xa639d6f6437a487201f414d787fdcacfa627b007, 0x0623806922db8bfe8a5d0996c73ea2fb5999ee82, 0x6e19cb93b94433f59a3257b6e995b95e655e09a2}');


CREATE MATERIALIZED VIEW IF NOT EXISTS whitelisted_pool_view
AS
WITH whitelisted_pools
AS
(
  SELECT
    196                                                             AS chain_id,
    'v2'                                                            AS version,
    '196:WOKB/USDT'                                                 AS name,
    env('196:v2:WOKB/USDT')                                         AS pool_address,
    env('196:USDT')                                                 AS token0,
    env('196:WOKB')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
  UNION ALL
  SELECT
    196                                                             AS chain_id,
    'v3'                                                            AS version,
    '196:WOKB/USDT'                                                 AS name,
    env('196:v3:WOKB/USDT')                                         AS pool_address,
    env('196:USDT')                                                 AS token0,
    env('196:WOKB')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
  UNION ALL
  SELECT
    196                                                             AS chain_id,
    'v3'                                                            AS version,
    '196:WETH/USDT'                                                 AS name,
    env('196:v3:WETH/USDT')                                         AS pool_address,
    env('196:USDT')                                                 AS token0,
    env('196:WETH')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
  UNION ALL
  SELECT
    195                                                             AS chain_id,
    'v2'                                                            AS version,
    '195:WOKB/USDC'                                                 AS name,
    env('195:v3:WOKB/USDC')                                         AS pool_address,
    env('195:WOKB')                                                 AS token0,
    env('195:USDC')                                                 AS token1,
    false                                                           AS token0_is_stablecoin
  UNION ALL
  SELECT
    195                                                             AS chain_id,
    'v3'                                                            AS version,
    '195:USDC/USDT'                                                 AS name,
    env('195:v2:USDC/USDT')                                         AS pool_address,
    env('195:USDC')                                                 AS token0,
    env('195:USDT')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
  UNION ALL
  SELECT
    195                                                             AS chain_id,
    'v3'                                                            AS version,
    '195:USDC/USDT'                                                 AS name,
    env('195:v3:USDC/USDT')                                         AS pool_address,
    env('195:USDC')                                                 AS token0,
    env('195:USDT')                                                 AS token1,
    true                                                            AS token0_is_stablecoin
)
SELECT * FROM whitelisted_pools;

ALTER MATERIALIZED VIEW whitelisted_pool_view OWNER TO writeuser;

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

CREATE OR REPLACE FUNCTION get_account_by_user_id(_user_id uuid)
RETURNS text
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN core.users.account
  FROM core.users
  WHERE 1 = 1
  AND core.users.user_id = _user_id;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_account_by_user_id(_user_id uuid) OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_name_by_account(_account text)
RETURNS text
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN core.monikers.name
  FROM core.monikers
  WHERE core.monikers.account = _account;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_name_by_account OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_name_by_login_id(_login_id uuid)
RETURNS text
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN get_name_by_user_id(get_user_id_by_login_id(_login_id));
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_name_by_login_id OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_name_by_user_id(_user_id uuid)
RETURNS text
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN core.monikers.name
  FROM core.users
  INNER JOIN core.monikers
  ON core.monikers.account = core.users.account
  WHERE 1 = 1
  AND core.users.user_id = _user_id;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_name_by_user_id OWNER TO writeuser;

CREATE OR REPLACE FUNCTION get_point_detail
(
  _page_number                                    integer,
  _account                                        address
)
RETURNS TABLE
(
  version                                         text,
  chain_id                                        uint256,
  action                                          text,
  account                                         address,
  pool_name                                       text,
  block_timestamp                                 integer,
  transaction_hash                                text,
  amount                                          numeric,
  points                                          numeric,
  page_size                                       integer,
  page_number                                     integer,
  total_records                                   integer,
  total_pages                                     integer,
  total_points                                    numeric,
  rank                                            integer
)
AS
$$
  DECLARE _query                                  text;
  DECLARE _pagination_query                       text;
  DECLARE _page_size                              integer = 25;
  DECLARE _offset                                 integer;
  DECLARE _total_records                          integer;
  DECLARE _total_pages                            integer;
  DECLARE _total_points                           numeric;
  DECLARE _rank                                   bigint;
BEGIN
  IF _page_number < 1 THEN
    _page_number := 1;
  END IF;

  SELECT point_view.points, point_view.rank
  INTO _total_points, _rank
  FROM point_view
  WHERE point_view.account = _account;

  IF(_total_points IS NULL) THEN
    RETURN;
  END IF;

  _query := format('
    WITH result
    AS
    (
      SELECT * FROM point_detail_view
      WHERE 1 = 1
      AND account = %s
    )', quote_literal(_account));

  _pagination_query := CONCAT(_query, E'\n\tSELECT COUNT(*) FROM result;');

  EXECUTE _pagination_query INTO _total_records;

  _total_pages := COALESCE(CEILING(_total_records::numeric / _page_size), 0);
  _offset := (_page_number - 1) * _page_size;

  _query := CONCAT
    (
      _query,
      E'\n', 
      format
      (
        E'\tSELECT
          *,
          %s AS page_size,
          %s AS page_number,
          %s AS total_records,
          %s AS total_pages,
          %s AS total_points,
          %s AS rank
        FROM result
        ORDER BY block_timestamp DESC
        LIMIT %s
        OFFSET %s;',
        _page_size,
        _page_number,
        _total_records,
        _total_pages,
        _total_points,
        _rank,
        _page_size, --limit
        _offset
      )
    );

  RAISE NOTICE '%', _query;

  RETURN QUERY EXECUTE _query;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_point_detail OWNER TO writeuser;
CREATE OR REPLACE FUNCTION get_points
(
  _page_number                                    integer,
  _search_account                                 text
)
RETURNS TABLE
(
  rank                                            bigint,
  moniker                                         text,
  account                                         address,
  points                                          numeric,
  page_size                                       integer,
  page_number                                     integer,
  total_records                                   integer,
  total_pages                                     integer  
)
AS
$$
  DECLARE _query                                  text;
  DECLARE _pagination_query                       text;
  DECLARE _page_size                              integer = 25;
  DECLARE _offset                                 integer;
  DECLARE _total_records                          integer;
  DECLARE _total_pages                            integer;
BEGIN
  IF _page_number < 1 THEN
    _page_number := 1;
  END IF;

  _query := format('
    WITH result
    AS
    (
      SELECT * FROM point_view
      WHERE 1 = 1
      AND account ILIKE %s
    )', quote_literal_ilike(_search_account));

  _pagination_query := CONCAT(_query, E'\n\tSELECT COUNT(*) FROM result;');

  EXECUTE _pagination_query INTO _total_records;

  _total_pages := COALESCE(CEILING(_total_records::numeric / _page_size), 0);
  _offset := (_page_number - 1) * _page_size;

  _query := CONCAT
    (
      _query,
      E'\n', 
      format
      (
        E'\tSELECT
          *,
          %s AS page_size,
          %s AS page_number,
          %s AS total_records,
          %s AS total_pages
        FROM result
        ORDER BY rank ASC
        LIMIT %1$s
        OFFSET %5$s;', 
        _page_size,
        _page_number,
        _total_records,
        _total_pages,
        _offset
      )
    );

  RAISE NOTICE '%', _query;

  RETURN QUERY EXECUTE _query;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_points OWNER TO writeuser;

DROP FUNCTION IF EXISTS get_point_detail
(
  _page_number                                    integer,
  _account                                        address
);

CREATE OR REPLACE FUNCTION get_point_detail
(
  _page_number                                    integer,
  _account                                        address
)
RETURNS TABLE
(
  version                                         text,
  chain_id                                        uint256,
  action                                          text,
  account                                         address,
  pool_name                                       text,
  block_timestamp                                 integer,
  transaction_hash                                text,
  amount                                          numeric,
  points                                          numeric,
  page_size                                       integer,
  page_number                                     integer,
  total_records                                   integer,
  total_pages                                     integer  
)
AS
$$
  DECLARE _query                                  text;
  DECLARE _pagination_query                       text;
  DECLARE _page_size                              integer = 25;
  DECLARE _offset                                 integer;
  DECLARE _total_records                          integer;
  DECLARE _total_pages                            integer;
BEGIN
  IF _page_number < 1 THEN
    _page_number := 1;
  END IF;

  _query := format('
    WITH result
    AS
    (
      SELECT * FROM point_detail_view
      WHERE 1 = 1
      AND account = %s
    )', quote_literal(_account));

  _pagination_query := CONCAT(_query, E'\n\tSELECT COUNT(*) FROM result;');

  EXECUTE _pagination_query INTO _total_records;

  _total_pages := COALESCE(CEILING(_total_records::numeric / _page_size), 0);
  _offset := (_page_number - 1) * _page_size;

  _query := CONCAT
    (
      _query,
      E'\n', 
      format
      (
        E'\tSELECT
          *,
          %s AS page_size,
          %s AS page_number,
          %s AS total_records,
          %s AS total_pages
        FROM result
        ORDER BY block_timestamp DESC
        LIMIT %1$s
        OFFSET %5$s;', 
        _page_size,
        _page_number,
        _total_records,
        _total_pages,
        _offset
      )
    );

  RAISE NOTICE '%', _query;

  RETURN QUERY EXECUTE _query;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_point_detail OWNER TO writeuser;

-- SELECT * FROM get_points(1, '%%');


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

CREATE OR REPLACE FUNCTION get_user_id_by_login_id(_login_id uuid)
RETURNS uuid
STABLE PARALLEL SAFE
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

DROP FUNCTION IF EXISTS quote_literal_ilike CASCADE;

CREATE FUNCTION quote_literal_ilike(_ilike text)
RETURNS text
IMMUTABLE
AS
$$
BEGIN
  RETURN quote_literal(CONCAT('%', TRIM(_ilike), '%'));
END
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sign_in
(
  _account                        text,
  _referral_code                  text,
  _ip_address                     text,
  _user_agent                     jsonb,
  _browser                        text
)
RETURNS jsonb
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
  DECLARE _moniker                text;
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

    INSERT INTO core.users(account, referral_id)
    SELECT _account, _referral_id;

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

  PERFORM generate_moniker(_account);

  _moniker := get_name_by_user_id(_user_id);

  RETURN jsonb_build_object
  (
    'loginId', _login_id,
    'moniker', _moniker
  );
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION sign_in OWNER TO writeuser;

CREATE OR REPLACE VIEW liquidity_transaction_view
AS
SELECT
  'v2'                                                          AS version,
  'remove'                                                      AS action,
  core.v2_pair_burn.chain_id                                    AS chain_id,
  core.v2_pair_burn.transaction_sender                          AS account,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env
  (
    CONCAT
    (
      core.v2_pair_burn.chain_id,
      ':',
      whitelisted_pool_view.pool_address,
      ':name'
    )
  )                                                             AS pool_name,
  core.v2_pair_burn.block_timestamp,
  core.v2_pair_burn.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v2_pair_burn.amount0)
    ELSE ABS(core.v2_pair_burn.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v2_pair_burn.amount1)
    ELSE ABS(core.v2_pair_burn.amount0)
  END                                                           AS token_amount
FROM core.v2_pair_burn
JOIN whitelisted_pool_view
ON  1 = 1
AND core.v2_pair_burn.chain_id        = whitelisted_pool_view.chain_id
AND LOWER(core.v2_pair_burn.contract) = ANY(LOWER(env(CONCAT(core.v2_pair_burn.chain_id, ':contracts')))::text[])
AND LOWER(core.v2_pair_burn.address)  = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version     = 'v2'

UNION ALL

SELECT
  'v2'                                                          AS version,
  'add'                                                         AS action,
  core.v2_pair_mint.chain_id                                    AS chain_id,
  core.v2_pair_mint.transaction_sender                          AS account,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env
  (
    CONCAT
    (
      core.v2_pair_mint.chain_id,
      ':',
      whitelisted_pool_view.pool_address,
      ':name'
    )
  )                                                             AS pool_name,
  core.v2_pair_mint.block_timestamp,
  core.v2_pair_mint.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v2_pair_mint.amount0)
    ELSE ABS(core.v2_pair_mint.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v2_pair_mint.amount1)
    ELSE ABS(core.v2_pair_mint.amount0)
  END                                                           AS token_amount
FROM core.v2_pair_mint
JOIN whitelisted_pool_view
ON  1 = 1
AND core.v2_pair_mint.chain_id        = whitelisted_pool_view.chain_id
AND LOWER(core.v2_pair_mint.contract) = ANY(LOWER(env(CONCAT(core.v2_pair_mint.chain_id, ':contracts')))::text[])
AND LOWER(core.v2_pair_mint.address)  = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version     = 'v2'

UNION ALL

SELECT
  'v3'                                                          AS version,
  'add'                                                         AS action,
  core.v3_pool_mint.chain_id                                    AS chain_id,
  core.v3_pool_mint.transaction_sender                          AS account,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env
  (
    CONCAT
    (
      core.v3_pool_mint.chain_id,
      ':',
      whitelisted_pool_view.pool_address,
      ':name'
    )
  )                                                             AS pool_name,
  core.v3_pool_mint.block_timestamp,
  core.v3_pool_mint.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_mint.amount0)
    ELSE ABS(core.v3_pool_mint.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_mint.amount1)
    ELSE ABS(core.v3_pool_mint.amount0)
  END                                                           AS token_amount
FROM core.v3_pool_mint
JOIN whitelisted_pool_view
ON  1 = 1
AND core.v3_pool_mint.chain_id        = whitelisted_pool_view.chain_id
AND LOWER(core.v3_pool_mint.contract) = ANY(LOWER(env(CONCAT(core.v3_pool_mint.chain_id, ':contracts')))::text[])
AND LOWER(core.v3_pool_mint.address)  = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version     = 'v3'

UNION ALL

SELECT
  'v3'                                                          AS version,
  'remove'                                                      AS action,
  core.v3_pool_burn.chain_id                                    AS chain_id,
  core.v3_pool_burn.transaction_sender                          AS account,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env
  (
    CONCAT
    (
      core.v3_pool_burn.chain_id,
      ':',
      whitelisted_pool_view.pool_address,
      ':name'
    )
  )                                                             AS pool_name,
  core.v3_pool_burn.block_timestamp,
  core.v3_pool_burn.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_burn.amount0)
    ELSE ABS(core.v3_pool_burn.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_burn.amount1)
    ELSE ABS(core.v3_pool_burn.amount0)
  END                                                           AS token_amount
FROM core.v3_pool_burn
JOIN whitelisted_pool_view
ON  1 = 1
AND core.v3_pool_burn.chain_id        = whitelisted_pool_view.chain_id
AND LOWER(core.v3_pool_burn.contract) = ANY(LOWER(env(CONCAT(core.v3_pool_burn.chain_id, ':contracts')))::text[])
AND LOWER(core.v3_pool_burn.address)  = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version     = 'v3';

ALTER VIEW liquidity_transaction_view OWNER TO writeuser;

CREATE OR REPLACE VIEW swap_transaction_view
AS
SELECT
  'v2'                                                          AS version,
  core.v2_pair_swap.transaction_sender                          AS account,
  core.v2_pair_swap.chain_id                                    AS chain_id,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env
  (
    CONCAT
    (
      core.v2_pair_swap.chain_id,
      ':',
      whitelisted_pool_view.pool_address,
      ':name'
    )
  )                                                             AS pool_name,
  core.v2_pair_swap.block_timestamp,
  core.v2_pair_swap.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS
    (
      CASE
        WHEN core.v2_pair_swap.amount0_in IS NULL
        THEN core.v2_pair_swap.amount0_out
        WHEN core.v2_pair_swap.amount0_in = 0
        THEN core.v2_pair_swap.amount0_out
        ELSE core.v2_pair_swap.amount0_in
      END
    )
    ELSE ABS
    (
      CASE
        WHEN core.v2_pair_swap.amount1_in IS NULL
        THEN core.v2_pair_swap.amount1_out
        WHEN core.v2_pair_swap.amount1_in = 0
        THEN core.v2_pair_swap.amount1_out
        ELSE core.v2_pair_swap.amount1_in
      END
    )
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS
    (
      CASE
        WHEN core.v2_pair_swap.amount1_in IS NULL
        THEN core.v2_pair_swap.amount1_out
        WHEN core.v2_pair_swap.amount1_in = 0
        THEN core.v2_pair_swap.amount1_out
        ELSE core.v2_pair_swap.amount1_in
      END
    )
    ELSE ABS
    (
      CASE
        WHEN core.v2_pair_swap.amount0_in IS NULL
        THEN core.v2_pair_swap.amount0_out
        WHEN core.v2_pair_swap.amount0_in = 0
        THEN core.v2_pair_swap.amount0_out
        ELSE core.v2_pair_swap.amount0_in
      END
    )
  END                                                           AS token_amount
FROM core.v2_pair_swap
INNER JOIN whitelisted_pool_view
ON  1 = 1
AND core.v2_pair_swap.chain_id        = whitelisted_pool_view.chain_id
AND LOWER(core.v2_pair_swap.contract) = ANY(LOWER(env(CONCAT(core.v2_pair_swap.chain_id, ':contracts')))::text[])
AND LOWER(core.v2_pair_swap.address)  = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version     = 'v2'

UNION ALL

SELECT
  'v3'                                                          AS version,
  core.v3_pool_swap.transaction_sender                          AS account,
  core.v3_pool_swap.chain_id                                    AS chain_id,
  whitelisted_pool_view.pool_address,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token0
    ELSE whitelisted_pool_view.token1
  END                                                           AS stablecoin,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN whitelisted_pool_view.token1
    ELSE whitelisted_pool_view.token0
  END                                                           AS token,
  env
  (
    CONCAT
    (
      core.v3_pool_swap.chain_id,
      ':',
      whitelisted_pool_view.pool_address,
      ':name'
    )
  )                                                             AS pool_name,
  core.v3_pool_swap.block_timestamp,
  core.v3_pool_swap.transaction_hash,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_swap.amount0)
    ELSE ABS(core.v3_pool_swap.amount1)
  END                                                           AS stablecoin_amount,
  CASE
    WHEN whitelisted_pool_view.token0_is_stablecoin
    THEN ABS(core.v3_pool_swap.amount1)
    ELSE ABS(core.v3_pool_swap.amount0)
  END                                                           AS token_amount
FROM core.v3_pool_swap
JOIN whitelisted_pool_view
ON  1 = 1
AND core.v3_pool_swap.chain_id        = whitelisted_pool_view.chain_id
AND LOWER(core.v3_pool_swap.contract) = ANY(LOWER(env(CONCAT(core.v3_pool_swap.chain_id, ':contracts')))::text[])
AND LOWER(core.v3_pool_swap.address)  = LOWER(whitelisted_pool_view.pool_address)
AND whitelisted_pool_view.version     = 'v3';

ALTER VIEW swap_transaction_view OWNER TO writeuser;

CREATE OR REPLACE VIEW swap_point_view
AS
WITH swap_transactions
AS
(
  SELECT
    version,
    chain_id,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    stablecoin_amount / POWER(10, env(CONCAT(chain_id, ':', stablecoin, ':decimals'))::numeric) AS amount
  FROM swap_transaction_view
)
SELECT
  version,
  chain_id,
  'swap'                                                                                        AS action,
  account,
  pool_address,
  pool_name,
  block_timestamp,
  transaction_hash,
  amount,
  amount * env('swap:point')::numeric                                                           AS points,
  CASE
    WHEN get_account_by_user_id(get_referrer(account)) IS NULL
    THEN NULL
    ELSE amount * env('swap:point')::numeric * env('referral:points')::numeric
  END                                                                                           AS referral_points,
  get_account_by_user_id(get_referrer(account))                                                 AS referrer
FROM swap_transactions;

ALTER VIEW swap_point_view OWNER TO writeuser;

CREATE OR REPLACE VIEW swap_account_summary_view
AS
SELECT
  account,
  referrer,
  SUM(amount)                   AS amount,
  SUM(points)                   AS points,
  SUM(referral_points)          AS referral_points
FROM swap_point_view
GROUP BY account, referrer;

ALTER VIEW swap_account_summary_view OWNER TO writeuser;

CREATE OR REPLACE VIEW liquidity_point_view
AS
WITH stage1
AS
(
  SELECT
    version,
    chain_id,
    action,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    to_timestamp(block_timestamp)                                                                                    AS date,
    (stablecoin_amount * 2) / POWER(10, env(CONCAT(chain_id, ':', stablecoin, ':decimals'))::numeric)                AS amount,
    ROW_NUMBER() OVER (PARTITION BY account, version, chain_id, pool_address ORDER BY to_timestamp(block_timestamp)) AS row_num,
    LEAD
    (
      to_timestamp(block_timestamp),
      1,
      NOW()
    ) OVER (PARTITION BY account, version, chain_id, pool_address ORDER BY to_timestamp(block_timestamp))            AS next_date
  FROM liquidity_transaction_view
),
balances
AS
(
  SELECT
    version,
    chain_id,
    action,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    date,
    amount,
    next_date,
    CASE
      WHEN action = 'add'
      THEN amount
      ELSE -amount
    END                                                                                                              AS balance_change
  FROM stage1
),
cumulative
AS
(
  SELECT
    version,
    chain_id,
    action,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    date,
    amount,
    next_date,
    SUM(balance_change) OVER (PARTITION BY account, version, chain_id, pool_address ORDER BY date)                   AS balance,
    next_date - date                                                                                                 AS total_duration
  FROM balances
),
daily_points_calculation
AS
(
  SELECT
    version,
    chain_id,
    action,
    account,
    pool_address,
    pool_name,
    block_timestamp,
    transaction_hash,
    amount,
    date,
    GREATEST(balance, 0)                                                                                             AS balance,
    EXTRACT(EPOCH FROM total_duration) / 86400                                                                       AS days,
    GREATEST(balance, 0) * env('liquidity:point')::numeric                                                           AS points_per_day
  FROM cumulative
)
SELECT
  version,
  chain_id,
  action,
  account,
  pool_address,
  pool_name,
  block_timestamp,
  transaction_hash,
  amount,
  date,
  balance,
  days,
  points_per_day * days                                                                                              AS points,
  CASE
    WHEN get_account_by_user_id(get_referrer(account)) IS NULL
    THEN NULL
    ELSE points_per_day * days * env('referral:points')::numeric
  END                                                                                                                AS referral_points,
  get_account_by_user_id(get_referrer(account))                                                                      AS referrer
FROM daily_points_calculation;

ALTER VIEW liquidity_point_view OWNER TO writeuser;


CREATE OR REPLACE VIEW liquidity_account_summary_view
AS
SELECT
  account,
  referrer,
  SUM(amount)                   AS amount,
  SUM(points)                   AS points,
  SUM(referral_points)          AS referral_points
FROM liquidity_point_view
GROUP BY account, referrer;

ALTER VIEW liquidity_account_summary_view OWNER TO writeuser;

CREATE OR REPLACE VIEW point_detail_view
AS
SELECT version, chain_id, action, account, pool_name, block_timestamp, transaction_hash, amount, points
FROM swap_point_view
UNION ALL
SELECT version, chain_id, action, account, pool_name, block_timestamp, transaction_hash, amount, points
FROM liquidity_point_view;

ALTER VIEW point_detail_view OWNER TO writeuser;

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
