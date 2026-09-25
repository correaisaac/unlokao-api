defmodule UnlokaoWeb.LimiteDeTentativasTest do
  # Mexe na configuração global, então não roda em paralelo com outros testes.
  use UnlokaoWeb.ConnCase, async: false

  setup do
    original = Application.fetch_env!(:unlokao, :limites_de_tentativas)

    Application.put_env(:unlokao, :limites_de_tentativas,
      login: {3, :timer.minutes(1)},
      esqueci_senha: {2, :timer.hours(1)}
    )

    on_exit(fn -> Application.put_env(:unlokao, :limites_de_tentativas, original) end)

    # IP único por teste, para os contadores não se misturarem.
    ip = {10, 0, :rand.uniform(254), :rand.uniform(254)}
    %{conn: %{build_conn() | remote_ip: ip}, ip: ip}
  end

  test "bloqueia o login com 429 depois do limite", %{conn: conn, ip: ip} do
    for _ <- 1..3 do
      assert %{status: 401} =
               post(%{conn | remote_ip: ip}, ~p"/api/login", email: "a@b.c", senha: "x")
    end

    conn = post(%{conn | remote_ip: ip}, ~p"/api/login", email: "a@b.c", senha: "x")
    assert %{"detail" => _} = json_response(conn, 429)["errors"]
    assert [segundos] = get_resp_header(conn, "retry-after")
    assert String.to_integer(segundos) in 1..60
  end

  test "limita o esqueci minha senha separado do login", %{conn: conn, ip: ip} do
    for _ <- 1..2,
        do:
          assert(
            %{status: 204} = post(%{conn | remote_ip: ip}, ~p"/api/senha/esqueci", email: "a@b.c")
          )

    assert json_response(
             post(%{conn | remote_ip: ip}, ~p"/api/senha/esqueci", email: "a@b.c"),
             429
           )

    assert %{status: 401} =
             post(%{conn | remote_ip: ip}, ~p"/api/login", email: "a@b.c", senha: "x")
  end

  test "atrás de proxy, conta pelo IP do cliente no X-Forwarded-For", %{ip: ip} do
    proxy = {10, 1, 1, 1}
    cliente = "203.0.113.#{:rand.uniform(254)}"

    login = fn ->
      %{build_conn() | remote_ip: proxy}
      |> put_req_header("x-forwarded-for", cliente)
      |> post(~p"/api/login", email: "a@b.c", senha: "x")
    end

    for _ <- 1..3, do: assert(%{status: 401} = login.())
    assert %{status: 429} = login.()

    # Outro cliente atrás do mesmo proxy não é bloqueado
    assert %{status: 401} =
             post(%{build_conn() | remote_ip: ip}, ~p"/api/login", email: "a@b.c", senha: "x")
  end

  test "outro IP não é afetado", %{conn: conn, ip: ip} do
    for _ <- 1..4, do: post(%{conn | remote_ip: ip}, ~p"/api/login", email: "a@b.c", senha: "x")

    assert %{status: 401} =
             post(%{conn | remote_ip: {10, 255, 255, 1}}, ~p"/api/login",
               email: "a@b.c",
               senha: "x"
             )
  end
end
