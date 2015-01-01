GitlabCI Docker Container
================

Docker container running Gitlab CI

## Testing the project's Dockerfile:

I'm using fig to raise a gitlab-ci container.

There's a few things to do:

- Run `fig run --rm app rake setup` to generate the gitlab-ci's database.
- Run `fig up -d` to start the postgres, redis & app containers.
- Run `fig logs`  to check the container logs.
- Open http://localhost:5000 to see the container in action.
