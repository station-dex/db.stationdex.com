CREATE OR REPLACE FUNCTION quote_literal_ilike(_ilike text)
RETURNS text
IMMUTABLE
AS
$$
BEGIN
  RETURN quote_literal(CONCAT('%', TRIM(_ilike), '%'));
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION quote_literal_ilike OWNER TO writeuser;
