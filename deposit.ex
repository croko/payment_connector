defmodule AppWeb.Connector.Provider.Deposit do
  use AppWeb, :connector
  alias AppWeb.Connector.Provider.Validator
  alias AppWeb.Connector.Provider.ParamsBuilder
  alias AppWeb.Service.Redis

  @required_fields ~w(provider_code amount currency first_name last_name email address dob city state country phone document_type document_number sex payment_method transaction_id success_url fail_url notify_url)a
  @optional_fields ~w()a

  defp url(), do: Application.get_env(:app, :connector)[:provider]
  def access_token_key(), do: "provider/access_token"
  def refresh_token_key(), do: "provider/refresh_token"

  def request(connector) do
    connector
    |> cast(@required_fields ++ @optional_fields)
    |> Validator.validate(@required_fields)
  end

  def send(connector) do
    with %{access_token: access_token} <- access_token_from_cache(connector) do
      request_data = %{
        url: "#{url()}/checkout_path",
        body: ParamsBuilder.deposit_params(connector),
        header: headers(connector, access_token),
        type: :deposit
      }

      Request.post(connector, request_data)
      |> case do
        {:redirect, redirect_url} ->
          Request.redirect(connector, redirect_url, %{}, "_blank")

        response ->
          response
      end
    else
      error -> error
    end
  end

  def get_access_token(connector) do
    Request.post(connector, access_token_data(connector))
    |> store_tokens(connector)
  end

  def get_access_token(connector, refresh_token) do
    Request.post(connector, refresh_token_data(connector, refresh_token))
    |> store_tokens(connector)
  end

  def access_token_data(connector) do
    %{
      url: "#{url()}/token",
      header: access_token_header(connector),
      body: ParamsBuilder.access_token(connector),
      type: :get_token
    }
  end

  defp refresh_token_data(connector, refresh_token) do
    %{
      url: "#{url()}/token",
      header: access_token_header(connector),
      body: ParamsBuilder.refresh_token(refresh_token),
      type: :refresh_token
    }
  end

  defp access_token_header(%{
         credentials: %{"apikey" => apikey}
       }),
       do: [{"content-type", "application/x-www-form-urlencoded"}, {"apikey", "#{apikey}"}]

  def headers(
        %{
          params: %{
            fail_url: fail_url,
            success_url: success_url,
            notify_url: notify_url,
            transaction_id: transaction_id
          },
          credentials: %{"apikey" => apikey}
        },
        access_token
      ) do
    [
      {"Content-Type", "application/json"},
      {"apikey", "#{apikey}"},
      {"X-User-Bearer", "#{access_token}"},
      {"X-CorrelationID", UUID.uuid4()},
      {"X-Redirect-OK", success_url},
      {"X-Redirect-Error", fail_url},
      {"X-Callback-URL", "#{notify_url}?our_transaction_id=#{transaction_id}"},
      {"X-Channel", "WS"}
    ]
  end

  def access_token_from_cache(
        %{
          credentials: %{"username" => username}
        } = connector
      ) do
    Redis.get("#{access_token_key()}_#{username}")
    |> case do
      nil -> refresh_token_from_cache(connector)
      access_token when is_binary(access_token) -> %{access_token: access_token}
    end
  end

  def refresh_token_from_cache(
        %{
          credentials: %{"username" => username}
        } = connector
      ) do
    Redis.get("#{refresh_token_key()}_#{username}")
    |> case do
      nil -> get_access_token(connector)
      refresh_token when is_binary(refresh_token) -> get_access_token(connector, refresh_token)
    end
  end

  def store_tokens(
        %{
          "access_token" => access_token,
          "refresh_token" => refresh_token,
          "expires_in" => expires_in,
          "refresh_expires_in" => refresh_expires_in
        },
        %{
          credentials: %{"username" => username}
        } = _connector
      ) do
    Redis.setex("#{access_token_key()}_#{username}", access_token, expires_in - 30)
    Redis.setex("#{refresh_token_key()}_#{username}", refresh_token, refresh_expires_in - 30)
    %{access_token: access_token}
  end

  # get banks request
  def store_tokens(
        {:ok,
         %{
           "access_token" => access_token,
           "refresh_token" => refresh_token,
           "expires_in" => expires_in,
           "refresh_expires_in" => refresh_expires_in
         }},
        %{
          credentials: %{"username" => username}
        } = _connector
      ) do
    Redis.setex("#{access_token_key()}_#{username}", access_token, expires_in - 30)
    Redis.setex("#{refresh_token_key()}_#{username}", refresh_token, refresh_expires_in - 30)
    %{access_token: access_token}
  end

  def store_tokens(_, _), do: %{access_token: nil}
end
