defmodule Topoi.Samples do
  @moduledoc """
  Local gold samples (gitignored, PRD §14). Tests that need them are
  tagged `:samples` and skipped when the files are absent.
  """
  @root Path.expand("../../docs/samples", __DIR__)
  @tmp Path.expand("../../tmp/elevenlabs", __DIR__)

  def srt(id), do: Path.join(@root, "#{id}.elevenlabs.srt.txt")
  def elevenlabs_json(id), do: Path.join(@tmp, "#{id}.json")

  def present?(path), do: File.exists?(path)
end
