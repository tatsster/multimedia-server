# Automated Jellyfin cluster
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
