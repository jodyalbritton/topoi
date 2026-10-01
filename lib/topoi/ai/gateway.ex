defmodule Topoi.AI.Gateway do
  @moduledoc """
  The app's one door to Airo (PRD §7). Wraps `AiroClient` with the
  saved `Topoi.Settings.Gateway` row; nothing else reads gateway config.
  Every call returns `{:error, :not_configured}` when the row is
  incomplete, so callers degrade instead of raising.
  """

  alias Topoi.Settings
  alias Topoi.Settings.Gateway, as: Config

  @doc """
  Chat completion with the configured chat model. Options:
  `:json_schema` (`%{"name" => ..., "schema" => ...}`) requests strict
  structured output; `:thinking` (default `false`) — local Qwen models
  return no `content` with thinking on (mem_pal lesson); `:model`
  overrides the alias. Returns `{:ok, response_body}`.
  """
  def chat(messages, opts \\ []) when is_list(messages) do
    with {:ok, config} <- configured() do
      params =
        %{"model" => Keyword.get(opts, :model, config.chat_model), "messages" => messages}
        |> put_schema(Keyword.get(opts, :json_schema))
        |> put_thinking(Keyword.get(opts, :thinking, false))
        |> Map.merge(Keyword.get(opts, :params, %{}))

      AiroClient.chat(params, client_opts(config))
    end
  end

  @doc "The gateway's model catalog for `config` (used by the settings page's connection test)."
  def model_catalog(%Config{} = config) do
    if Config.configured?(config),
      do: AiroClient.model_catalog(client_opts(config, receive_timeout: 10_000)),
      else: {:error, :not_configured}
  end

  @doc "Model ids grouped by capability: `%{chat: [...], embeddings: [...]}`."
  def models_by_capability(catalog) when is_list(catalog) do
    pick = fn cap ->
      for %{"id" => id} = m <- catalog, cap in (m["capabilities"] || []), do: id
    end

    %{chat: pick.("chat"), embeddings: pick.("embeddings")}
  end

  def configured?, do: match?({:ok, _}, configured())

  defp configured do
    config = Settings.get(Config)
    if Config.configured?(config), do: {:ok, config}, else: {:error, :not_configured}
  end

  defp put_schema(params, nil), do: params

  defp put_schema(params, %{} = schema),
    do:
      Map.put(params, "response_format", %{
        "type" => "json_schema",
        "json_schema" => Map.put_new(schema, "strict", true)
      })

  defp put_thinking(params, true), do: params

  defp put_thinking(params, false),
    do: Map.put(params, "chat_template_kwargs", %{"enable_thinking" => false})

  defp client_opts(config, extra \\ []) do
    [
      base_url: config.base_url,
      api_key: config.api_key,
      req_options: Application.get_env(:topoi, __MODULE__, [])[:req_options] || []
    ]
    |> Keyword.merge(extra)
  end
end
