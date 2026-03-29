import Config

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      Variável de ambiente DATABASE_PATH não definida.
      Exemplo: /app/data/w_core_prod.db
      """

  config :w_core, WCore.Repo,
    database: database_path,
    pool_size: 1

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      Variável de ambiente SECRET_KEY_BASE não definida.
      Gere uma com: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  port = String.to_integer(System.get_env("PORT", "4000"))

  config :w_core, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :w_core, WCoreWeb.Endpoint,
    server: true,
    check_origin: false,
    url: [host: host, port: port, scheme: "http"],
    http: [
      port: port,
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base
end
