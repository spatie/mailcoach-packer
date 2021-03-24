## Building the Mailcoach 1-click-installer

This repo contains the Packer configuration used to build the snapshot behind [our 1-click-installer](https://mailcoach.app/docs/v2/app/installation/using-the-1-click-installer) containing a fully configured [Mailcoach](https://mailcoach.app) installation.

## Support us

[<img src="https://github-ads.s3.eu-central-1.amazonaws.com/mailcoach-packer.jpg?t=1" width="419px" />](https://spatie.be/github-ad-click/mailcoach-packer)

We invest a lot of resources into creating [best in class open source packages](https://spatie.be/open-source). You can support us by [buying one of our paid products](https://spatie.be/open-source/support-us).

We highly appreciate you sending us a postcard from your hometown, mentioning which of our package(s) you are using. You'll find our address on [our contact page](https://spatie.be/about-us). We publish all received postcards on [our virtual postcard wall](https://spatie.be/open-source/postcards).

## Using Packer

[Packer](https://www.packer.io/intro/index.html) is a tool for creating images from a single source configuration. Using this Packer template reduces the entire process of creating, configuring, validating, and snapshotting a build Droplet to a single command:

```
ansible-galaxy install jnv.unattended-upgrades
packer build -var 'do_api_token=YOUR_TOKEN' template.json
```

## Usage

To run the Packer build you'll need to [install Packer](https://www.packer.io/intro/getting-started/install.html) and [create a DigitalOcean personal access token](https://www.digitalocean.com/docs/api/create-personal-access-token/) and set it to the `DIGITALOCEAN_TOKEN` environment variable. Running `packer build mailcoach-one-click.json` without any other modifications will create a build Droplet configured with LAMP, clean and verify it, then power it down and snapshot it.

## Configuration Details

By using [Packer's DigitalOcean Builder](https://www.packer.io/docs/builders/digitalocean.html) to integrate with the [DigitalOcean API](https://developers.digitalocean.com/), this template fully automates Marketplace image creation.

This template uses Packer's [file provisioner](https://www.packer.io/docs/provisioners/file.html) to upload complete directories to the Droplet. The contents of `files/var/` will be uploaded to `/var/`. Likewise, the contents of `files/etc/` will be uploaded to `/etc/`. One important thing to note about the file provisioner, from Packer's docs:

> The destination directory must already exist. If you need to create it, use a shell provisioner just prior to the file provisioner in order to create the directory. If the destination directory does not exist, the file provisioner may succeed, but it will have undefined results.

This template also uses Packer's [shell provisioner](https://www.packer.io/docs/provisioners/shell.html) to run scripts from the `/scripts` directory and install APT packages using an inline task.

Learn more about using Packer in [the official Packer documentation](https://www.packer.io/docs/index.html).
