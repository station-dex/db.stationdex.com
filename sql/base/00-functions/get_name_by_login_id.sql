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
