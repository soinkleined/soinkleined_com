# Migration plan: daveklein.com and soinkleined.com

Planning document only. Nothing in this repository changes HostRocket, Route 53, GitHub Pages settings, or the live sites. Checked 23 Oct 2026 from public DNS, RDAP, the live WordPress sites, and the public GitHub repositories. The HostRocket cPanel zone export is the source of truth for any record this document could not see. Reconcile the export with `migration/terraform/dns` before the first apply.

## Recommendation

Move registration to Amazon Route 53 Domains, and move DNS to two Route 53 public hosted zones managed by the Terraform in `migration/terraform`. Leave the HostRocket nameservers in place until those zones exist and have been diffed against the live zones. Serve each site from its own GitHub Pages project repository, with the apex as the canonical host and `www` redirected by GitHub. Copy the Google Workspace mail records unchanged on the first apply.

Apply Terraform from the Mac with IAM Identity Center (section "Where to run Terraform"). The day-to-day policy is created by the bootstrap stack and is scoped to these zones plus the state object.

Close the HostRocket account only after the registrar transfer has completed, the parent-zone NS TTL has expired, and a real mailbox round-trip still authenticates.

## Order

Phases 2, 3, and 5 can run in parallel once phase 0 and phase 1 are done. Phase 6 waits for all three.

| Phase | What changes | Rollback |
| --- | --- | --- |
| 0. Inventory and backups | Nothing live | Nothing to undo |
| 1. Lower TTLs on the HostRocket zones | Cached TTLs only | Put the previous TTLs back |
| 2. Finish the static sites on `*.github.io/<repo>/` | GitHub only; public DNS still points at HostRocket | Leave the WordPress sites where they are |
| 3. `terraform apply` the hosted zones | New zones that are not delegated | `terraform destroy` in `migration/terraform/dns` |
| 4. Verify the domains in GitHub | A TXT record on the current authoritative DNS, and the same value in Terraform | Remove the TXT |
| 5. Transfer registration to Route 53 Domains, nameservers unchanged | Registrar of record, after the transfer completes | Reject the transfer before it completes. After it completes, ICANN locks transfers away for 60 days. DNS rollback is still "put the old nameservers back" |
| 6. Nameserver cutover | Delegation | Put `ns1.myworlddns.com` and `ns2.myworlddns.com` back at the registrar. This works only while the HostRocket zones still serve the pre-cutover data |
| 7. Prove web and mail | Observation | Phase 6 rollback if mail or the new site is wrong |
| 8. HTTPS, then remove HostRocket mail leftovers, then DMARC | Terraform flags, then the GitHub "Enforce HTTPS" checkbox | Set the flags back; turn Enforce HTTPS off |
| 9. Close HostRocket | Account cancellation | There is no clean undo. Reach this phase only after phase 7 has held for the parent NS TTL |

Content freeze starts at phase 6, not before. The WordPress sites can keep running through phase 5.

## What is true today

Registrar for both, from RDAP: eNom, LLC (IANA 48). Status `client transfer prohibited`. Nameservers `ns1.myworlddns.com` and `ns2.myworlddns.com`.

| Domain | Created | Expires | RDAP last changed | SOA serial |
| --- | --- | --- | --- | --- |
| daveklein.com | 1999-03-24 | 2028-03-24 | 2023-03-24 | 2026101700 |
| soinkleined.com | 2012-10-02 | 2027-10-02 | 2022-10-01 | 2026101901 |

The serials mean the HostRocket zones were edited on 17 Oct and 19 Oct 2026. Take the zone export after those dates and diff it against this document. The last-changed dates are old enough that an inter-registrar transfer lock from a previous transfer should not be in force. Confirm that in the registrar panel anyway.

SOA for both is `ns1.myworlddns.com. cpanel.hostrocket.com.` with refresh 3600, retry 3600, expire 1209600, minimum 86400. In-zone NS TTL observed via recursive lookup is 86400. That is not the parent delegation TTL. This environment could not query the `.com` servers (`a.gtld-servers.net` timed out), so measure it before cutover:

```sh
dig +norecurse NS daveklein.com @a.gtld-servers.net
dig +norecurse NS soinkleined.com @a.gtld-servers.net
```

No DS records, so DNSSEC is off. No CAA. No SRV. No apex AAAA. Apex TXT is the SPF record and nothing else, as seen publicly. A Google site-verification TXT, if it exists, is either in the zone and was not returned or it is an HTML meta tag. The export decides.

Apex A for both is `216.120.240.100`. PTR of that address is `alpha.hrwebservices.net`. `rs2.hostrocket.com` currently resolves to `66.147.230.52`, so do not treat that hostname as the site address. The A record is what goes away.

