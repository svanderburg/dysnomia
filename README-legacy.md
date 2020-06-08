Deprecated Dysnomia modules
===========================
Two modules have been deprecated in the most recent version of Dysnomia,
because they combine several kinds of functionality into one module, that
ideally should be separated, and they do not follow recommended practices for
managing foreground processes in the background.

Because the alternatives to these modules break compatibility and the legacy
modules used to have an important role, they can still be used by passing the
`--enable-legacy` parameter to the `configure` script.

Although the legacy modules are still available, they will be removed in the
next release and you should migrate to better alternatives as quickly as
possible.

Modules
-------
The following modules are deprecated:

* `process`. Wraps a process inside a
  [systemd](http://www.freedesktop.org/wiki/Software/systemd) or init.d job and
  activates or deactivates it.
* `wrapper`. Wraps the `bin/wrapper` activation script inside the component into
  a [systemd](http://www.freedesktop.org/wiki/Software/systemd) or init.d job
  and activates or deactivates it.

Configuration of the process and wrapper modules
------------------------------------------------
The `process` and `wrapper` modules are supposed to use the host system's
"service manager". Unfortunately, this component differs among operating systems
and system distributions.

By default, Dysnomia is preconfigured to use NixOS' service manager, namely
`systemd`, which expects runtime state files to reside in
`/etc/systemd-mutable/system` and sets `/run/current-system/sw/bin` as the
default `PATH` for services.

If you are planning to use a different Linux distribution, these settings can be
changed through the `--with-systemd-rundir` and `--with-systemd-path` configure
parameters.

`systemd` jobs deployed by Dysnomia are wanted by the `dysnomia.target`, if this
file exists. However, this target file is not created by default. You need to do
this yourself first. The following command typically suffices:

```bash
$ cat > /etc/systemd-mutable/system/dysnomia.target <<EOF
[Unit]
Description=Services that are activated and deactivated by Dysnomia
After=final.target
EOF
```

Apart from `systemd`, Dysnomia can also be used to generate plain old `init.d`
scripts instead. The template that is used to generate these scripts reside in
`data/*.template.initd` of the source distribution. By default, it's configured
to generate an `init.d` script for Ubuntu 12.04 LTS.

If none of the operating system's service manager can be used, Dysnomia can also
activate and deactivate services directly. To accomplish this use the `direct`
template option.

To support other kinds of Linux distributions, you need to adapt these templates
to match your distribution's convention.

Alternatives
------------
If you were previously using the legacy `process` module:

* If you want to deploy a systemd unit, then use: `systemd-unit`
* If you want to deploy an init script, then use: `sysvinit-script`
* If you want to directly manage a daemon, then use the new `process` module
* If you wish to use other process managers, check the [README.md](README.md)
* If you want to dynamically translate a process manager agnostic config file
  to any supported process manager, then use: `managed-process`

If you were previously using the legacy `wrapper` module:

* If your only objective is to delegate the responsibility of executing
  activities to the component, then migrate to the new `wrapper` module
* If you want to manage a daemon, then migrate to the new `process` module
* If you want a daemon to be managed by a process manager then pick any of the
  process management modules described in the [README.md](README.md)

Migrating to these new modules require you to update the component
configurations and redeploy all affected components.
