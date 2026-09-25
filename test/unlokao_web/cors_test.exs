defmodule UnlokaoWeb.CorsTest do
  use UnlokaoWeb.ConnCase

  test "preflight de origem permitida libera Authorization e Content-Type", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "http://localhost:5173")
      |> put_req_header("access-control-request-method", "POST")
      |> put_req_header("access-control-request-headers", "authorization,content-type")
      |> options(~p"/api/login")

    assert conn.status == 204
    assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:5173"]
    [cabecalhos] = get_resp_header(conn, "access-control-allow-headers")
    assert cabecalhos =~ "Authorization"
    assert cabecalhos =~ "Content-Type"
  end

  test "origem não permitida não recebe o cabeçalho", %{conn: conn} do
    conn = conn |> put_req_header("origin", "https://site-malicioso.com") |> get(~p"/api/me")
    assert get_resp_header(conn, "access-control-allow-origin") == []
  end
end
