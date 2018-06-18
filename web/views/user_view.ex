defmodule Shield.UserView do
  use Shield.Web, :view

  def render("index.json", %{users: users}) do
    %{users: render_many(users, __MODULE__, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{user: render_one(user, __MODULE__, "user.json")}
  end

  def render("user.json", %{user: user}) do
    json = %{id: user.id, email: user.email}
    if is_nil(user.settings), do: json,
                              else: Map.put(json, :settings, user.settings)
  end
end
