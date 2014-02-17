How to create/reproduce the ejabberd dump file
==============================================
- Create a NixOS configuration with ejabberd enabled:

    services.ejabberd.enable = true;

- Deploy the NixOS configuration:

    $ nixos-rebuild switch

- Create an admin account:

    $ ejabberdctl='ejabberctl --spool /var/lib/ejabberd'
    $ $ejabberdctl register admin local admin

- Grant the admin user, administration privileges:
  * Open `/var/ejabberd/ejabberd.cfg`
  * Search for `ACCESS CONTROL_LISTS` section
  * Add the following line near the `admin` user section:

    {acl, admin, {user, "admin", "localhost"}}.

- Restart ejabberd:
    $ stop ejabberd
    $ start ejabberd

- Verify whether you can access the admin web GUI:
  * Open in your browser: `http://localhost:5280/admin`
  * Username: `admin@localhost`
  * Password: `admin`
  * You should see the option 'Access Control Lists' and 'Access Rules' in the left menu bar

- Dump the ejabberd database:

    $ $ejabberdctl dump $(pwd)/ejabberdcfg.dump

- This is it
