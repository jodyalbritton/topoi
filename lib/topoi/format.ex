defmodule Topoi.Format do
  @moduledoc "Small formatting helpers shared by the core and the web layer."

  @doc "A millisecond offset as `m:ss` or `h:mm:ss`."
  def clock(ms) when is_integer(ms) and ms >= 0 do
    total = div(ms, 1000)
    {h, m, s} = {div(total, 3600), div(rem(total, 3600), 60), rem(total, 60)}
    pad = &String.pad_leading(Integer.to_string(&1), 2, "0")
    if h > 0, do: "#{h}:#{pad.(m)}:#{pad.(s)}", else: "#{m}:#{pad.(s)}"
  end
end
