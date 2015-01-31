defmodule DirectTest do
  use ExUnit.Case
  import PathHelpers

  setup_all do
    {:ok, pid} = HTTPotion.spawn_worker_process("http://httpbin.org")
    Process.register(pid, :non_pooled_connection)
    :ok
  end

  test "get" do
    assert_response HTTPotion.get("httpbin.org", [direct: :non_pooled_connection]), fn(response) ->
      assert match?(<<60, 33, 68, 79, _ :: binary>>, response.body)
    end
  end

  test "head" do
    assert_response HTTPotion.head("httpbin.org/get", [direct: :non_pooled_connection]), fn(response) ->
      assert response.body == ""
    end
  end

  test "post charlist body" do
    assert_response HTTPotion.post("httpbin.org/post", 'test', [direct: :non_pooled_connection])
  end

  test "post binary body" do
    { :ok, file } = File.read(fixture_path("image.png"))

    assert_response HTTPotion.post("httpbin.org/post", file, [direct: :non_pooled_connection])
  end

  test "put" do
    assert_response HTTPotion.put("httpbin.org/put", "test", [direct: :non_pooled_connection])
  end

  test "patch" do
    assert_response HTTPotion.patch("httpbin.org/patch", "test", [direct: :non_pooled_connection])
  end

  test "delete" do
    assert_response HTTPotion.delete("httpbin.org/delete", "test", [direct: :non_pooled_connection])
  end

  test "options" do
    assert_response HTTPotion.options("httpbin.org/get", [direct: :non_pooled_connection]), fn(response) ->
      assert response.headers[:"Content-Length"] == "0"
      assert is_binary(response.headers[:Allow])
    end
  end

  test "headers" do
    assert_response HTTPotion.head("http://httpbin.org/cookies/set?first=foo&second=bar", [direct: :non_pooled_connection]), fn(response) ->
      assert_list response.headers[:"Set-Cookie"], ["first=foo; Path=/", "second=bar; Path=/"]
    end
  end

  test "ibrowse option" do
    ibrowse = [basic_auth: {'foo', 'bar'}]
    assert_response HTTPotion.get("http://httpbin.org/basic-auth/foo/bar", [], [ ibrowse: ibrowse, direct: :non_pooled_connection ])
  end

  test "explicit http scheme" do
    assert_response HTTPotion.head("http://httpbin.org/get", [direct: :non_pooled_connection])
  end

  test "https scheme" do
    assert_response HTTPotion.head("https://httpbin.org/get", [direct: :non_pooled_connection])
  end

  test "char list URL" do
    assert_response HTTPotion.head('httpbin.org/get', [direct: :non_pooled_connection])
  end

  test "exception" do
    assert_raise HTTPotion.HTTPError, "econnrefused", fn ->
      HTTPotion.get "localhost:1", [direct: :non_pooled_connection]
    end
  end

  test "extension" do
    defmodule TestClient do
      use HTTPotion.Base

      def process_url(url) do
        send(self, :ok)

        super(url)
      end
    end

    TestClient.head("httpbin.org/get", [direct: :non_pooled_connection])

    assert_received :ok
  end

  test "asynchronous request" do
    ibrowse = [basic_auth: {'foo', 'bar'}]
    %HTTPotion.AsyncResponse{ id: id } = HTTPotion.get "httpbin.org/basic-auth/foo/bar", [], [stream_to: self, ibrowse: ibrowse, direct: :non_pooled_connection]

    assert_receive %HTTPotion.AsyncHeaders{ id: ^id, status_code: 200, headers: _headers }, 1_000
    assert_receive %HTTPotion.AsyncChunk{ id: ^id, chunk: _chunk }, 1_000
    assert_receive %HTTPotion.AsyncEnd{ id: ^id }, 1_000
  end

  defp assert_response(response, function \\ nil) do
    assert HTTPotion.Response.success?(response, :extra)
    assert response.headers[:Connection] == "keep-alive"
    assert is_binary(response.body)

    unless function == nil, do: function.(response)
  end

  defp assert_list(value, expected) do
    Enum.sort(value) == expected
  end
end
