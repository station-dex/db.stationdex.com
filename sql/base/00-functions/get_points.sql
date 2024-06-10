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

