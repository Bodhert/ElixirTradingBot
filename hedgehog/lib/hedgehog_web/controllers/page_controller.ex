defmodule HedgehogWeb.PageController do
  use HedgehogWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
