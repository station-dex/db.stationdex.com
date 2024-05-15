CREATE TABLE IF NOT EXISTS environment_variables
(
  key                                            text NOT NULL PRIMARY KEY,
  value                                          text NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS environment_variables_key_uix
ON environment_variables(LOWER(key));

ALTER TABLE environment_variables OWNER TO writeuser;
