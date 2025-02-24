# Teamscale Docker Deployment

This repository contains a reference configuration for deploying Teamscale using [*Docker Compose*](https://docs.docker.com/compose/).
This setup uses multiple Teamscale instances for staging and a reverse proxy for SSL termination.
Focus is put on switching the production instance with zero downtime.

Although this repository will give you a good starting point in setting up Teamscale, we strongly recommend reading the following documentation first:
* [How to install Teamscale with Docker and Docker Compose](https://docs.teamscale.com/howto/installing-with-docker/)
* [How to access Teamscale via a Reverse Proxy](https://docs.teamscale.com/howto/configuring-reverse-proxy/)

As a general note, it can be useful to start with a single instance setup first.
Addressing infrastructure and configuration problems is typically much easier in a single instance setup.
Please refer to the [respective section](#single-instance) in this guide.

## Installation

### Quick Setup

The whole deployment setup can be executed locally as follows, given `docker` and the Docker Compose plugin are installed:

1. [Download](https://github.com/cqse/teamscale-docker-deployment/archive/refs/heads/master.zip) the contents of this repository as a zip file and extract it.

2. Start the containers using `sudo ./start.sh`.
   This starts all containers in detached mode (`docker compose up -d`), reloads the nginx config (`./nginx-reload.sh`) and then follows the logs `docker compose logs --follow`.

   _Note:_ You can detach from the console at any time using `Ctrl+C`. Teamscale will keep running.

3. The Teamscale servers should be available via nginx at the following URLs
  - <https://teamscale.localhost> (the production server)
  - <https://teamscale-staging.localhost> (the staging server)

> **Remark:**
> The web services are SSL-encrypted using a self-signed certificate (located in folder `nginx`) for demo-purposes.
> It is **strongly** recommended to exchange this certificate with an appropriate certificate.

### Production Setup

#### Motivation

You may ask, why do I need to deploy two Teamscale instances for updates at all?
The reason is that Teamscale does not perform database upgrades upon updating from one feature version to another (e.g. v2025.1 to v2025.2).
Instead it performs a fresh analysis of source code and other artifacts to compensate for newly added or modified analyses.
Ideally this reanalysis is performed on a second instance to avoid unavailability of analysis results.
Patch releases, however, (e.g. v2025.2.1 to v2025.2.2) are drop-in and thus do _not_ require setting up a staging instance .
For more information, please consult the corresponding how-to on [updating Teamscale](https://docs.teamscale.com/howto/updating-teamscale/#feature-version-updates).

#### Architecture

Instead of hard-coding two instances, e.g. named `production` and `staging`, this guides follows a Teamscale release-based deployment setup.
It configures Teamscale services according to releases and has the advantage of documenting the version in paths and service names.
Thus, it may prevent you from "mixing up" instances and allows to switch the production server without downtime.
It comes, however, with increased effort of creating folders and copying files for each release.

This example describes two Teamscale instances:
* `v2025.1` is the production instance: in a real-world scenario, this instance would already be filled with analysis data
* `v2025.2` is the staging instance: in a real-world scenario, this instance would reanalyze the data of `v2025.1` and go live after the analysis has finished

The servers should be available using
  - <https://teamscale.localhost> (2025.1, the production server)
  - <https://teamscale-next.localhost> (2025.2, the staging server)

The data and configuration files for these instances are stored in folders named according to the deployed releases, e.g. `v2025.1` and `v2025.2`.
The services described in `docker-compose.yml` have the same naming scheme, e.g. `v2025.1` and `v2025.2`.

#### Getting started

_Note:_ `v2025.1` and `v2025.2` are only used as example, please replace these with your current needs.
Especially when migrating from a previous setup like setting up a first independent instance, copy all config files and the `storage` folder to e.g. `./v2025.1`.

- Ensure a valid [Teamscale license file](https://docs.teamscale.com/getting-started/installing-teamscale/#getting-your-evaluation-license) is placed in the config directories, e.g. `./v2025.1/config/teamscale.license`.
- Adjust [deploy-time configuration](https://docs.teamscale.com/reference/administration-ts-installation/#configuring-teamscale) such as the amount of workers (`engine.workers` in `teamscale.properties`) and memory (`TEAMSCALE_MEMORY` in `docker-compose.yml`).
- Change the `server_name`s in `./nginx/teamscale.conf` to the production domains and replace the self-signed certificates in `./nginx` by valid ones matching this domain.
- Make sure Docker and the services are automatically restarted when you restart your server.

_Note:_ For initial setup you may want to just run a [single instance](#single-instance).

## Updating Teamscale

Our documentation describes how to perform [Patch Version Updates](https://docs.teamscale.com/howto/updating-teamscale/patch-version/) and [Feature Version Updates](https://docs.teamscale.com/howto/updating-teamscale/feature-version/) using this setup.

## Further tweaks and considerations

### Single instance

The staging instance (in this example `v2025.2`) can be disabled in `docker-compose.yml` for the initial setup, e.g. by renaming the service from `v2025.2` to `x-v2025.2`.
Prefixing a service with `x-` [hides](https://docs.docker.com/compose/compose-file/#extension) it from _docker compose_.

If you want to use this setup to run exactly one instance this service can be removed completely.
In addition, you should delete the staging server in the `teamscale.conf` nginx configuration.

### Blue-Green deployment

A different deployment pattern is the so-called [blue-green deployment](https://en.wikipedia.org/wiki/Blue-green_deployment) strategy:
It contains two Teamscale instances, called "blue" and "green", that alternate between being the production server and the staging environment.

The setup is similar to the release-based naming but relieves you from creating/copying new services and configuration files for each release.
It contains two Docker Compose services named `blue` and `green` with data and configuration directories named accordingly:

```yml
  blue:
    image: 'cqse/teamscale:2025.1.latest'
    restart: unless-stopped
    working_dir: /var/teamscale
    volumes:
      - ./blue/:/var/teamscale/

  green:
    image: 'cqse/teamscale:2025.2.latest'
    restart: unless-stopped
    working_dir: /var/teamscale
    volumes:
      - ./green/:/var/teamscale/
```

The nginx configuration `teamscale.conf` will look as follows if `blue` is the production server:

```nginx
# The production server (live)
server {
    # Binds the production server to the "blue" docker container
    set $teamscale_prod  blue;

    server_name teamscale.localhost;

    listen      443  ssl http2;
    listen [::]:443  ssl http2;

    location / {
        proxy_pass http://$teamscale_prod:8080;
    }
}

# The staging server (next)
server {
    # Binds the staging server to the "green" docker container
    set $teamscale_next  green;

    server_name teamscale-next.localhost;

    listen      443  ssl http2;
    listen [::]:443  ssl http2;

    location / {
        proxy_pass http://$teamscale_next:8080;
    }
}
```

Preparation of a new deployment follows the same principle as described above in the release-based deployment.
Once you are satisfied with the changes in the staging instance just edit `./nginx/teamscale.conf` and switch the `blue` and `green` values of variables `$teamscale_prod` and `$teamscale_next`.
After saving the file simply execute `sudo ./nginx-reload.sh` (or `sudo ./start.sh` as it reloads the configuration and ensures all containers are started).
You should now be able to access the previous *staging* instance using <https://teamscale.localhost>.

The downside of this deployment strategy is that you need to be careful when making configuration changes or plan a new deployment not to "mix up" the colors blue and green.
This especially is the case when you need to purge the storage directory when setting up a fresh instance.

### Visually distinguish both instances

Set the `instance.name` property to the release number (e.g. `v2025.1`, or `blue`) respectively in each instance's `teamscale.properties` config file or in `docker-compose.yml`.
This allows you to easily differentiate the environment from the Web UI.

### Using YAML anchors

You can make use of *yaml-anchors* to extract common configuration that is shared between services:

```yaml
x-teamscale-common: &teamscale-common
  restart: unless-stopped
  working_dir: /var/teamscale
  environment:
    JAVA_OPTS: "-Dlog4j2.formatMsgNoLookups=true"

  v2025.1:
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
  v2025.1:
    # ...
    ports:
      - '8080:8080'
```

### Error logs

For Teamscale problems, the Teamscale logs will be stored in the folder `./logs` of the respective instance.
In addition, the console output is available via:

```sh
sudo docker compose logs <service-name>
```

For nginx problems, consult the nginx logs:

```sh
sudo docker compose logs nginx
```

### Error 502 bad gateway

Please restart nginx by running `sudo docker compose restart nginx`.
Nginx noticed that the Teamscale instance was down (e.g. due to a restart) and is now refusing to try to reconnect to it.
After restarting, it should be reachable again.

### Teamscale Dashboard cannot be embedded

The provided nginx configuration forbids a page from being displayed in a frame to prevent click-jacking. 
You can learn more about this [here](https://owasp.org/www-community/attacks/Clickjacking). 
If you still want to embed a Teamscale in Jira, Azure DevOps or another Teamscale instance, the line `add_header X-Frame-Options "DENY";` in `nginx/common.conf`has to be commented out. 