Recursive TTLs on 23 Oct 2026 were not stable for every name (www came back as both 14400 and 300, which is a cache mix). Read the TTL column in the export. From the lookups that were consistent: apex A 300, daveklein.com MX 300, soinkleined.com MX 3600, apex TXT / DKIM / DMARC 3600, `mail`/`calendar`/`docs` CNAMEs 14400.

### Records to reproduce

Both zones:

| Name | Type | Value |
| --- | --- | --- |
| apex | A | `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153` |
| apex | AAAA | `2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153` |
| `www` | CNAME | `soinkleined.github.io` |
| apex | MX | `1 smtp.google.com` |
| `google._domainkey` | TXT | the Google DKIM key already published; stored in `locals.tf` |
| `_dmarc` | TXT | see below |

`daveklein.com` apex TXT: `v=spf1 include:_spf.google.com ~all`

`soinkleined.com` apex TXT, first apply: `v=spf1 include:_spf.google.com include:_spf.hostrocket.com ~all`

DMARC, byte for byte, including the space before `rua`:

```text
v=DMARC1;p=quarantine; rua=mailto:info@daveklein.com
v=DMARC1;p=quarantine; rua=mailto:david@soinkleined.com
```

`soinkleined.com` only, and only while WordPress can still send:

| Name | Type | Value |
| --- | --- | --- |
| `x._domainkey` | TXT | cPanel DKIM key, in `locals.tf` |
| `mail` | CNAME | `ghs.googlehosted.com` |
| `calendar` | CNAME | `ghs.googlehosted.com` |
| `docs` | CNAME | `ghs.googlehosted.com` |

GitHub Pages addresses are the ones published in GitHub's custom-domain docs on 23 Oct 2026. Re-read that page before the first apply. The www target is the user Pages hostname for both zones. GitHub routes on the Host header to the repository that claimed that domain. The target does not include the repository name, and it is not a `*.pages.github.io` name.

DKIM values are longer than a single Route 53 character-string. Terraform splits them at 255 octets. In a plan, the split shows up as `""` inside the TXT value. That marker is not part of the key. `terraform test` in `migration/terraform/dns` checks the published SPF, DMARC, and key lengths.

TTL on every record Terraform manages is 300 until phase 8. A shorter TTL than today's 3600/14400 records is intentional.

### Records that were visible and stay out of the new zones

These are cPanel defaults aimed at `216.120.240.100`. Leave them off the new zones unless the export shows a client that is not the hosting panel.

- Both zones: `autoconfig`, `cpanel`, `webmail`, `ftp`, `whm`, `webdisk`, `cpcalendars`, `cpcontacts`
- `soinkleined.com` also: `autodiscover`

No wildcard records. A wildcard delegated at GitHub Pages is a domain-takeover bug even after the domain is verified.

Anything else in the export (a real subdomain, a verification TXT, a CAA) goes in `extra_apex_txt` or `extra_records` in `terraform.tfvars`. Apex TXT values share one record set, so a verification string is an extra value on the apex TXT, not a second resource. `extra_records` rejects NS, SOA, and the names this module already manages.

## Sites and repositories

Both live sites are WordPress 7.1.3 on LiteSpeed. Apex redirects to www. GitHub Pages will invert that if the custom domain field is the apex: www then 301s to the apex, and both names keep working.

### soinkleined.com

Public content is small. Permalinks are `/%postname%/`.

- Posts: `/why-virtualize/`, `/how-to-expand-a-unix-group-and-list-all-of-its-members/` (modified 2022-01-07)
- Pages: `/` (slug `main`), `/about/`, `/blog/`
- Portfolio: `/portfolio_page/infrastructure-standards/`
- Categories: `/category/virtualization/`, `/category/perl/`
- The homepage is a LayerSlider. It does not need to come across as a slider
- The public comments API returned an empty list. The database is still the authority. Treat comments as spam unless the export shows otherwise, and do not put a comment system on the static site

This repository (`soinkleined/soinkleined_com`) is the unmodified Hydejack starter. Title is still "Starter Kit", the author is a placeholder, and the only posts are the theme examples under `example/_posts`. `_config.yml` has `url` and `baseurl` commented out, with the project-site path `/soinkleined_com` in the comment. Permalink style `/:categories/:year-:month-:day-:title/` matches none of the WordPress URLs. `jekyll-redirect-from` is already in the Gemfile, which is the right plugin for the few URLs that will not match `/:title/`.

There is no GitHub Actions workflow. Pages is enabled and `https://soinkleined.github.io/soinkleined_com/` returns HTTP 200 with `content-length: 0` (last-modified 2025-06-30). The theme gem plus `kramdown-math-katex` will not build on GitHub's legacy Pages pipeline. Publishing has to be a GitHub Actions workflow of the kind already described in `docs/deploy.md`. Until that build is green and the real posts are in the repo, this site is not a cutover candidate.

