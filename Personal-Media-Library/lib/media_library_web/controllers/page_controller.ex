defmodule MediaLibraryWeb.PageController do
  use MediaLibraryWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
