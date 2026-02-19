defmodule SelectoTest.SavedViewConfigContextTest do
  use SelectoTest.DataCase, async: true

  alias SelectoComponents.Form.ParamsState
  alias SelectoTest.PagilaDomainFilms

  @context "/pagila/films"
  @view_type "detail"
  @user_id "denorm_test_user"

  describe "saved detail views with denormalization setting" do
    test "round-trips a denorm-enabled saved view and reconstructs params" do
      params = saved_detail_view_payload(true)

      assert {:ok, saved} =
               PagilaDomainFilms.save_view_config(
                 "detail_denorm_on",
                 @context,
                 @view_type,
                 params,
                 user_id: @user_id
               )

      loaded =
        PagilaDomainFilms.load_view_config(
          "detail_denorm_on",
          @context,
          @view_type,
          user_id: @user_id
        )

      assert loaded.id == saved.id

      decoded = PagilaDomainFilms.decode_view_config(loaded)
      assert get_in(decoded, ["detail", "prevent_denormalization"]) == true

      full_params = ParamsState.convert_saved_config_to_full_params(decoded, @view_type)

      assert full_params["view_mode"] == "detail"
      assert full_params["prevent_denormalization"] == "true"
      assert full_params["per_page"] == "30"

      selected_fields =
        full_params
        |> Map.fetch!("selected")
        |> Map.values()
        |> Enum.map(&Map.get(&1, "field"))

      assert "title" in selected_fields
      assert "film_actors.actor.last_name" in selected_fields
    end

    test "supports separate saved views for denorm on/off in the same context" do
      assert {:ok, _} =
               PagilaDomainFilms.save_view_config(
                 "detail_denorm_on",
                 @context,
                 @view_type,
                 saved_detail_view_payload(true),
                 user_id: @user_id
               )

      assert {:ok, _} =
               PagilaDomainFilms.save_view_config(
                 "detail_denorm_off",
                 @context,
                 @view_type,
                 saved_detail_view_payload(false),
                 user_id: @user_id
               )

      names = PagilaDomainFilms.get_view_config_names(@context, @view_type, user_id: @user_id)
      assert "detail_denorm_on" in names
      assert "detail_denorm_off" in names

      loaded_off =
        PagilaDomainFilms.load_view_config(
          "detail_denorm_off",
          @context,
          @view_type,
          user_id: @user_id
        )

      off_params =
        loaded_off
        |> PagilaDomainFilms.decode_view_config()
        |> ParamsState.convert_saved_config_to_full_params(@view_type)

      assert off_params["prevent_denormalization"] == "false"
    end
  end

  defp saved_detail_view_payload(prevent_denormalization?) do
    %{
      "detail" => %{
        "selected" => [
          ["col_1", "title", %{}],
          ["col_2", "film_actors.actor.last_name", %{"alias" => "Actor Last Name"}]
        ],
        "order_by" => [
          ["ord_1", "title", %{"dir" => "asc"}]
        ],
        "per_page" => "30",
        "prevent_denormalization" => prevent_denormalization?
      }
    }
  end
end
