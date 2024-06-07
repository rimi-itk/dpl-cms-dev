FROM itkdev/php8.1-fpm:latest

# Set bash as default shell
# Make `sh` point to `bash` (rather than `dash` which is the default in Ubuntu) to resolve
# `sh: 1: [[: not found` error due to `"post-drupal-scaffold-cmd"` in composer.json.
USER root
RUN rm /bin/sh && ln -s bash /bin/sh
USER deploy
