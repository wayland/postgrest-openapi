-- Default PostgREST OpenAPI Specification

create or replace function callable_root() returns jsonb as $$
	-- Calling this every time is inefficient, but it's the best we can do until PostgREST calls it when it updates the server config
	CALL set_server_from_configuration();
	SELECT get_postgrest_openapi_spec(
		schemas := string_to_array(current_setting('pgrst.db_schemas', TRUE), ','),
		version := 'not-spec'
	);
$$ language sql;

create or replace function get_postgrest_openapi_spec(
  schemas text[],
  version text default null
)
returns jsonb language sql as
$$
select openapi_object(
  openapi := '3.1.0',
  info := openapi_info_object(
    title := coalesce(sd.title, 'PostgREST API'),
    description := coalesce(sd.description, 'This is a dynamic API generated by PostgREST'),
    -- The document version
    version := 'undefined' -- Really we want to give the user some way to set this, so they can release new versions of their API
  ),
  xsoftware := jsonb_build_array(
    -- The version of the OpenAPI extension
    openapi_x_software_object(
      name := 'OpenAPI',
      version := version,
      description := 'Automatically/dynamically generate an OpenAPI schema for the API generated by PostgREST'
    ),
    -- The version of PostgREST
    openapi_x_software_object(
      name := 'PostgREST API',
      version := postgrest_get_version(),
      description := 'Automatically/dynamically turns a PostgreSQL database directly into a RESTful API'
    )
  ),
  servers := openapi_server_objects(),
  paths := '{}',
  components := openapi_components_object(
    schemas := postgrest_tables_to_openapi_schema_components(schemas) || postgrest_composite_types_to_openapi_schema_components(schemas)
  )
)
from postgrest_get_schema_description(schemas[1]) sd;
$$;