Left to do in this repo, as a later change, not this PR:

- Export the two posts, the about page, and the portfolio page. WXR from Tools → Export, plus `wp-content/uploads`, plus a SQL dump. WXR does not reliably carry the binaries
- Set `url: https://soinkleined.com` and `baseurl: ""` when the custom domain is attached. On the project URL, baseurl stays `/soinkleined_com`
- Set permalink `/:title/` so the two posts keep their paths. Add `redirect_from` for `/portfolio_page/infrastructure-standards/` and the two category URLs, or replace the category URLs with one archive page and a redirect
- Add the Actions workflow. Drop the example content
- Custom domain in the Pages settings is `soinkleined.com`. `migration/examples/CNAME.soinkleined.com` is the file a branch-based publish would commit as `CNAME`. An Actions publish ignores that file. The example is the apex name, not `soinkleined.github.io`

### daveklein.com

Also WordPress. Permalinks are `/%year%/%monthnum%/%postname%/`. Thirteen posts from April 2010 through July 2012 (`/2010/04/toggledisplayscale-released/` through `/2012/07/ozone-coffee-rules/`). Pages include `/about/`, `/about/contact/`, `/about/curriculum-vitae/`, `/photos/`, and a set of photo-gallery subpages under `/photos/`. The comments API returns 404, so it says nothing about the comment tables.

`soinkleined/daveklein_com` is a public fork, Pages on, Actions workflow `.github/workflows/jekyll-gh-pages.yml`, and `https://soinkleined.github.io/daveklein_com/` returns the theme. It is not ready for the apex:

- `_config.yml` still has `baseurl: "/daveklein_com"` and `url: "https://soinkleined.github.io"`. The built HTML references `/daveklein_com/...`. On the apex those assets 404 until baseurl is `""` and the site is rebuilt. The workflow runs `jekyll build` with no `--baseurl`, so the config value wins
- `/cv/` is a real CV. The six files in `_posts/` are May 2026 theme samples, not the WordPress archive
- `permalink: pretty` emits a day segment. WordPress does not. Use `/:year/:month/:title/` or `redirect_from` on each historical post
- `jekyll-redirect-from` is not in the Gemfile. Add it for `/about/`, `/about/contact/`, `/about/curriculum-vitae/`, and any photo URL that should survive
- No custom domain is configured. Actions will ignore a `CNAME` file. Set the Pages custom domain to `daveklein.com`. `migration/examples/CNAME.daveklein.com` is the branch-publish equivalent

The photo galleries are the bulk of that site. Migrating them is a content decision (open questions), not a DNS step. A static cutover that only publishes the new CV will 404 every `/2010/...` and `/photos/...` URL. Decide that before phase 6.

### online-cv and github.io

`soinkleined/online-cv` is a fork of the Orbit CV theme. Pages is on at `https://soinkleined.github.io/online-cv/` and the data file is David's CV, overlapping `daveklein_com`'s `/cv/`. `_config.yml` still has `url: http://webjeda.com`. The `CNAME` file on `main` contains `online-cv.webjeda.com`, the upstream demo hostname. Delete that file before any custom-domain work. A `CNAME` is what GitHub uses for a branch publish. There are also branches `cursor/pages-actions-build-79e4` and `cursor/fix-print-pages-79e4`; confirm which source is actually publishing. Do not attach either apex to this repository. If the CV should have its own hostname later, that is a separate name such as `cv.daveklein.com`, added as its own record and its own Pages domain.

`soinkleined/github.io` is an empty repository (a README only), `has_pages` false, last pushed 2024-04-25. A user site has to live in a repository named exactly `soinkleined.github.io`. This one does not. `https://soinkleined.github.io/` 404s, which is what an account with no user site looks like.

### How the Pages hostnames interact

- Project sites are `https://soinkleined.github.io/<repo>/`. A custom domain on a project site serves that repository at the domain root. `baseurl` must be empty on that build
- Both apexes can be live at once, on two repositories. Each repository gets one custom domain. www and the apex are a pair: the name typed into the Pages custom-domain field is canonical, and GitHub 301s the other name if both DNS records point at Pages
- The DNS CNAME for www on both domains is `soinkleined.github.io`. The repository mapping is the custom domain saved on the repo, not the CNAME target
- A user site created later as `soinkleined/soinkleined.github.io` would publish at `https://soinkleined.github.io/`. If that user site were given `soinkleined.com` or `daveklein.com`, project sites that do not have their own custom domain would start appearing as paths under that apex. Leave the user site unpublished, or give it a hostname that is neither apex
- Verify each domain for the `soinkleined` account before the A/AAAA records are delegated. The TXT name is `_github-pages-challenge-soinkleined`. GitHub looks it up on the public internet, which still means HostRocket until phase 6, so the TXT has to exist in both places before the cutover
- Enforce HTTPS only after GitHub has issued the certificate. That checkbox can stay disabled for up to 24 hours after DNS is correct. GitHub Pages certificates come from Let's Encrypt. There is no CAA today. If CAA is added, `letsencrypt.org` has to be an `issue` issuer. The Terraform variable refuses a CAA list that omits it
- Add the custom domain on the repository before the A/AAAA/CNAME records point at GitHub. Pointing DNS at Pages for a domain no repository has claimed is the takeover case GitHub documents

