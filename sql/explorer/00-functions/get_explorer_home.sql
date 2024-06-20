CREATE OR REPLACE FUNCTION get_explorer_home
(
  _sort_by                                                              text,
  _sort_direction                                                       text,
  _page_number                                                          integer,
  _page_size                                                            integer,
  _date_from                                                            TIMESTAMP WITH TIME ZONE,
  _date_to                                                              TIMESTAMP WITH TIME ZONE,
  _networks                                                             numeric[],
  _contracts                                                            text[],
  _event_name_like                                                      text,
  _transaction_sender_like                                              text,
  _transaction_hash_like                                                text,
  _block_number_like                                                    text
)
RETURNS TABLE
(
  id                                                                    uuid,
  chain_id                                                              uint256,
  date                                                                  TIMESTAMP WITH TIME ZONE,
  event_name                                                            text,
  transaction_sender                                                    address,
  contract                                                              address,
  transaction_hash                                                      text,
  block_number                                                          text,
  page_size                                                             integer,
  page_number                                                           integer,
  total_records                                                         integer,
  total_pages                                                           integer
)
STABLE
AS
$$
  DECLARE _total_records                                                integer;
  DECLARE _total_pages                                                  integer;
  DECLARE _query                                                        text;
BEGIN
  IF(COALESCE(_sort_direction, '') = '') THEN
    _sort_direction := 'ASC';
  END IF;
  
  IF(_sort_direction NOT IN ('ASC', 'DESC')) THEN
    RAISE EXCEPTION 'Access is denied. Invalid sort_direction: "%"', _sort_direction; --SQL Injection Attack
  END IF;

  IF(_networks IS NULL) THEN
    _networks := array_agg(DISTINCT core.transactions.chain_id) FROM core.transactions;
  END IF;

  IF(_contracts IS NULL) THEN
    _contracts := array_agg(DISTINCT core.transactions.address) FROM core.transactions;  
  END IF;

  IF(_sort_by NOT IN('chain_id', 'date', 'event_name', 'transaction_sender', 'contract', 'block_number', 'transaction_hash')) THEN
    RAISE EXCEPTION 'Access is denied. Invalid sort_by: "%"', _sort_by; --SQL Injection Attack
  END IF;
  
  IF(_sort_by = 'date') THEN
    _sort_by := 'block_timestamp';
  END IF;
      
  IF(_page_number < 1) THEN
    RAISE EXCEPTION 'Invalid page_number value %', _page_number;  
  END IF;
  
  IF(_page_size < 1) THEN
    RAISE EXCEPTION 'Invalid _page_size value %', _page_size;  
  END IF;
  
  
  _query := format('
  WITH result AS
  (
    SELECT * FROM core.transactions
    WHERE core.transactions.block_timestamp
    BETWEEN
      EXTRACT(epoch FROM COALESCE(%L, ''-infinity''::date))
      AND EXTRACT(epoch FROM COALESCE(%L, ''infinity''::date))  
    AND core.transactions.chain_id                                      = ANY(%L)
    AND core.transactions.address                                       = ANY(%L)
    AND core.transactions.event_name                                    ILIKE %s
    AND core.transactions.transaction_sender                            ILIKE %s
    AND core.transactions.transaction_hash                              ILIKE %s
    AND core.transactions.block_number                                  ILIKE %s
  )
  SELECT COUNT(*) FROM result;', _date_from, _date_to, _networks, _contracts, quote_literal_ilike(_event_name_like), quote_literal_ilike(_transaction_sender_like), quote_literal_ilike(_transaction_hash_like), quote_literal_ilike(_block_number_like));
  
  EXECUTE _query
  INTO _total_records;
  
  _total_pages = COALESCE(CEILING(_total_records::numeric / _page_size), 0);
  
  _query := format('
  SELECT
    core.transactions.id,
    core.transactions.chain_id,
    to_timestamp(core.transactions.block_timestamp)::TIMESTAMP WITH TIME ZONE AS date,
    core.transactions.event_name,
    core.transactions.transaction_sender,
    core.transactions.address,
    core.transactions.transaction_hash,
    core.transactions.block_number,
    %s                                                                  AS page_size,
    %s                                                                  AS page_number,
    %s                                                                  AS total_records,
    %s                                                                  AS total_pages
  FROM core.transactions
  WHERE core.transactions.block_timestamp
  BETWEEN 
    EXTRACT(epoch FROM COALESCE(%L, ''-infinity''::date))
    AND EXTRACT(epoch FROM COALESCE(%L, ''infinity''::date))
  AND core.transactions.chain_id                                        = ANY(%L)
  AND core.transactions.address                                         = ANY(%L)
  AND core.transactions.event_name                                      ILIKE %s
  AND core.transactions.transaction_sender                              ILIKE %s
  AND core.transactions.transaction_hash                                ILIKE %s
  AND core.transactions.block_number                                    ILIKE %s
  ORDER BY %I %s
  LIMIT %s::integer
  OFFSET %s::integer * %s::integer  
  ', _page_size, _page_number, _total_records, _total_pages, _date_from, _date_to, _networks, _contracts, quote_literal_ilike(_event_name_like), quote_literal_ilike(_transaction_sender_like), quote_literal_ilike(_transaction_hash_like), quote_literal_ilike(_block_number_like), _sort_by, _sort_direction, _page_size, _page_number - 1, _page_size);

  RETURN QUERY EXECUTE _query;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION get_explorer_home OWNER TO writeuser;

-- SELECT * FROM get_explorer_home
-- (
--   'date',           --_sort_by                                       text,
--   'DESC',           --_sort_direction                                text,
--   1,                --_page_number                                   integer,
--   2,                --_page_size                                     integer,
--   NULL,             --_date_from                                     TIMESTAMP WITH TIME ZONE,
--   '1-1-2099'::date, --_date_to                                       TIMESTAMP WITH TIME ZONE,
--   NULL,             --_networks                                      numeric[],
--   NULL,             --_contracts                                     text[],
--   '',               --_event_name_like                               text,
--   '',               --_transaction_sender_like                       text
--   '',               --_transaction_hash_like                         text
--   ''                --_block_number_like                             text
-- );
