# dpl-cms-dev

[dpl-cms](https://github.com/danskernesdigitalebibliotek/dpl-cms) development setup for [ITK
Development](https://github.com/itk-dev) (and others using [ITK-dev docker
setup](https://github.com/itk-dev/devops_itkdev-docker)).

## Getting started

We use [Task](https://taskfile.dev/), so run

``` shell
task dev:install
task dev:update
```

to get started.

This will install dpl-cms and make it available on <https://dpl-cms-develop.local.itkdev.dk/>. The development setup
also contains the latest stable version of [pretix](https://pretix.eu/) and pretix is available on
<http://pretix.dpl-cms-develop.local.itkdev.dk/> with the default admin credentials; see [Small-scale deployment with
Docker](https://docs.pretix.eu/en/latest/admin/installation/docker_smallscale.html#next-steps) for details.

------------------------------------------------------------------------------------------------------------------------

``` shell
git clone https://github.com/danskernesdigitalebibliotek/dpl-cms dpl-cms

docker compose --profile pretix pull
docker compose --profile pretix  up --detach

# @todo resolve `sh: 1: [[: not found` error due to `"post-drupal-scaffold-cmd"` in composer.json.
# Make `sh` point to `bash` (rather than `dash` which is the default in Ubuntu)
docker compose exec --user root phpfpm bash -c 'ln -sf bash /bin/sh'
docker compose exec phpfpm composer install

git clone --branch dpl_pretix https://github.com/rimi-itk/dpl_pretix dpl-cms/web/sites/default/files/modules_local/dpl_pretix

cat >| dpl-cms/web/sites/default/settings.local.php <<'EOF'
<?php

$settings['hash_salt'] = 'V-tz1Y86bnQ7IDugaKTbx0goQR64ewhdsWlscc00813DSYYuEf9ziG2Qqfo1zshlVQF_n37Lbg';

$databases['default']['default'] = [
  'database' => getenv('DATABASE_DATABASE') ?: 'db',
  'username' => getenv('DATABASE_USERNAME') ?: 'db',
  'password' => getenv('DATABASE_PASSWORD') ?: 'db',
  'host' => getenv('DATABASE_HOST') ?: 'mariadb',
  'port' => getenv('DATABASE_PORT') ?: '',
  'driver' => getenv('DATABASE_DRIVER') ?: 'mysql',
  'prefix' => '',
];

$config['system.logging']['error_level'] = ERROR_REPORTING_DISPLAY_VERBOSE;

EOF

docker compose exec phpfpm vendor/bin/drush --yes site:install --existing-config
docker compose exec phpfpm vendor/bin/drush --yes cache:rebuild
docker compose exec phpfpm vendor/bin/drush --yes pm:uninstall purge
docker compose exec phpfpm vendor/bin/drush --yes pm:install devel dpl_example_content dpl_example_breadcrumb field_ui restui uuid_url views_ui dblog

docker compose exec phpfpm vendor/bin/drush --yes pm:install dpl_pretix

open $(docker compose exec phpfpm vendor/bin/drush --uri=$(itkdev-docker-compose url) user:login /admin/config/dpl_pretix)
```

``` shell
docker compose exec phpfpm vendor/bin/drush --yes config:set dpl_pretix.settings pretix.url http://pretix.dpl-cms-develop.local.itkdev.dk/
docker compose exec phpfpm vendor/bin/drush --yes config:set dpl_pretix.settings pretix.organizer_slug dpl-cms
# http://pretix.dpl-cms-develop.local.itkdev.dk/control/organizer/dpl-cms/team/1/
docker compose exec phpfpm vendor/bin/drush --yes config:set dpl_pretix.settings pretix.api_key p1q35ojjgt7jh3wqoub00v5l0v91xf94pjn0l708zmcz40ec1i7a6eilrjhrle1i
docker compose exec phpfpm vendor/bin/drush --yes config:set dpl_pretix.settings pretix.template_event_slug dpl-cms-default-template

docker compose exec phpfpm vendor/bin/drush config:get dpl_pretix.settings
```

## pretix

``` shell
docker compose --profile pretix up --detach
open "http://pretix.dpl-cms-develop.local.itkdev.dk/control"
# https://docs.pretix.eu/en/latest/admin/installation/docker_smallscale.html#next-steps

docker compose exec --env PGPASSWORD=pretix pretix_database psql --user=pretix pretix
docker compose exec --no-TTY --env PGPASSWORD=pretix pretix_database psql --user=pretix pretix <<< "SELECT token FROM pretixbase_teamapitoken WHERE name = 'dpl-cms'"
docker compose exec --no-TTY --env PGPASSWORD=pretix pretix_database psql --user=pretix pretix --tuples-only --csv <<< "SELECT token FROM pretixbase_teamapitoken WHERE name = 'dpl-cms'"

docker compose exec phpfpm vendor/bin/drush --yes config:set dpl_pretix.settings pretix.api_key $(docker compose exec --no-TTY --env PGPASSWORD=pretix pretix_database psql --user=pretix pretix --tuples-only --csv <<< 'SELECT token FROM pretixbase_teamapitoken')

curl --header "Authorization: Token $(docker compose exec --no-TTY --env PGPASSWORD=pretix pretix_database psql --user=pretix pretix --tuples-only --csv <<< 'SELECT token FROM pretixbase_teamapitoken')" http://pretix.dpl-cms-develop.local.itkdev.dk/api/v1/organizers/


curl --header "Authorization: Token $(docker compose exec --no-TTY --env PGPASSWORD=pretix pretix_database psql --user=pretix pretix --tuples-only --csv <<< 'SELECT token FROM pretixbase_teamapitoken')" http://pretix.dpl-cms-develop.local.itkdev.dk/api/v1/organizers/dpl-cms/events/
```

## Coding standards

``` shell name=coding-standards
docker run --rm --volume "$PWD:/md" peterdavehello/markdownlint markdownlint --ignore LICENSE.md --ignore dpl-cms '**/*.md' --fix
docker run --rm --volume "$PWD:/md" peterdavehello/markdownlint markdownlint --ignore LICENSE.md --ignore dpl-cms '**/*.md'
```

## Code analysis

``` shell name=code-analysis
task dev:code-analysis
```

## Patches and other hacks

We run into […… duplicated paths in URLs, such as
/core/authorize.php/core/authorize.php](https://www.drupal.org/project/drupal/issues/2583799), so we add a band-aid in
`.docker/templates/default.conf.template`.

``` nginx
    # @see https://www.drupal.org/project/drupal/issues/2583799#comment-10464799
    rewrite ^/core/authorize.php/core/authorize.php(.*) /core/authorize.php$1 break;
```

For production, the patch in [`patches/reverse-proxy.patch`](patches/reverse-proxy.patch) must be applied (cf. [Security
check failure with reverse proxy](https://www.drupal.org/project/drupal/issues/2934570)).


## Code snippets

``` shell name=pretix-reset-all-data
task dev:drush -- sql:query "TRUNCATE dpl_pretix_events"
task dev:pretix:db-load --yes
```

``` shell name=re-synchronize-event
task dev:drush -- --yes dpl_pretix:pretix-event:delete «event id» || true

task dev:drush -- --yes dpl_pretix:event:synchronize «event id»
```

``` shell name=synchronize-event
task dev:drush -- --yes dpl_pretix:event:synchronize «event id» --verbose
```
