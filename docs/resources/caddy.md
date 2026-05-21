# Caddy Resources

Caddy is a modern web server and reverse proxy focused on simplicity, automatic HTTPS, and easy configuration. It fills a role similar to Nginx or Apache, but is generally much simpler to configure and maintain for small-to-medium deployments.

OpenGameBuilder uses Caddy as the public-facing edge server for handling HTTPS, routing requests, serving the frontend files, and forwarding API traffic to the backend services. In practice, Caddy is responsible for things like:

- Automatically managing SSL/TLS certificates
- Redirecting HTTP to HTTPS
- Serving the Blazor frontend
- Proxying `/api/*` requests to the backend API container
- Applying compression such as gzip and zstd
- Acting as the single public entry point for the deployment servers

Most OpenGameBuilder contributors will not have to work with Caddy directly. It is only used on the deployment servers. Contributors working purely on the frontend, backend, engine, or editor code generally do not need to understand or modify the Caddy configuration.

## General
- [Website](https://caddyserver.com/)
- [Docs](https://caddyserver.com/docs/)
- [Getting started](https://caddyserver.com/docs/getting-started)
- [Command line reference](https://caddyserver.com/docs/command-line)
- [Automatic HTTPS](https://caddyserver.com/docs/automatic-https)
- [Conventions](https://caddyserver.com/docs/conventions)
- [Keep Caddy running](https://caddyserver.com/docs/running)
- [Troubleshooting strategies](https://caddyserver.com/docs/troubleshooting)

## Caddyfile
- [Overview](https://caddyserver.com/docs/caddyfile)
- [Quick-start](https://caddyserver.com/docs/quick-starts/caddyfile)
- [Tutorial](https://caddyserver.com/docs/caddyfile-tutorial)
- [Concepts](https://caddyserver.com/docs/caddyfile/concepts)
- [Directives](https://caddyserver.com/docs/caddyfile/directives)
- [Request matchers](https://caddyserver.com/docs/caddyfile/matchers)
- [Global options](https://caddyserver.com/docs/caddyfile/options)
- [Common patterns](https://caddyserver.com/docs/caddyfile/patterns)
