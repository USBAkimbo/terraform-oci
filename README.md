# What is this?
- This is a repo for my Terraform config for Oracle Cloud
- This config automatically does the following:
  - Spins up an instance of Ubuntu Server using the Always Free tier
  - Triggers Ansible to
    - Automate patching
    - Install Docker
    - Install Traefik reverse proxy
    - Install Filebrowser behind the reverse proxy

# Requirements
- Linux machine to run this from (WSL works on Windows)
- Terraform
- Ansible
- [OCI-CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)
- [Oracle Terraform docs for reference](https://learn.hashicorp.com/collections/terraform/oci-get-started)

# Getting started
- You need to be running from some kind of Linux terminal
- I did this in WSL 2 with Ubuntu, so that works if you need something
- Start by cloning this repo

```
git clone https://github.com/USBAkimbo/terraform-oci
cd terraform-oci
```

- Initialize Terraform

```
terraform init
```

- Copy the example vars file

```
cp tfvars.example terraform.tfvars
```

- Modify the `terraform.tfvars` file to include your Oracle account variables and Cloudflare variables
- Modify `ansible-config.yml` to include your email and the dns hostname for your Filebrowser
- My example uses my Ansible Vault strings
- You can do this using

```
ansible-vault encrypt_string yourstringhere
<enter vault password>
!vault |
          $ANSIBLE_VAULT;1.1;AES256
          62343563353836383962376363393931343961316331343564653939303030356638386136666562
          3161653562333736313162623630626538646264643035350a623939623532346462353432316231
          63393762333435613833306136633761323932336539623462353733636335383235653162616562
          6261386236303631310a376536303333643338663136323031613662343038663765656530313061
          6264
```

- You don't have to use vault, so your file could look like this

```
- hosts: all
  roles:
    - patch
    - install-docker
    - install-traefik
    - install-filebrowser
  vars:
    email: me@example.com
    dns_name: filebrowser-cloud.mydomain.com
```

- Once this is all done, run the following to start the build

```
terraform apply
```

- Note that this will probably fail for the first time on the Ansible step
- This is because the VM probably isn't ready just yet
- If it does fail, just re-run the command again
- That should be it! Give it a few minutes and your site should be accessible at `https://filebrowser-cloud.yourdomain.com`