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