## Phase 0 — Inventory and backups

From HostRocket cPanel, for each domain:

- Zone Editor export. Save it next to the Terraform, outside git if it contains anything that should not be published. Diff every record against the tables above
- Full account backup, plus a separate dump of each WordPress database and a copy of `wp-content/uploads`
- Email → Email Accounts. MX is Google, so these should be empty or system-only. If a mailbox has mail, export it before any thought of closing the account. Google Workspace is not in this backup
- Cron Jobs. Note the command, schedule, and which address it sends as. DMARC aggregate reports show MailChannels (`include:_spf.hostrocket.com`) sending WordPress mail as `wordpress@soinkleined.com` (comment moderation, update mail) and a once-daily message as `daveklein.com` from 14 Sep 2026 through 7 Oct 2026. Find that daily job here or in a plugin. Those senders end when the sites leave this host. A static site does not replace them. A contact form, if one should survive, is a form host or a `mailto:`, chosen in the open questions
- Addon domains, parked domains, subdomains, FTP accounts, and databases that are not these two WordPress sites
- Confirm the registrant email that eNom will use for the transfer approval, and whether the login that can unlock the domain is the HostRocket panel or a direct eNom account

Rollback: none. Do not change records in this phase.

## Phase 1 — Lower TTLs

On the HostRocket zones, set TTL 300 on every record that will differ after cutover and on every mail record: apex A, www CNAME, MX, apex TXT, `google._domainkey`, `_dmarc`, `x._domainkey`, `mail`, `calendar`, `docs`. Wait out the previous TTL of the slowest of those (www and the Google CNAMEs are the ones to check in the export) before phase 6.

Rollback: restore the exported TTLs.

## Phase 2 — Static sites on the project URLs

Build and review both sites at `https://soinkleined.github.io/soinkleined_com/` and `https://soinkleined.github.io/daveklein_com/`. Custom domains stay off the repositories until phase 4's verification has succeeded, and the A records stay on HostRocket until phase 6.

For daveklein.com, historical URLs that should survive need either a matching permalink or `redirect_from`. For soinkleined.com, `/:title/` plus a redirect for the portfolio path covers the public sitemap. Generate the redirect list from the WXR, not from memory.

Rollback: the WordPress sites are still the public sites.

## Phase 3 — Terraform the zones, do not delegate

Terraform layout:

| Path | Role |
| --- | --- |
| `migration/terraform/bootstrap` | State bucket and the IAM policy. Local state. `prevent_destroy` on the bucket |
| `migration/terraform/dns` | Both hosted zones and the records in this document. Remote state |
| `migration/terraform/iam/terraform-dns-policy.json.tftpl` | The policy bootstrap renders |
| `migration/terraform/iam/github-actions-trust.json.example` | Trust policy if phase "Where to run Terraform" option (c) is used later |
| `migration/terraform/dns/backend.hcl.example` | Copy to `backend.hcl` (gitignored) |

Bootstrap once, from a principal that can create a bucket and a customer managed policy. The ongoing role does not have those rights.

```sh
cd migration/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # set a globally unique bucket name
terraform init
terraform apply
```

Copy `state_bucket`, `state_key`, and `aws_region` from the outputs into `migration/terraform/dns/backend.hcl`:

```hcl
bucket       = "<state_bucket>"
key          = "dns/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
```

`use_lockfile` is native S3 locking (Terraform >= 1.10). The lock object is `<key>.tflock`. DynamoDB locking is deprecated in current Terraform and is not used. A DynamoDB table would only be a compatibility bridge for a Terraform older than 1.10, which this config refuses.

```sh
cd migration/terraform/dns
terraform init -backend-config=backend.hcl
terraform test
terraform plan
terraform apply
```

`terraform test` does not need AWS. It checks the mail strings and the DKIM split. `terraform plan` must be creates only: two zones and the records in this document. Defaults keep the HostRocket SPF include and the cPanel DKIM key. `github_pages_challenge` stays empty until phase 4, then it is a second apply.

The plan's DKIM lines contain `""`. That is the 255-octet boundary.

`terraform output name_servers` is the delegation set. Those four names are not predictable until the zone exists. Nothing at the registrar should use them until phase 6.

Route 53 will answer for the zone only on those nameservers. Creating the zone does not move traffic.

