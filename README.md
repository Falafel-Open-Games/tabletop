# Multiplayer Tabletop Game

This project contains both server and client for an open-source tabletop games framework.

## Status

This is under construction and in a very early stage, things are moving a lot, better documentation will come as the project matures.

## License

MIT

## Usage

If you are a developer that wants to contribute to the project and have Godot installed, skip to the "Build the binaries" section.

### Get the binaries

#### Pull the server from Dockerhub and run it

```
podman pull docker.io/fczuardi/tabletop-server:latest
podman run -it --rm --init -p 8910:8910 -t tabletop-server:latest
```

#### Download client binaries from Github and run them

On the page https://github.com/Falafel-Open-Games/tabletop/releases/tag/latest you can find the Linux and HTML clients for the multiplayer game. This page will always have the latest binaries generated from the main branch.

Once downloaded you can decompress the client files to a folder with:

```
tar -xzf tabletop-linux-client.tar.gz
```

And then instantiate multiple clients on linux by running the command below on different terminal windows:

```
./tabletop.x86_64
```

### Build the binaries

First step is to build the binaries, both the headless server and the client, you will need Godot `4.5.1-stable` for that. You can do that by opening the Godot project and Export>Export All, or via command line as displayed below:


```
alias godot=~/dev/Godot_v4.5.1-stable_linux.x86_64 # replace with your godot path
godot --headless --export-release "Linux Headless Server" build/server/tabletop_server.x86_64
godot --headless --export-release "Linux Client" build/linux-client/tabletop.x86_64
```

### Launch the server in one terminal

It's important to pass the CLI argument `--server`.

```
./build/server/tabletop_server.x86_64 --server
```

The server will communicate via websockets by default on `ws://127.0.0.1:8910`

#### Alternativelly, build the docker container and launch it instead

```
podman build -t tabletop-server:latest -f Containerfile .
podman run -it --rm --init -p 8910:8910 -t tabletop-server:latest
```

### Launch the clients on different terminals

To open a new client window on the same machine as the server, run:

```
./build/linux-client/tabletop.x86_64
```

### How to test over the internet using Cloudflare (cloudflared cli tool) tunnels

If you have a domain name managed by Cloudflare it is possible to use the `cloudflared` command line tool to expose your localhost server to the Internet, below are the steps:

In this example I am using `ws-example` as the tunnel name, `tabletop-server.example.com` as the service hostname and `8910` as the local port, adjust to your values.

```
brew install cloudflared

cloudflared tunnel login

cloudflared tunnel create ws-example
# ... Created tunnel tabletop-server with id XXX-YYY-ZZZ

cloudflared tunnel list

nvim ~/.cloudflared/config.yaml
# create this config following the provided example below

# REPLACE WITH YOUR VALUES
cloudflared tunnel route dns XXX-YYY-ZZZ tabletop-server.example.com 

cloudflared tunnel run ws-example
```

Example of config.yaml file:

```
tunnel: XXX-YYY-ZZZ
credentials-file: ~/.cloudflared/XXX-YYY-ZZZ.json

ingress:
  - hostname: tabletop-server.example.com
    service: http://localhost:8910
  - service: http_status:404
```

Then on your clients use `wss://tabletop-server.example.com` as the `--url` argument.
