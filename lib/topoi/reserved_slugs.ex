defmodule Topoi.ReservedSlugs do
  @moduledoc """
  First path segments the app uses. Debater slugs live at the root
  (`topoi.gg/<handle>`, PRD §13.2), so none of these may be a slug.
  """
  @slugs ~w(about admin assets custom-designs debaters debates design design.json dev
            images live phoenix request schools search tags topics tidewave users)

  def all, do: @slugs
end
