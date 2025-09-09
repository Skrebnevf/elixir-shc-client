defmodule ChatClient.SSL.CertificateVerifier do
  require Logger

  def get_ssl_options do
    [
      :binary,
      packet: :raw,
      active: false,
      verify: :verify_peer,
      verify_fun: {&verify_certificate/3, System.get_env("CHAT_SERVER_FINGERPRINT")},
      cacerts: []
    ]
  end

  def verify_certificate({:OTPCertificate, der, _}, :valid_peer, expected_fp)
      when is_binary(expected_fp) do
    actual_fp = :crypto.hash(:sha256, der) |> Base.encode16(case: :lower)

    if actual_fp == expected_fp do
      IO.puts("Certificate verified successfully!")
      {:valid, :verified}
    else
      IO.puts("Certificate fingerprint mismatch!")
      IO.puts("Expected: #{expected_fp}")
      IO.puts("Actual:   #{actual_fp}")
      {:fail, :fingerprint_mismatch}
    end
  end

  def verify_certificate({:OTPCertificate, der, _}, :valid_peer, nil) do
    actual_fp = :crypto.hash(:sha256, der) |> Base.encode16(case: :lower)
    show_warning(actual_fp)

    {:valid, :unverified}
  end

  def verify_certificate(_cert, _event, state) do
    {:valid, state}
  end

  defp show_warning(actual_fp) do
    formatted_fp = format_fingerprint(actual_fp)

    IO.puts("""

    WARNING: Connecting without certificate verification!
    Server fingerprint: #{formatted_fp}

    For secure connections, set:
    export CHAT_SERVER_FINGERPRINT=#{actual_fp}
    """)
  end

  defp format_fingerprint(fp) do
    fp
    |> String.graphemes()
    |> Enum.chunk_every(2)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(":")
  end
end
