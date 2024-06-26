CREATE OR REPLACE FUNCTION get_referrals
(
  _login_id                                       uuid,
  _referral_code                                  text,
  _page_number                                    integer,
  _search_account                                 text
)
RETURNS TABLE
(
  moniker                                         text,
  account                                         address,
  points                                          numeric,
  referral_points                                 numeric,
  referral_code                                   character varying(32),
  referrer		                                    uuid,
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
  DECLARE _referrer_id                            uuid = get_user_id_by_login_id(_login_id);
BEGIN
  IF _page_number < 1 THEN
    _page_number := 1;
  END IF;

  _query := format('
    WITH result
    AS
    (
      SELECT * FROM referral_point_view
      WHERE 1 = 1
      AND referrer=%s
      AND referral_code=%s
      AND account ILIKE %s
    )', quote_literal(_referrer_id), quote_literal(_referral_code), quote_literal_ilike(_search_account));

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
          moniker,
          account,
          points::numeric(20, 2),
          referral_points::numeric(20, 2),
          referral_code,
          referrer,
          %s AS page_size,
          %s AS page_number,
          %s AS total_records,
          %s AS total_pages
        FROM result
        ORDER BY points ASC
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

ALTER FUNCTION get_referrals OWNER TO writeuser;