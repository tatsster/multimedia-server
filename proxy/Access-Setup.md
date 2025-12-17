# Access Services from Public Network
## Access with Cloudflared Tunnel
To prevent 1 LXC reaches max CPU usage would cause service degradation, I recommend to deploy Cloudflared Tunnel in separate LXC. And simply go with this
```
https://community-scripts.github.io/ProxmoxVE/scripts?id=cloudflared
```

Follow instruction to create Cloudflared LXC. Then head to Cloudflare dashboard to create Tunnel: Zero Trust -> Network -> Tunnels

After create tunnel with instruction, now add public hostname for each service:
- Enter subdomain for service
- Choose domain we own
- Enter URL, this will be IPv4 with port of service in LAN
- Type:
    - HTTP: Simple, no additional work
    - HTTPS: Service enables this by default, then Additonal setting -> TLS -> enable `No TLS verify`

### Add Login with allowed Google account
Go to Zero Trust -> Access -> Applications, choose to add an application
- Select Self-hosted
- Enter any application name, usually your service
- Add public hostname
- Add policy then finish

To create policy, can follow many guide on internet because this will require Google/Github,... token. I follow this guide: https://www.youtube.com/watch?v=Ynr8VubJqvY&t

## Dynamic DNS resolver
First create Cloudflare (my public DNS records) token to periodically update my IP.
Just go Profile -> API Token -> Create Token -> Get Custom Token:
- Your token name, anything
- Add permissions:
    - Zone.Zone Read
    - Zone.DNS Edit
- In Zone resources: Select Include All zones
- Good to finish
- Keep new API Token to use with `cloudflare-stack.yml` docker compose

## Caddy (for services dont use Tunnel)
Similar reason with Tunnel, we go with new LXC and remember to install `xcaddy`. My recommendation is having 1 LXC for both Caddy + Tunnel
```
https://community-scripts.github.io/ProxmoxVE/scripts?id=caddy
```

Because we use Cloudflare as our DNS so should install this module for SSL challenges
```
xcaddy build --with github.com/caddy-dns/cloudflare
sudo mv ./caddy $(which caddy)
sudo chmod +x $(which caddy)
caddy list-modules
```

Use [Caddyfile](./config/Caddyfile) as example to reverse proxy to a service with TLS, just copy its content for simplicity
```
touch Caddyfile
nano Caddyfile
```

Then move it to Caddy config folder and run daemon, remember to add API Token in [DDNS](#dynamic-dns-resolver) in environment variable
```
caddy fmt --overwrite
cp Caddyfile /etc/caddy/Caddyfile
caddy start
```

### DDNS module
This is another solution replace for cloudflare-ddns stack
```
xcaddy build --with github.com/mholt/caddy-dynamicdns --with github.com/caddy-dns/cloudflare
```
Remember to overwrite main Caddy to apply new module

This is simple for owned domain:
```
{
	dynamic_dns {
		provider cloudflare {env.CF_API_TOKEN}
		domains {
			liftlab.dev
		}
		dynamic_domains  
	}
}
```
Important line is `dynamic_domains`, this makes Caddy manage all server blocks below which match to domains listed above. In this case, `*.liftlab.dev`

### Cloudflare API KEY
Need a API key to challenge TLS cert. In Caddy LXC, I save it in `/etc/profile` to load as env vars when booting
