defmodule ChatClient.Spinner do
  @spinner_chars ["|", "/", "-", "\\"]

  def with_spinner(message, callback) do
    pid = spawn(fn -> spin_loop(message, 0) end)

    result = callback.()

    Process.exit(pid, :kill)
    IO.write("\r#{message}\n")

    result
  end

  defp spin_loop(message, index) do
    char = Enum.at(@spinner_chars, rem(index, 4))
    IO.write("\r#{message} #{char}")
    :timer.sleep(100)
    spin_loop(message, index + 1)
  end
end
