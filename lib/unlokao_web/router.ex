defmodule UnlokaoWeb.Router do
  use UnlokaoWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", UnlokaoWeb do
    pipe_through :api

    resources "/chaves", ChaveController, except: [:new, :edit]
    resources "/usuarios", UsuarioController, except: [:new, :edit]
  end
end
