CREATE OR REPLACE FUNCTION get_stablecoin_value(_chain_id uint256, _amount numeric(100, 32))
RETURNS numeric(100, 32)
IMMUTABLE
AS
$$
BEGIN
  IF(_chain_id IN (56)) THEN
    RETURN _amount / POWER(10, 18)::numeric(100, 32);  
  END IF;

  RETURN _amount / POWER(10, 6)::numeric(100, 32);
END
$$
LANGUAGE plpgsql;
