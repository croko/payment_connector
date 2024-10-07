defmodule AppWeb.Connector.Provider.Notify do
  use AppWeb, :connector

  @response_format "application/json"
  def init(
        %{
          params: %{
            "our_transaction_id" => transaction_id
          }
        } = notify
      ) do
    notify
    |> PaymentManager.assign(transaction_id)
    |> check_params()
    |> assign_response()
  end

  defp check_params(
         %{
           params: %{
             "transactionStatus" => "finished",
             "transactionReference" => transaction_reference
           }
         } = notify
       ),
       do: Map.merge(notify, %{provider_transaction_id: transaction_reference})

  defp check_params(
         %{
           params: %{
             "transactionStatus" => status
           }
         } = notify
       )
       when status in ~w(waiting processing conciliate pending reserved),
       do: Map.merge(notify, %{status: :pending})

  defp check_params(
         %{
           params: %{
             "transactionStatus" => status,
             "transactionReference" => transaction_reference
           }
         } = notify
       )
       when status in ~w(annulled cancelled error),
       do: Map.merge(notify, %{status: :error, provider_transaction_id: transaction_reference})

  defp check_params(notify), do: Map.merge(notify, %{status: :pending})

  defp assign_response(notify) do
    Map.merge(
      notify,
      %{
        response: %{
          content_type: @response_format,
          body: "",
          status_code: 204
        }
      }
    )
  end
end
