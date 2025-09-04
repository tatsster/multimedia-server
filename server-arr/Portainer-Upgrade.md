## Upgrade Portainer
Because Portainer is installed with default volume name so run these commands:
```
docker stop portainer
docker rm portainer
docker pull portainer/portainer-ce:lts
docker run -d -p 8000:8000 -p 9443:9443 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:lts
```
