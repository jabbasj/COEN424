defmodule MediaLibraryWeb.Router do
  use MediaLibraryWeb, :router

  import MediaLibraryWeb.Auth, only: [authenticate: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    
    plug MediaLibraryWeb.Auth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MediaLibraryWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/login", MediaLibraryWeb do
    pipe_through :browser

    get "/", SessionController, :new
    post "/", SessionController, :create

    delete "/logout", SessionController, :delete

    get "/register", UserController, :new
    post "/register", UserController, :create

    get "/:provider", OAuthController, :new, as: :oauth
    get "/:provider/callback", OAuthController, :callback
  end

  scope "/app", MediaLibraryWeb do
    pipe_through :browser
    pipe_through :authenticate

    resources "/videos", VideoController
    get "/videos/info/:id", VideoController, :info
    get "/videos/transcode/:id", VideoController, :transcode
    get "/videos/stream/:id", StreamController, :stream

    get "/settings", UserController, :settings
    get "/settings/:provider", UserController, :oauth_drive
    get "/settings/sync/:provider", UserController, :sync_library
  end
end
