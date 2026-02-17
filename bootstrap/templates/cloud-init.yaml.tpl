#cloud-config
# Cuemby Cloud Marketplace — cloud-init user-data template.
#
# The UI generates this file with actual values replacing the {{ placeholders }}.
# This runs on first boot of the provisioned VM.

package_update: true
package_upgrade: true

packages:
  - curl
  - git
  - jq

write_files:
  - path: /opt/cuemby/marketplace-env.sh
    permissions: "0600"
    content: |
      #!/usr/bin/env bash
      export APP_NAME="{{ app_name }}"
      export APP_VERSION="{{ app_version }}"
      {{ #each parameters }}
      export PARAM_{{ name }}="{{ value }}"
      {{ /each }}

runcmd:
  - git clone https://github.com/cuemby/cloud-marketplace.git /opt/cuemby/marketplace
  - [bash, -c, "source /opt/cuemby/marketplace-env.sh && /opt/cuemby/marketplace/bootstrap/entrypoint.sh 2>&1 | tee /var/log/cuemby/bootstrap.log"]
