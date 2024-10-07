# payment_connector

This is a sample code of a payment connector written in Elixir. It consists of three key modules:

1. **Deposit**: This module is responsible for handling deposit requests. It processes transactions where users initiate the transfer of funds into their accounts. It ensures the transaction is initiated properly and tracks the status of the deposit.

2. **Withdrawal**: This module manages withdrawal requests. It processes transactions where users request to transfer funds out of their accounts. Similar to the deposit module, it handles the request flow and monitors the status of the withdrawal transaction.

3. **Notify**: This module finalizes transactions by processing notifications from external systems (such as banks or third-party payment services). It updates the status of a transaction based on the notification received. For example, a successful notification will mark a transaction as complete, while an error notification may set the status to failed or canceled.

### Transaction Lifecycle:
- When a deposit or withdrawal request is successfully initiated, the transaction is assigned a **pending** status. This indicates that the transaction is in progress and awaiting further updates.
- If an error occurs during the initiation of the transaction (for example, if the request is invalid or there is an issue with external services), the transaction will be marked with an **error** status.
- After the **Notify** module receives a notification regarding the transaction, it checks the contents of the notification and updates the status accordingly. If the notification indicates a successful transaction, the status will be updated to reflect completion. If there is an error in the notification, the transaction status will be updated to reflect failure or cancellation.

This explanation provides a clearer overview of the structure and flow of the payment connector in Elixir.