# Teamscale Docker Setup with Staging

This repository contains three docker-compose scripts that set up a [blue-green deployment](https://en.wikipedia.org/wiki/Blue-green_deployment) strategy between two Teamscale instances. I.e. there are always two instances of Teamscale running, called "blue" and "green", that alternate between being the production server and the staging environment.

An nginx reverse proxy in front of them terminates SSL and allows zero-downtime switches betweeen the instances as described in [our blog post on our recommended productive Teamscale setup](https://www.cqse.eu/en/news/blog/teamscale-production-setup/).

## Download

[Download the contents of this repository](https://github.com/cqse/teamscale-docker-blue-green-deployment/archive/refs/heads/master.zip) as a zip file and extract it.

## Playing Around

The entire setup is runnable as is on `localhost`. Simply run

```sh
sudo ./start_all.sh
```

and then access any of the following URLs:

- <https://localhost> (productive server)
- <https://localhost/staging> (staging server)
- <https://teamscale.localhost> (productive server)
- <https://teamscale-staging.localhost> (staging server)

## Installation

1. Before you start with this staging setup, first set up a _single_ Teamscale instance using [our Docker installation guide](https://docs.teamscale.com/howto/installing-with-docker/). Verify that it works as intended. It is much easier to address any infrastructure and configuration problems that might come up when dealing with a simple one-instance setup.
2. Once that works, address all TODOs in the files in this repository
3. Copy all files from the working directory of the instance from step 1 to `./blue/workingdir`, especially all config files and the `storage` folder.
4. Merge the docker-compose.yaml files of the instance from step 1 with `./blue/docker-compose.yaml`.
5. Start everything by running
   ```sh
   sudo ./start_all.sh
   ```
6. Open the public URL of your production and staging instance and test whether they are reachable as expected.
7. If all is well, make sure your setup is automatically restarted when you restart your server.
8. Optional: Set the `instance.name` property to `Blue` or `Green` respectively in each instance's `teamscale.properties` config file. This allows you to easily differentiate the blue and green environment from the Web UI.

# Troubleshooting

## Error 502 bad gateway

Please restart nginx. It noticed that your Teamscale instance was down (e.g. due to a restart) and is now refusing to try to reconnect to it. After restarting, it should be reachable again.