Rollback: `terraform destroy` in `migration/terraform/dns`. `force_destroy` is false; Terraform deletes the records it owns, then the zone. The state bucket has `prevent_destroy` and is not part of that destroy.

### Policy

Bootstrap creates `soinkleined-terraform-dns`. It allows:

- Route 53 record and zone operations on `arn:aws:route53:::hostedzone/*` and `arn:aws:route53:::change/*`: `ChangeResourceRecordSets`, `ChangeTagsForResource`, `DeleteHostedZone`, `GetChange`, `GetHostedZone`, `ListResourceRecordSets`, `ListTagsForResource`, `UpdateHostedZoneComment`
- `route53:CreateHostedZone` on `*`. Create cannot be scoped to a zone id that does not exist yet
- `s3:ListBucket` on the state bucket, prefix limited to the state key
- `s3:GetObject` and `s3:PutObject` on the state object
- `s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on the `.tflock` object

`DeleteObject` is on the lock object only. Terraform does not delete the state object. The bucket uses SSE-S3. Switching it to SSE-KMS requires `kms:Decrypt` and `kms:GenerateDataKey` on that key, which this policy does not grant.

Two Route 53 actions showed up in a mechanical reading of the provider schema and are omitted because `hashicorp/aws` v6.70.0 does not call them for this configuration: `AssociateVPCWithHostedZone` runs only when a `vpc` block is set, and `UpdateHostedZoneFeatures` runs only when `enable_accelerated_recovery` is set. This stack sets neither. `UpdateHostedZoneComment` and `DeleteHostedZone` are included because the zone comment is a managed attribute and destroying an undelegated zone is the phase 3 rollback.

The policy does not grant Route 53 Domains, IAM, or any other bucket. Registrar changes stay a separate, explicit step. Attach the policy to an Identity Center permission set. It grants nothing until it is attached.

S3 backend calls are not in a Terraform plan, so those three statements are the S3 backend permission list from the Terraform 1.14+ docs, with the prefix set to the state key. The upstream example prefixes the bucket name into `s3:prefix`; the object key is the value that `ListBucket` actually sends.

### Import

If a zone already exists (hand-built, or created by a transfer wizard), import it instead of creating a second public zone. Two public zones for the same name can coexist. Only the delegated one answers, and both cost $0.50 per month.

```sh
terraform import 'aws_route53_zone.apex["daveklein.com"]' Z0123456789ABCDEFGHIJ
terraform import 'aws_route53_record.apex_a["daveklein.com"]' Z0123456789ABCDEFGHIJ_daveklein.com_A
terraform import 'aws_route53_record.apex_aaaa["daveklein.com"]' Z0123456789ABCDEFGHIJ_daveklein.com_AAAA
terraform import 'aws_route53_record.www["daveklein.com"]' Z0123456789ABCDEFGHIJ_www.daveklein.com_CNAME
terraform import 'aws_route53_record.mx["daveklein.com"]' Z0123456789ABCDEFGHIJ_daveklein.com_MX
terraform import 'aws_route53_record.apex_txt["daveklein.com"]' Z0123456789ABCDEFGHIJ_daveklein.com_TXT
terraform import 'aws_route53_record.dmarc["daveklein.com"]' Z0123456789ABCDEFGHIJ__dmarc.daveklein.com_TXT
terraform import 'aws_route53_record.google_dkim["daveklein.com"]' Z0123456789ABCDEFGHIJ_google._domainkey.daveklein.com_TXT
```

Repeat for `soinkleined.com`, plus:

```sh
terraform import 'aws_route53_record.cpanel_dkim[0]' Z0123456789ABCDEFGHIJ_x._domainkey.soinkleined.com_TXT
terraform import 'aws_route53_record.google_app["mail.soinkleined.com"]' Z0123456789ABCDEFGHIJ_mail.soinkleined.com_CNAME
terraform import 'aws_route53_record.google_app["calendar.soinkleined.com"]' Z0123456789ABCDEFGHIJ_calendar.soinkleined.com_CNAME
terraform import 'aws_route53_record.google_app["docs.soinkleined.com"]' Z0123456789ABCDEFGHIJ_docs.soinkleined.com_CNAME
```

NS and SOA belong to the zone resource. Do not import them as records. After import, `terraform plan` should be empty, or it should show only the differences you are about to publish (the GitHub A/AAAA/CNAME, and a lower TTL). A plan that replaces an MX or a DKIM value is a bug in the tfvars. Read it.

A record that exists in the zone and is not imported will make apply fail with "already exists". Import it, or delete that one console record, then apply. The next `terraform plan` is the drift check from then on. A console edit shows up there. Put it back by apply, or import the intended change into the config. The lockfile is what keeps two applies from writing the state at once. Versioning on the bucket is how a bad state object is restored.

## Phase 4 — Verify the domains in GitHub

In GitHub, verify `daveklein.com` and `soinkleined.com` for the `soinkleined` account. Put the TXT value GitHub displays at `_github-pages-challenge-soinkleined` on the HostRocket zone first, wait for the lookup to succeed, and click verify. Then set the same values in `github_pages_challenge` and apply Terraform so the TXT is still there after the nameservers move. Verification that exists only on HostRocket lapses at cutover.

Add each apex as the custom domain on its repository after verification, while DNS still points at HostRocket. GitHub will report the DNS check as failing until phase 6. That is the safe order.

Rollback: remove the TXT and remove the custom domain from the repository.

## Phase 5 — Transfer the registrar, keep the nameservers

Transfer both domains to Route 53 Domains. HostRocket is the likely eNom reseller. Cancelling that account before the domains are in an account he controls is how these get stranded. A direct eNom login that survives HostRocket would also work. Route 53 is the better end state: registration and DNS in the account he already uses, and the nameserver change in phase 6 is an AWS API call.

`.com` registration, renewal, and transfer on the Route 53 price list are $16 per year as of 1 Jul 2026. A transfer adds a year to the current expiry. Budget $32 at transfer time, then $16 per domain per year. Confirm the live price in the console before paying. Promotional credit does not pay domain fees.

Steps:

1. Confirm the registrant email receives mail. Turn off privacy if it hides that address
2. Remove `client transfer prohibited` and copy the EPP auth code. Do this while the HostRocket account still exists
3. Start the transfer in Route 53 Domains (`us-east-1` only). Keep the current nameservers, `ns1.myworlddns.com` and `ns2.myworlddns.com`. Accepting the wizard's offer to create a hosted zone and switch delegation publishes an empty zone and takes mail down
4. Approve the transfer from the registrant email
5. When the transfer shows as complete, re-lock the domains. They will also be under the 60-day transfer lock
6. `aws route53 list-hosted-zones-by-name --dns-name daveklein.com` (and the other name). If the transfer created a zone, import it in phase 3's import procedure. Do not let Terraform create a second one, and do not change the registered nameservers yet

Rollback: decline the transfer if it has not completed. After it has, the registrar move itself stays for 60 days. The live site is unaffected because the nameservers did not change.

## Phase 6 — Nameserver cutover

Preconditions: phase 1's TTL wait has elapsed, phase 2's project URLs look right, phase 3's plan is clean, phase 4's verification is green, and he can edit nameservers either in Route 53 Domains or still at eNom.

At the start of the cutover, disable WordPress cron, comment posting, and any mail-sending plugin on the HostRocket copy. Resolvers will keep using the old nameservers until the parent NS TTL expires, so that host will still receive some traffic and would otherwise keep emitting the MailChannels mail.

Delegation, after `terraform output -json name_servers`:

```sh
aws route53domains update-domain-nameservers \
  --region us-east-1 \
  --domain-name daveklein.com \
  --nameservers \
    Name=ns-AAAA.awsdns-XX.com \
    Name=ns-BBBB.awsdns-XX.net \
    Name=ns-CCCC.awsdns-XX.org \
    Name=ns-DDDD.awsdns-XX.co.uk
