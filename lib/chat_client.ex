defmodule ChatClient.Client do
  @moduledoc """
  Secure chat client with SSL/TLS support, authentication, and auto-reconnect.

  ## Overview
  This module implements an interactive chat client that connects to a server
  over SSL/TLS, authenticates with a password, and allows bidirectional
  messaging. It also provides automatic reconnection in case of errors or
  connection drops.

  ## Features
    * Connects to a server over SSL/TLS with optional certificate fingerprint check.
    * Prompts user for host, port, and authentication password.
    * Verifies server certificate if `CHAT_SERVER_FINGERPRINT` environment
      variable is set; otherwise connects insecurely.
    * Supports authentication handshake with the server.
    * Continuously listens for incoming messages (`listen/1`).
    * Provides an interactive loop for sending messages (`send_loop/1`).
    * Handles timeouts, authentication errors, and closed connections.
    * Automatically retries connection with a delay.

  ## Environment Variables
    * `CHAT_SERVER_FINGERPRINT` – expected server certificate fingerprint.
      If not set, the client will warn the user and skip certificate validation.

  ## Typical Flow
    1. User starts the client with `ChatClient.Client.start/0`.
    2. Host and port are requested from the user.
    3. The client attempts an SSL connection.
    4. Authentication is performed with a password.
    5. If successful, two loops are spawned:
       * One for listening to incoming messages.
       * One for sending messages from the console.
    6. In case of errors, the client retries connection after a delay.

  ## Example
      iex -S mix
      ChatClient.Client.start()

  """
  alias ChatClient.Spinner
  alias ChatClient.SSL.CertificateVerifier

  def start do
    host =
      IO.gets("Type host: ")
      |> String.trim()
      |> String.to_charlist()

    port =
      IO.gets("Type port: ")
      |> String.trim()
      |> String.to_integer()

    case System.get_env("CHAT_SERVER_FINGERPRINT") do
      nil ->
        IO.puts("""
        WARNING: CHAT_SERVER_FINGERPRINT is not set.
        The client will connect INSECURELY and accept any certificate.
        """)

      fp ->
        IO.puts("""
        Secure mode enabled.
        Expected server fingerprint: #{fp}
        """)
    end

    connect_loop(host, port)
  end

  defp connect_loop(host, port) do
    case :ssl.connect(host, port, CertificateVerifier.get_ssl_options()) do
      {:ok, socket} ->
        IO.puts("Connected to #{host}:#{port}")

        password = IO.gets("Enter server password: ") |> String.trim()

        auth_message = %{"type" => "auth", "password" => password}
        encoded_auth = ChatClient.Protocol.encode_message(auth_message)
        :ssl.send(socket, encoded_auth)

        case :ssl.recv(socket, 0, 5000) do
          {:ok, binary_data} ->
            {response, _rest} = ChatClient.Protocol.decode_message(binary_data)

            case response do
              %{"type" => "auth_result", "success" => true} ->
                IO.puts("Authentication successful!")
                spawn(fn -> listen(socket) end)
                send_loop(socket)

              %{"type" => "auth_result", "success" => false, "error" => error} ->
                IO.puts("Authentication failed: #{error}")
                :ssl.close(socket)

                Spinner.with_spinner("Reconnection in one second please wait", fn ->
                  :timer.sleep(1000)
                end)

                connect_loop(host, port)

              _ ->
                IO.puts("Unexpected response from server")
                :ssl.close(socket)
                connect_loop(host, port)
            end

          {:error, :timeout} ->
            IO.puts("Authentication timeout")
            :ssl.close(socket)

            Spinner.with_spinner("Reconnection in 5 seconds please wait", fn ->
              :timer.sleep(5000)
            end)

            connect_loop(host, port)

          {:error, reason} ->
            IO.puts("Authentication error: #{inspect(reason)}")
            :ssl.close(socket)

            Spinner.with_spinner("Reconnection in 5 seconds please wait", fn ->
              :timer.sleep(5000)
            end)

            connect_loop(host, port)
        end

      {:error, {:tls_alert, {:bad_certificate, _}}} ->
        IO.puts("Certificate verification failed")

        Spinner.with_spinner("Reconnection in 5 seconds please wait", fn ->
          :timer.sleep(5000)
        end)

        connect_loop(host, port)

      {:error, reason} ->
        IO.puts("Connection failed #{inspect(reason)}")

        Spinner.with_spinner("Reconnection in 5 seconds please wait", fn ->
          :timer.sleep(5000)
        end)

        connect_loop(host, port)
    end
  end

  defp listen(socket) do
    case :ssl.recv(socket, 0) do
      {:ok, binary_data} ->
        {message, _rest} = ChatClient.Protocol.decode_message(binary_data)

        case message do
          %{"type" => "chat", "text" => text, "sender_ip" => sender_ip} ->
            IO.puts("msg from #{sender_ip}: #{text}")

          %{"text" => text, "sender_ip" => sender_ip} ->
            IO.puts("msg from #{sender_ip}: #{text}")

          _ ->
            :ok
        end

        listen(socket)

      {:error, :closed} ->
        :timer.sleep(2000)
        IO.puts("Connection closed")

      {:error, reason} ->
        IO.puts("Listen error: #{inspect(reason)}")
        :timer.sleep(2000)
    end
  end

  defp send_loop(socket) do
    case IO.gets("--> ") do
      msg when is_binary(msg) ->
        message = String.trim(msg)

        if message != "" do
          message_data = %{
            "type" => "chat",
            "text" => message
          }

          encoded_message = ChatClient.Protocol.encode_message(message_data)

          case :ssl.send(socket, encoded_message) do
            :ok ->
              send_loop(socket)

            {:error, reason} ->
              IO.puts("Failed to send message: #{inspect(reason)}")
              :ssl.close(socket)
          end
        else
          send_loop(socket)
        end

      # TODO Fix it
      nil ->
        IO.puts("Disconnecting...")
        :ssl.close(socket)
        :ok
    end
  end
end
