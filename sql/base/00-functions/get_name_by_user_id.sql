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
