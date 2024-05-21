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
