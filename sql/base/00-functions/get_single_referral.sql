CREATE OR REPLACE FUNCTION get_single_referral
(
  _login_id                                       uuid,
  _referral_code                                  text
)
RETURNS TABLE
(
  referral_id                                     uuid,
  memo                                            character varying(512),
  referral_code                                   character varying(32),
  created_at                                      TIMESTAMP WITH TIME ZONE,
  total_referrals                                 integer,
  deleted                                         boolean,
  deleted_at                                      TIMESTAMP WITH TIME ZONE
)
AS
$$
  DECLARE _query                                  text;
  DECLARE _referrer_id                            uuid = get_user_id_by_login_id(_login_id);
BEGIN
  _query := format('
    SELECT
      referral_id,
      memo,
      referral_code,
      created_at,
      total_referrals,
      deleted,
      deleted_at
    FROM core.referrals
    WHERE 1 = 1
    AND referrer = %s
    AND referral_code = %s;', quote_literal(_referrer_id), quote_literal(_referral_code));

  RETURN QUERY EXECUTE _query;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_single_referral OWNER TO writeuser;