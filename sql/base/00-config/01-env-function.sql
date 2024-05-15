CREATE OR REPLACE FUNCTION env(_key text, _value text)
RETURNS void
AS
$$
BEGIN
  IF(_value IS NULL) THEN
    DELETE FROM environment_variables
    WHERE LOWER(key) = LOWER(_key);
    RETURN;
  END IF;

  INSERT INTO environment_variables(key, value)
  VALUES (_key, _value)
  ON CONFLICT (key)
  DO UPDATE SET value = _value;
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION env(_key text, _value text) OWNER TO writeuser;

CREATE OR REPLACE FUNCTION env(_key text)
RETURNS text
STABLE PARALLEL SAFE
AS
$$
BEGIN
  RETURN value FROM environment_variables
  WHERE LOWER(key) = LOWER(_key);
END
$$
LANGUAGE plpgsql;

ALTER FUNCTION env(_key text) OWNER TO writeuser;
