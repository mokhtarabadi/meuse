---
title: Configuration
weight: 20
disableToc: false
---

## Configure Meuse

Meuse is configured through a YAML file. Meuse uses [yummy](https://github.com/exoscale/yummy) to load the YAML file. This library supports custom tag parsers for a lot of use cases (like reading environment variables for example).

The list of available parsers can be found in the yummy [README](https://github.com/exoscale/yummy#additional-yaml-tags).

Secrets can be loaded using the special `!secret` or `!envvar` (to read a secret from an environment variable) tags.
These tags will indicate to Meuse that the value is a secret and extra security measures will be added to the variable.

Here is a commented example of a Meuse configuration:

```yaml
# The PostgreSQL database configuration
database:
  # The database user
  user: "meuse"
  # The database password
  password: !secret "meuse"
  # The database host
  host: "127.0.0.1"
  # The database port
  port: 5432
  # The database name
  name: "meuse"
  # optional: client certificates for tls connections
  cacert: "/home/mathieu/Documents/meuse/ssl/ca.cer"
  cert: "/home/mathieu/Documents/meuse/ssl/client.cer"
  key: "/home/mathieu/Documents/meuse/ssl/client.key"
  # optional: postgresql verify mode (default is "verify-full")
  ssl-mode: "verify-ca"
  # optional: connection pool size (default is 2)
  max-pool-size: 3
  # optional: the PostgreSQL schema to used
  schema: myschema
# The HTTP server configuration
http:
  # the IP address of the HTTP server
  address: 127.0.0.1
  # the port of the HTTP server
  port: 8855
  # optional: server certificates for tls
  cacert: "/home/mathieu/Documents/meuse/ssl/ca.cer"
  cert: "/home/mathieu/Documents/meuse/ssl/client.cer"
  key: "/home/mathieu/Documents/meuse/ssl/client.key"

# The logging configuration
# Meuse uses the unilog library for logging, you can check
# its doc for the configuration options:
# https://github.com/pyr/unilog/
logging:
  level: debug
  console:
    encoder: json
  overrides:
    org.eclipse.jetty: info
    com.zaxxer.hikari.pool.HikariPool: info
    org.apache.http: error
    io.netty.buffer.PoolThreadCache: error
    org.eclipse.jgit.internal.storage.file.FileSnapshot: info
    com.amazonaws.auth.AWS4Signer: warn
    com.amazonaws.retry.ClockSkewAdjuster: warn
    com.amazonaws.request: warn
    com.amazonaws.requestId: warn

# The configuration of your Git index
metadata:

  # Meuse supports multiple ways of managing the crate index
  # containing the crate metadata.
  # Only one should be configured.

  #### shell-out to the git command
  #### Meuse will shell-out to the git command to manage the index.

  type: "shell"
  # The local path of your Git index
  path: "/home/mathieu/prog/rust/testregistry"
  # The branch which will contain the metadata files
  target: "origin/master"
  # The URL of your Git index.
  url: "https://github.com/mcorbin/testregistry"

  #### JGit: Meuse will use a Java implementation of Git.
  #### The Git command is not needed

  type: "jgit"
  # The local path of your Git index
  path: "/home/mathieu/prog/rust/testregistry"
  # The branch which will contain the metadata files
  target: "origin/master"
  # Your Git username
  username: "my-git-username"
  # Your Git password. If you use Github, the password can also be
  # a Github Access Token
  password: !secret "my-git-password"

# The crate binary files configuration
crate:
  # Meuse supports multiple backends for crate files.
  # Only one should be configured.

  #### filesystem backend:

  store: filesystem
  # The local path of your crate files
  path: "/home/mathieu/prog/rust/crates"

  #### S3-compatible storage backend:

  store: s3

  # s3 credentials
  access-key: !secret your-access-key
  secret-key: !secret your-secret-key

  # s3 endpoint
  endpoint: s3-endpoint

  # The bucket which will be used to store the files
  bucket: bucket-name

# Activates the Meuse frontend
# The frontend is currently in alpha, and is accessible on the "/front" URL.
# It allows you to browse crates and categories.
frontend:

  # Enable or disable the frontend.
  enabled: true

  # Set to true to disable frontend authentication.
  # Default to false
  public: false

  # A random string with 32 characters.
  secret: !secret "ozeifjrizjrjghtkzifrnbjfkzoejfjz"
```

## Database migrations

When Meuse starts, it will automatically create its database and apply migration scripts. Meuse will track which migration script has been executed in a table named `database_migrations`. This table will also be created and managed by Meuse.

## Configure Cargo

### .cargo/config

In `.cargo/config`, you should configure the URL of your registry index. For example:

```
[registries.custom]
index = "https://github.com/mcorbin/testregistry"
```

### Index configuration

The index should also contain a `config.json` file which should contain the URL of the Meuse API as described in the Cargo [registries documentation](https://doc.rust-lang.org/nightly/cargo/reference/registries.html)), for example:

```
{
    "dl": "http://localhost:8855/api/v1/crates",
    "api": "http://localhost:8855",
    "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
```
If missing, the `allowed-registries` value will be the value specified in the `metadata.url` key in Meuse configuration.

### Token configuration

You should also configure a token to be able to interact with Meuse from Cargo in the `.cargo/credentials` file:

```
[registries.custom]
token = "<your token>"
```

You can find how to create a token in the `API` documentation.

## Root user configuration

In order to use Meuse, you need to create a first `admin` user. The only way to create this user currently is by inserting it directly into the database ¯\_(ツ)_/¯

Passwords are encrypted using bcrypt. You can generate a password by running the Meuse jar with the `password` subcommand, for example:

```
java -jar meuse.jar password do_not_use_this_password
12:15:23.793 [main] INFO meuse.core - your password is: $2a$11$PN29HCYWPjcHbC4cyLSrReMb2UKNGAAWMlaxEeMNNCVGz3pk/rNee
```

Then, insert a new `admin` user using this password in the database:

```
INSERT INTO users(id, name, password, description, active, role_id)
VALUES ('f3e6888e-97f9-11e9-ae4e-ef296f05cd17', 'root_user', '$2a$11$PN29HCYWPjcHbC4cyLSrReMb2UKNGAAWMlaxEeMNNCVGz3pk/rNee', 'my root user', true, '867428a0-69ba-11e9-a674-9f6c32022150');
```
