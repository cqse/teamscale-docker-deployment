# Teamscale Docker Deployment

This repository contains a reference configuration for deploying Teamscale using *docker-compose*.

It follows the pattern of a [blue-green deployment](https://en.wikipedia.org/wiki/Blue-green_deployment) strategy:
It contains two Teamscale instances, called "blue" and "green", that alternate between being the production server and the staging environment.
In addition an *nginx* reverse proxy in front of these terminates SSL and allows zero-downtime switches between the instances.

Although this repository will give you a good starting point in setting up Teamscale, we strongly recommend reading the following documentation:
* [How to install Teamscale with Docker and docker-compose](https://docs.teamscale.com/howto/installing-with-docker/)
* [How to access Teamscale via a Reverse Proxy](https://docs.teamscale.com/howto/configuring-reverse-proxy/)

In particular, before starting to configure a deployment with multiple Teamscale instances, set up a _single_ first using [the Docker installation guide](https://docs.teamscale.com/howto/installing-with-docker/).
It is much easier to address infrastructure and configuration problems when dealing with a simple one-instance setup.

## Installation

### Quick Setup

The whole deployment setup can be executed locally as follows, given `docker` and `docker-compose` are installed:

1. [Download](https://github.com/cqse/teamscale-docker-deployment/archive/refs/heads/master.zip) the contents of this repository as a zip file and extract it.
2. Start the containers using `sudo ./start.sh`.
   This starts all containers in detached mode (`docker-compose up -d`), reloads the nginx config (`./nginx-reload.sh`) and then follows the logs `docker-compose logs --follow`.
3. The servers should be available using
  - <https://teamscale.localhost> (blue, the productive server)
  - <https://teamscale-staging.localhost> (green, the staging server)

### Production Setup

If you are migrating from a previous setup, e.g. from setting up a first independent instance, copy all config files and the `storage` folder to `./blue`.
  The *blue* instance will be the new production instance.

- Ensure a valid [Teamscale license file](https://docs.teamscale.com/getting-started/installing-teamscale/#getting-your-evaluation-license) is placed in the config directories, e.g. `./blue/config/teamscale.license`.
- Adjust [deploy-time configuration](https://docs.teamscale.com/reference/administration-ts-installation/#configuring-teamscale) such as the amount of workers (`engine.workers` in `teamscale.properties`) and memory (`TEAMSCALE_MEMORY` in `docker-compose.yaml`).
- Change the `server_name`s in `./nginx/teamscale.conf` to the production domains and replace the self-signed certificates in `./nginx` by valid ones matching this domain.
- Enable [automatic backups](https://docs.teamscale.com/howto/handling-backups/#automated-backups) (Starting with Teamscale 7.8 backups are enabled by default).
- Make sure Docker and the services are automatically restarted when you restart your server.

### Switching instances

Besides providing a smooth starting point to deploy Teamscale using Docker, the setup described allows to switch instances without downtime.

You can prepare lengthy updates and reanalyses in the *staging* instance that is available via `https://teamscale-staging.localhost`.
Once you are satisfied with the changes in the staging instance edit `./nginx/teamscale.conf` and switch the `blue` and `green` values of variables `$teamscale_prod` and `$teamscale_next`.
After saving the file simply execute `sudo ./nginx-reload.sh` (or `sudo ./start.sh` as it reloads the configuration and ensures all containers are started).
You should now be able to access the previous *staging* instance using `https://teamscale.localhost`.

## Further tweaks and considerations

### Visually distinguish both instances

Set the `instance.name` property to `blue` or `green` respectively in each instance's `teamscale.properties` config file.
This allows you to easily differentiate the blue and green environment from the Web UI.

### Using YAML anchors

You can make use of *yaml-anchors* to extract common configuration that is shared between services:

```
x-teamscale-common: &teamscale-common
  restart: unless-stopped
  working_dir: /var/teamscale
  environment:
    JAVA_OPTS: "-Dlog4j2.formatMsgNoLookups=true"

  blue:
    <<: *teamscale-common
```

### Serving Teamscale using subpaths instead of subdomains

You can also serve Teamscale using subpaths instead of subdomains.
Please follow the guide outlined in the [documentation](https://docs.teamscale.com/howto/configuring-reverse-proxy/#basic-configuration).

__Important:__ Currently there is no way to switch instances without downtime as you need to change the `server.urlprefix` configuration property in `teamscale.properties` for both instances.
We are working on a way to resolve this issue for the next releases.

### Full control over nginx configuration

In order to reduce complexity and provide meaningful defaults, the default nginx configuration shipped within the container is used.
The directory `./nginx` is mounted as `/etc/nginx/conf.d/` in the container and all config files matching `*.conf` are included within the `http` configuration block.

If you want to have full control over the nginx configuration, please follow the [official guide](https://github.com/docker-library/docs/tree/master/nginx#complex-configuration).
In particular change the mount from `/etc/nginx/conf.d/` to `/etc/nginx/` and provide a `nginx.conf` in the `nginx` directory.

## Troubleshooting

### Directly access the container from localhost

If you need to access the HTTP interface of the container directly, e.g. for debugging reasons, you need to explicitly map the port:

```yaml
  blue:
    # ...
    ports:
      - '8080:8080'
```

### Error logs

For Teamscale problems, the Teamscale logs will be stored in the folder `./logs` of the respective instance.
In addition, the console output is available via:

```sh
sudo docker-compose logs <blue|green>
```

For nginx problems, consult the nginx logs:

```sh
sudo docker-compose logs nginx
```

### Error 502 bad gateway

Please restart nginx by running `sudo docker-compose restart nginx`.
Nginx noticed that the Teamscale instance was down (e.g. due to a restart) and is now refusing to try to reconnect to it.
After restarting, it should be reachable again.

### Bypass the reverse proxy

In the default setup the Teamscale server can only be accessed using the reverse proxy.
If you need to directly access the service, a port mapping to port `8080` has to be established:

```yaml
blue:
  # ...
  ports:
      - '8080:8080'
```