```

Repeat for `soinkleined.com`. Use the four names from the output. If the domain is still at eNom, enter those four names there. They are already glued in the `awsdns-*` zones. Do not add glue at eNom.

Before changing anything, diff the two authorities. Mail must match. Web must not. TXT comparison concatenates character-strings, because cPanel and Route 53 split long DKIM values at different boundaries. A raw `dig` diff of those quotes is noise.

```sh
NS=<one route53 nameserver from the output>
txt() { dig +short TXT "$1" @"$2" | python3 -c 'import sys,re; print("".join(re.findall("\"([^\"]*)\"", sys.stdin.read())))'; }
for name in daveklein.com soinkleined.com; do
  echo "== $name =="
  diff -u \
    <(dig +short MX "$name" @ns1.myworlddns.com | sort) \
    <(dig +short MX "$name" @"$NS" | sort)
  for owner in "$name" "google._domainkey.$name" "_dmarc.$name"; do
    diff -u <(txt "$owner" ns1.myworlddns.com) <(txt "$owner" "$NS")
  done
  echo "-- route53 web --"
  dig +short A "$name" @"$NS"
  dig +short AAAA "$name" @"$NS"
  dig +short CNAME "www.$name" @"$NS"
done
diff -u \
  <(txt x._domainkey.soinkleined.com ns1.myworlddns.com) \
  <(txt x._domainkey.soinkleined.com "$NS")
