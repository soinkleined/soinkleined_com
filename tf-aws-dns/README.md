# tf-aws-dns

Route 53 for `daveklein.com` and `soinkleined.com`. One Terraform root per domain and per visibility:

```text
domains/daveklein.com/public
domains/daveklein.com/private
domains/soinkleined.com/public
domains/soinkleined.com/private
```

Each root has its own state object. Applying one cannot change the other. Shared mechanics live in `modules/public-zone` and `modules/private-zone`. Mail data lives in the domain folder (`mail.tf`), not in the module.

The cutover procedure is `MIGRATION.md` in `soinkleined/soinkleined_com`. This repo is the configuration that procedure applies. Nothing here changes the registrar.

## State

Bootstrap once, from a principal that can create a bucket and a customer managed policy. The ongoing role does not have those rights.

```sh
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # set a globally unique bucket name
terraform init
terraform apply
```

Copy `backend.hcl.example` to `backend.hcl` and set `bucket` from the `state_bucket` output. Leave the key out. `scripts/tf.sh` sets it:

| Root | State key |
| --- | --- |
| `domains/daveklein.com/public` | `domains/daveklein.com/public/terraform.tfstate` |
| `domains/daveklein.com/private` | `domains/daveklein.com/private/terraform.tfstate` |
| `domains/soinkleined.com/public` | `domains/soinkleined.com/public/terraform.tfstate` |
| `domains/soinkleined.com/private` | `domains/soinkleined.com/private/terraform.tfstate` |

The lock object is that key plus `.tflock`. `use_lockfile` is native S3 locking and needs Terraform >= 1.10.

`soinkleined-terraform-dns` allows the Route 53 record and zone APIs used here, including `AssociateVPCWithHostedZone` and `DisassociateVPCFromHostedZone` for private zones, plus `CreateHostedZone` on `*`. S3 is limited to `domains/*/terraform.tfstate` and the matching `.tflock`. In an IAM resource ARN, `*` matches slashes, so a new domain under `domains/` does not need a policy edit. `DeleteObject` is on the lock object only. The bucket is SSE-S3. The policy does not grant Route 53 Domains, IAM, KMS, or any other bucket.

`UpdateHostedZoneFeatures` is omitted. This configuration does not set `enable_accelerated_recovery`.

## Day to day

```sh
scripts/tf.sh daveklein.com public init
scripts/tf.sh daveklein.com public plan
scripts/tf.sh daveklein.com public apply
```

Repeat for `soinkleined.com` `public`. `terraform test` does not need AWS. `plan` on a public root must be creates only the first time: one zone, the GitHub Pages addresses, and the mail records in `mail.tf`.

`scripts/tf.sh daveklein.com public output name_servers` is that domain's delegation set. `soinkleined.com` has a different one. The registrar change is not Terraform.

`github_pages_challenge` stays empty until GitHub shows the verification token. On `soinkleined.com`, leave `include_hostrocket_spf` and `include_cpanel_dkim` true until the migration plan says to clear them.

Destroying one public root deletes that zone and the records it owns (`force_destroy` is false, so a record Terraform does not manage blocks the destroy). The other domain is untouched. The state bucket has `prevent_destroy`.

## Private zones

`domains/<domain>/private` creates nothing while `vpcs` is empty. A private hosted zone with no VPC is not a thing Route 53 will create; omitting the VPC would publish a second public zone, so the module refuses an empty list and the root does not instantiate it.

Set `vpcs` when a VPC should resolve the name, then `scripts/tf.sh <domain> private init` and apply. The first VPC is sent on `CreateHostedZone`. Further VPCs in the same account are associated by the provider. This is same-account only. Do not paste the public MX and DKIM into the private root unless something inside the VPC actually looks them up. A private zone is another $0.50 per month once it exists.

## Where to run it

Apply from the Mac with IAM Identity Center, permission set carrying `soinkleined-terraform-dns`. `backend.hcl` and `terraform.tfvars` stay on that machine.

GitHub Actions is optional and later. A free account can hold this private repo. It cannot put required reviewers on an environment in a private repo; that needs GitHub Pro. The example trust policy therefore pins `repo:soinkleined/tf-aws-dns:ref:refs/heads/main`. With Pro, change the subject to `repo:soinkleined/tf-aws-dns:environment:dns` and protect that environment. Do not use a subject of `repo:soinkleined/*`.

## Tests

```sh
terraform -chdir=modules/public-zone init -backend=false
terraform -chdir=modules/public-zone test
terraform -chdir=modules/private-zone init -backend=false
terraform -chdir=modules/private-zone test
scripts/tf.sh daveklein.com public test
scripts/tf.sh daveklein.com private test
scripts/tf.sh soinkleined.com public test
scripts/tf.sh soinkleined.com private test
```

`scripts/tf.sh ... test` runs `terraform init -backend=false` when that root has not been initialised, so the tests do not need `backend.hcl`.

The public tests check the published SPF and DMARC strings, including the space before `rua`, the DKIM lengths, and the 255-octet split. DKIM in a plan contains `""`. That marker is the character-string boundary, not part of the key.
