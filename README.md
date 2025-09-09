# ChatClient

A secure chat client implemented in Elixir with SSL/TLS support, authentication, and automatic reconnection. For elixir-shc in this repo

## Overview

`ChatClient` is an interactive command-line client that connects to a server over SSL/TLS, verifies certificates using fingerprint pinning (if configured), and performs password-based authentication. Once connected, the client enables two-way messaging: listening for incoming messages and sending user input interactively.

It is designed for experimenting with secure communication over SSL in Elixir and includes robust error handling and reconnection logic.

## Features

- SSL/TLS connection to a chat server  
- Certificate fingerprint verification via environment variable  
- Interactive prompts for host, port, and password  
- Password-based authentication handshake  
- Continuous message listening loop  
- Interactive message sending loop  
- Automatic reconnection on errors, timeouts, or closed connections  

## Environment Variables

- `CHAT_SERVER_FINGERPRINT`  
  If set, the client verifies the server's certificate fingerprint against this value.  
  If not set, the client will connect insecurely and accept any certificate.  

## Usage

Run the client from the Elixir shell:

```bash
iex -S mix
```