dig +short CNAME mail.soinkleined.com @"$NS"
dig +short CNAME calendar.soinkleined.com @"$NS"
dig +short CNAME docs.soinkleined.com @"$NS"
```

Expected mail diff: empty. Expected web answers: the four A addresses, the four AAAA addresses, and `soinkleined.github.io`. The Google CNAMEs should be `ghs.googlehosted.com`.

Rollback: set the registrar nameservers back to `ns1.myworlddns.com` and `ns2.myworlddns.com`. Leave the HostRocket zones untouched until phase 7 has held for the parent NS TTL.

## Phase 7 — Prove web and mail

Watch delegation from more than one resolver. Parent TTL dominates, so this is not instant.

```sh
dig +short NS daveklein.com @8.8.8.8
dig +short NS daveklein.com @1.1.1.1
dig +short NS soinkleined.com @8.8.8.8
dig +short NS soinkleined.com @1.1.1.1
dig +norecurse NS daveklein.com @a.gtld-servers.net
dig +short A daveklein.com @8.8.8.8
dig +short AAAA daveklein.com @8.8.8.8
dig +short CNAME www.daveklein.com @8.8.8.8
dig +short MX daveklein.com @8.8.8.8
dig +short MX soinkleined.com @8.8.8.8
dig +short TXT daveklein.com @8.8.8.8
dig +short TXT soinkleined.com @8.8.8.8
```

Web, once a resolver has the new NS:

```sh
curl -sI http://daveklein.com
curl -sI http://www.daveklein.com
curl -sI http://soinkleined.com
curl -sI http://www.soinkleined.com
```

`server: GitHub.com` is the new site. HTTPS will fail until the certificate exists. That is expected in this phase.

Mail, from outside and from each domain:

- Send from `info@daveklein.com` and from `david@soinkleined.com` to an external mailbox, and reply inbound
- On the received copy, `Authentication-Results` should show `spf=pass`, `dkim=pass` with `header.d` equal to the sending domain and `header.s=google`, and `dmarc=pass`
- Open `https://mail.soinkleined.com`, `https://calendar.soinkleined.com`, and `https://docs.soinkleined.com` and confirm they still land on Google
- Read the next DMARC aggregate reports at `info@daveklein.com` and `david@soinkleined.com`. During the parent TTL, MailChannels may still appear because the old host can still send. After cron is off and the old NS have expired, the only sources should be Google

Rollback of a mail failure is phase 6's nameserver revert. Do not "fix" it by deleting the Google MX.

## Phase 8 — HTTPS, then mail tightening

When GitHub enables the checkbox, turn on Enforce HTTPS for both repositories. Canonical host is the apex, so www 301s to it. That is the reverse of today's WordPress redirect. Both names still resolve.

After the parent NS TTL has expired and at least one week of DMARC reports shows no MailChannels or other HostRocket source:

```hcl
include_hostrocket_spf = false
include_cpanel_dkim    = false
```

`terraform plan` should show two changes: the soinkleined.com apex TXT loses `include:_spf.hostrocket.com`, and `x._domainkey.soinkleined.com` is destroyed. `daveklein.com` SPF was already Google-only and must stay that way. Apply, then send one more mail from each domain and check `dmarc=pass`.

`p=reject` is a later apply, after several clean weekly reports:

```hcl
dmarc_policy = "reject"
```

That produces `v=DMARC1;p=reject; rua=mailto:...` with the same rua addresses. Tightening SPF from `~all` to `-all` can ride along with that change. It is a one-line edit in `locals.tf`, reviewed in the plan. Leave rua in place.

Optional after that: raise `record_ttl` from 300 to 3600. Optional CAA:

```hcl
caa_issuers = {
  "daveklein.com"   = ["letsencrypt.org"]
  "soinkleined.com" = ["letsencrypt.org"]
}
```

Rollback: set the flags and `dmarc_policy` back and apply. Turn off Enforce HTTPS if a certificate mis-issue ever requires it.

## Phase 9 — Close HostRocket

All of these are true before cancellation:

- Zone export, files, and both databases are stored somewhere that is not the HostRocket account
- Any mailbox that actually had mail has been exported. Google Workspace is untouched
- Both domains show Route 53 as registrar, are locked, and the registered nameservers are the Route 53 set
- `dig +norecurse NS` against a `.com` server returns only those nameservers, and has done so for at least that NS TTL
- Phase 7's mail test has been repeated after that TTL
- Cron jobs found in phase 0 are disabled or irrelevant, and nothing else (another domain, a certificate renewal, a billing contact) depends on the account
- Domain renewal is no longer billed by HostRocket. The transfer is what makes that true
- A final `terraform plan` is empty

Then cancel. There is no rollback.

## Where to run Terraform

Recommendation: the Mac, option (a). Two zones and a few applies a year do not need a pipeline. The state bucket is what makes the laptop replaceable. Option (c) is the same roles and the same state, added later if a pull-request gate is worth it. The trust policy for that is already in the repo.

