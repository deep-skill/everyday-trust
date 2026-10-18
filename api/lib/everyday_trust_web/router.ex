defmodule EverydayTrustWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
    plug EverydayTrustWeb.Access
  end

  get "/api/v1/health", EverydayTrustWeb.CaseController, :health

  scope "/api/v1" do
    pipe_through :api
    get "/stats", EverydayTrustWeb.CaseController, :stats
    post "/visits", EverydayTrustWeb.CaseController, :visit
    post "/cases", EverydayTrustWeb.CaseController, :create
    get "/cases/:id", EverydayTrustWeb.CaseController, :show
    post "/cases/:id/save", EverydayTrustWeb.CaseController, :save
    post "/cases/:id/messages", EverydayTrustWeb.CaseController, :message
    post "/cases/:id/feedback", EverydayTrustWeb.CaseController, :feedback
    post "/cases/:id/review", EverydayTrustWeb.CaseController, :review
    delete "/cases/:id/review", EverydayTrustWeb.CaseController, :delete_review
    get "/history", EverydayTrustWeb.CaseController, :history
    get "/history/:id", EverydayTrustWeb.CaseController, :saved
    delete "/history/:id", EverydayTrustWeb.CaseController, :delete
    get "/me", EverydayTrustWeb.CaseController, :me
    delete "/me", EverydayTrustWeb.CaseController, :delete_account
  end
end
