CREATE SCHEMA meta;

CREATE TABLE IF NOT EXISTS meta.locks
(
  id                                                BIGSERIAL PRIMARY KEY NOT NULL,
  project_id                                        text,
  created_at                                        TIMESTAMP WITH TIME ZONE DEFAULT (NOW())
);

CREATE UNIQUE INDEX IF NOT EXISTS locks_ensure_unique_uix
ON meta.locks (LOWER(project_id));

-- SELECT * FROM meta.locks;

CREATE TABLE IF NOT EXISTS meta.progress_tracker
(
  project_id                    text PRIMARY KEY NOT NULL,
  synced_upto_block_number      integer,
  synced_upto_log_index         integer
);

CREATE UNIQUE INDEX IF NOT EXISTS progress_tracker_project_id_uix
ON meta.progress_tracker (LOWER(project_id));

CREATE OR REPLACE FUNCTION meta.update_progress
(
  _project_id                   text,
  _block_number                 integer,
  _log_index                    integer
)
RETURNS void
AS
$$
BEGIN
  INSERT INTO meta.progress_tracker
    (
      project_id,
      synced_upto_block_number,
      synced_upto_log_index
    )
    VALUES
    (
      _project_id,
      _block_number,
      _log_index
    ) 
    ON CONFLICT (project_id)
    DO UPDATE
    SET
      synced_upto_block_number = _block_number,
      synced_upto_log_index = _log_index;
END
$$
LANGUAGE plpgsql;

-- SELECT * FROM meta.progress_tracker;

--
