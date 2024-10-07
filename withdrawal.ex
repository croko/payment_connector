defmodule AppWeb.Connector.Provider.Withdrawal do
  use AppWeb, :connector
  alias AppWeb.Connector.Provider.Validator
  alias AppWeb.Connector.Provider.ParamsBuilder
  alias AppWeb.Connector.Provider.Deposit

  @required_fields ~w(provider_code amount currency bank account_number address city state email first_name last_name phone country transaction_id notify_url)a
  @optional_fields ~w(payment_concept account_type)a

  defp url(), do: Application.get_env(:app, :connector)[:provider]

  def request(connector) do
    connector
    |> cast(@required_fields ++ @optional_fields)
    |> Validator.validate(@required_fields)
  end

  def send(connector) do
    with %{access_token: access_token} <- Deposit.access_token_from_cache(connector) do
      request_data = %{
        url: "#{url()}/transactions/1.0/transactions/type/withdrawal",
        body: ParamsBuilder.deposit_params(connector),
        header: headers(connector, access_token),
        type: :withdrawal
      }

      Request.post(connector, request_data)
      |> case do
        {:ok, %{"transactionStatus" => "finished"}} ->
          {:ok, "success"}

        {:ok, %{"transactionStatus" => status}}
        when status in ~w(waiting processing conciliate pending reserved) ->
          {:pending, "pending"}

        {:ok, %{"transactionStatus" => status}}
        when status in ~w(annulled cancelled error) ->
          {:error, 43000, "Provider withdrawal error: #{status}"}

        {:ok, _} ->
          {:error, 43000, "withdrawal error"}

        response ->
          response
      end
    else
      error -> error
    end
  end

  def headers(
        %{
          params: %{
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
      {"X-Callback-URL", "#{notify_url}?our_transaction_id=#{transaction_id}"},
      {"X-Channel", "WS"}
    ]
  end
end
