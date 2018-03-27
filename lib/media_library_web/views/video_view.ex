defmodule MediaLibraryWeb.VideoView do
  use MediaLibraryWeb, :view

  alias MediaLibrary.FileUtils

  def get_thumbnail_url(video, user) do
    FileUtils.build_thumbnail_url(video, user)
  end
end