| | (a) Mac | (b) Linux host or VM he runs | (c) GitHub Actions, OIDC | (d) Console |
| --- | --- | --- | --- | --- |
| Credentials | `aws login` or IAM Identity Center. Permission set carries `soinkleined-terraform-dns`. No access keys | The same profile, or an instance profile of a role with that policy if the host is single-purpose. No access keys on disk | `sts:AssumeRoleWithWebIdentity`. Trust is `github-actions-trust.json.example`: audience `sts.amazonaws.com`, subject `repo:soinkleined/soinkleined_com:environment:dns`. Create the GitHub environment `dns` with required reviewers. No stored keys | SSO session in the console. No keys |
| State | S3, versioned, SSE-S3, public access blocked, `use_lockfile = true` | Same bucket | Same bucket. Apply from the protected environment only | No state. The console becomes the source of drift |
| Drift | `terraform plan` | `terraform plan` | Plan on the pull request, apply on the environment | Every click is drift. Follow it with a plan and either import or revert |
| Effort | One bootstrap apply, then a plan and apply per change | The same, plus patching a machine that has no other reason to exist | OIDC provider, role, environment protection, and a workflow. Worth it when someone else should approve a DNS change | Fastest for one record. Slower from the second edit onward |
| Cost | $0 of compute | $0 if the machine already exists. A new VM is wasted money at this size | Public-repo Actions minutes. Effectively $0 for a handful of applies | $0 |

`backend.hcl` and `terraform.tfvars` stay on the machine that applies. They hold the bucket name and, later, the GitHub challenge token. They are gitignored. The state file holds the zone contents, which are public DNS, including the DKIM public keys. Keep the bucket private anyway. Bootstrap's bucket policy denies non-TLS. Restoring a bad apply is an S3 object-version restore of `dns/terraform.tfstate`, then `terraform plan`.

Do not put long-lived keys in `~/.aws/credentials` for this. Identity Center is the Mac path. The Actions path uses the OIDC provider `https://token.actions.githubusercontent.com` with client id `sts.amazonaws.com`, then a role whose permissions policy is the one bootstrap created and whose trust is the example file with `ACCOUNT_ID` replaced. A wildcard `sub` of `repo:soinkleined/*` would let any workflow in the account assume the role. The example does not do that.

Option (d) is the break-glass path during an outage when Terraform is not at hand. The following `terraform plan` is what puts the zone back under the config. A Route 53 change-batch file is intentionally not in this repo. It would be a second source of truth.

CloudTrail on the account should already record `ChangeResourceRecordSets` and `UpdateDomainNameservers`. If it does not, turn it on before phase 6. This plan does not add a trail.

## Cost

Checked against the Route 53 pricing page and the domain price list on 23 Oct 2026.

| Item | Cost |
| --- | --- |
| Two public hosted zones | $0.50 each, $1.00 per month, not prorated. A zone deleted within 12 hours is not billed; queries still are |
| Standard queries | $0.40 per million for the first billion. These are not alias records, so they are billed. Two personal zones plus mail lookups should stay well under a million queries a month, so the query line is cents, not dollars |
| State bucket | Versioned JSON. Pennies, inside S3 free-tier noise if the account still has it |
| DynamoDB, Resolver, health checks, DNSSEC KMS | $0. None of them are in this design. DNSSEC signing later is a KMS key on top |
| Domain transfer and renewal | $16 per `.com` per year on the 1 Jul 2026 price list. $32 to transfer both (one year added to each expiry), then $16 per domain per year |
| GitHub Pages | $0 for these public repositories |

Call the steady state about $1 to $2 per month for DNS, plus $32 per year of registration once the transfer years roll into renewals. Re-check the `.com` price in the console before starting the transfer. It moves.

## Open questions

- Is the eNom account reachable only through HostRocket, and which address receives the transfer approval?
- Apex as the canonical host, or keep today's www canonical? This plan uses the apex
- daveklein.com: migrate the 2010–2012 posts and the `/photos/` galleries, keep them as an offline archive, or drop them?
- soinkleined.com: migrate the two posts, about page, and portfolio page, or replace the site with a short page?
- Should either site have a contact form, and if so which form host? Nothing on GitHub Pages will run the current PHP
- Which rows in the zone export are absent from this document?
- What else is on the HostRocket account (other domains, mailboxes, cron, databases)?
- What is the daily daveklein.com sender, and which Google Workspace mailboxes must still receive mail the morning of the cutover?
- Which CV is canonical, `daveklein_com`'s `/cv/` or `online-cv`?
- Which AWS account holds the state bucket? The config assumes `us-east-1`
- Add DNSSEC or CAA after the move, or leave both off as they are today?
- Local apply, or GitHub Actions once the first cutover is done?
