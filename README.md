
# pg-iam

A generic database backend for use in IAM APIs.

# Features

- create persons, users, and groups with optional expiry dates, and activation states
- add users and/or groups to groups, specify temporal constraints on memberships
- add persons without users to groups, for external account access control management
- allow groups to moderate memberships of other groups
- affiliate groups with one another
- create capabilities, criteria for obtaining them, use them in access tokens
- specify the scope of the capabilities
- create organisational units and hierarchies with institutions, and projects
- affiliate groups with institutions and projects
- data integrity and consistency, immutable columns wherever possible
- audit log on all inserts, updates, and deletes
- SQL functions for simplified application development

# Usage

Read the guide on how to install and run tests.

```bash
git clone git@github.com:unioslo/pg-iam.git
cd pg-iam
./install.sh --guide
```

# Container

In this repository there is an extension of the
[docker.io/postgres](https://hub.docker.com/_/postgres) image provided for
running pg-iam in a container.

## Building the container

You can build the container with Docker like this:

```console
docker build --tag pg-iam https://github.com/unioslo/pg-iam.git
```

Or by cloning the repository and using the repository root as build context:

```console
git clone https://github.com/unioslo/pg-iam.git
cd pg-iam
docker build --tag pg-iam .
```

## Running the container

After it [has been built](#building-the-container), you can run the container
like this:

```console
docker run --env POSTGRES_PASSWORD=mypassword -p 127.0.0.1:5432:5432 pg-iam
```

The `POSTGRES_PASSWORD` environment variable can be set to anything, but some
value is required to start the container image. This will be used as the
superuser's password.

For persisting data, you will need to mount a volume for the container's
PostgreSQL data directory:

```console
docker run \
    --env POSTGRES_PASSWORD=mypassword \
    -v /custom/mount:/var/lib/postgresql/data \
    -p 127.0.0.1:5432:5432 \
    pg-iam
```

**Note:** pg-iam will only be installed by this container when started with an
**empty PostgreSQL data directory** during the first-time run.

To review all available options, please refer to the [`docker.io/postgres`
images' documentation](https://github.com/docker-library/docs/blob/master/postgres/README.md).

# Learn more

Read the [docs](https://github.com/unioslo/pg-iam/tree/master/docs).

# LICENSE

BSD.
