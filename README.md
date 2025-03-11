# Automated Jellyfin cluster
Main instruction from [Techhut](https://github.com/TechHutTV/homelab/tree/main/media)

## The Stack
**Jellyfin** is an open source media server.

**qBittorrent** is a torrent client. Transmission and Deluge are also popular choices but I chose qBittorrent because you can easily configure it to only operate over the VPN connection.

**Glutun** is a VPN running in docker. This will allow you to connect the qBittorrent container to your VPN without having to put your entire system behind it
    - Consider put entire system behind Cloudflare Tunnel

**Prowlarr** is a tool that Sonarr and Radarr use to search indexers and trackers for torrents

**Sonarr** is a tool for automating and managing your TV library. It automates the process of searching for torrents, downloading them then "moving" them to your library. It also checks RSS feeds to automatically download new shows as soon as they're uploaded!

**Radarr** is a fork of Sonarr that does all the same stuff but for Movies

[**Jellyseerr**](https://github.com/Fallenbagel/jellyseerr) is an application for managing requests for your media library. It is a fork of Overseerr built to bring support for Jellyfin servers!

[**Bazarr**](https://wiki.bazarr.media/Getting-Started/Setup-Guide/) is a tool for Sonarr and Radarr to download subtitles for your content

## Optional
[**Homepage**](https://github.com/gethomepage/homepage) is a dashboard for keeping track all of these web services

[**jfa-go**](https://github.com/hrfee/jfa-go) is a user manager for Jellyfin that allows your users to sign up via an invite code and reset their passwords

[**Unmanic**](https://docs.unmanic.app) is a great tool for optimising media files. For example, you can use it to remove unneccessary subtitles/audio tracks and transcode media to your desired format.

[**nginx-proxy-manager**](https://nginxproxymanager.com/guide/#quick-setup)  is a simple reverse proxy service for making Jellyfin accessible outside of your local network

## Setup
### Linux/Mac
Change all User id, Group id services with:
```
- PUID=${PUID:-$(id -u)}
- PGID=${PGID:-$(id -g)}
```

### Public access
- Deploy cloudflare stack 
- Add/migrate domain to Cloudflare
- Create & get secret for Tunnel
- Assign that value in .env file
- Create subdomain url for each services

### How to run
Just simple
```
docker compose up -d
```

### Torrent Client
For 1st login, check container log for 1 time password login 
- Change password in Option > WebUI
- Auto remove torrents & files after 15min
    - Option > BitTorrent
    - Scroll to Seeding Limits
    - Check `When total seeding time reaches`
    - Choice `Remove torrent & its files`

### Prowlarr
Add Indexeres, the choice is simple:
- Public server
- en_US language
- Server Movies, TV and maybe Anime

Add applications, this is the same setup for both Radarr & Sonarr. Because all these in same network, we can use container name as endpoint:
- Prowlarr Server: http://prowlarr:9696
- Radarr Server: http://radarr:7878
- Sonarr Server: http://sonarr:8989

Also go to Radarr/Sonarr to grab API key and insert here, just in Settings > General

Edit Default profile:
- Minimum seeders: 5 (can be higher for better downloading exp)

Also, enable authentication, just make it simple with Forms login page

### Radarr / Sonarr
Add root folder, according to docker compose file, root folder for each:
- Radarr: /movies
- Sonarr: /tv

Add Torrent client:
- Can be different if with VPN
- If no VPN, then host is container name
- Use newly-created login in qBitTorrent for authen
- Check `Remove Completed`

Also remember to create authentication for Radarr/Sonarr with Forms

### Bazarr
Add subtitles providers, some free for recommendation:
- YIFY Subtitles
- Gestdown 
- Anime Tosho
- TVSubtitles
- OpenSubtitles.com (free but must have account)

Create Language profile
- Check as `Default language profiles for newly added shows`

Then just enable for Radarr/Sonarr

### Jellyfin / Jellyseerr
Follow Jellyfin Setup wizard to mount correct Movies & TV folder

For Jellyseer:
- Use Jellyfin account to authen 
- Grab Radarr/Sonarr API key to sync services
- And follow setup wizard, this is easy
