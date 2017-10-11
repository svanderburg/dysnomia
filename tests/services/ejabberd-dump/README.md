How to create/reproduce the ejabberd dump file
==============================================
- Create a NixOS configuration with ejabberd enabled. In other words, it should contain:

```
services.ejabberd.enable = true;
```

- Deploy the NixOS configuration:

```
$ nixos-rebuild switch
```

- Figure out where the config file is by checking the output of the following command:

```
$ ejabberdctl
```

- Create an admin account:

```
$ su ejabberd -s /bin/sh -c "ejabberdctl --spool /var/lib/ejabberd register admin localhost admin"
```

- Make a copy of the config file:

```
$ cp /nix/store/...-ejabberd-15.11/etc/ejabberd/ejabberd.yml /etc/nixos
```

- Grant the admin user, administration privileges:
  * Open `/etc/nixos/ejabberd.yml` in a text editor
  * Search for the `acl:` section
  * Add the following lines:

```
  admin:
    user:
      - "admin": "localhost"
```

- Change the NixOS configuration to use the modified config:

```
services.ejabberd.configFile = ./ejabberd.yml;
```

- Deploy the modified ejabberd and remove its old state:

```
$ systemctl stop ejabberd
$ rm -R /var/lib/ejabberd
$ nixos-rebuild switch
```

- Verify whether you can access the admin web GUI:
  * Open in your browser: `http://localhost:5280/admin`
  * Username: `admin@localhost`
  * Password: `admin`
  * You should see the option 'Access Control Lists' and 'Access Rules' in the left menu bar

- Dump the ejabberd database:

```
$ su ejabberd -s /bin/sh -c "ejabberdctl dump /tmp/ejabberdcfg.dump"
```

- Copy the database and fix permissions:

```
$ mv /tmp/ejabberdcfg.dump .
$ chown sander:users ejabberdcfg.dump
```

- This is it!
