import Config

config :thistle_tea, :map_dir, "maps"
config :thistle_tea, ecto_repos: [ThistleTea.DBC, ThistleTea.Mangos]
config :thistle_tea, ThistleTea.DBC, database: "db/dbc.sqlite", log: false
config :thistle_tea, ThistleTea.Mangos, database: "db/mangos0.sqlite", log: false

config :mnesia, dir: ~c".mnesia/#{Mix.env()}/#{node()}"

config :logger, :default_formatter,
  format: "[$level] $message $metadata\n",
  metadata: [
    :username,
    :character_name,
    :target_name,
    :file,
    :pid,
    :mfa,
    :error_code
  ]

import_config "runtime.exs"
