#!/bin/bash
set -euxo pipefail

# Ex: 21.0.0
VERSION=$1
# Ex: 20.0.0
# Ex: NONE [if no replaces]
REPLACES_VERSION=$2
# Ex: keycloak/keycloak-operator:25.0.0-SNAPSHOT
OPERATOR_DOCKER_IMAGE=$3

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

{ set +x; } 2>/dev/null
echo ""
echo "Creating OLM bundle for version $VERSION replacing version $REPLACES_VERSION"
echo ""
set -x

cd "$SCRIPT_DIR"

rm -rf ../olm/$VERSION
mkdir -p ../olm/$VERSION

# Extract the files generated by Quarkus during the maven build
unzip -q -d ../olm/$VERSION ../target/keycloak-operator-*-olm.zip

# Find the CSV YAML
CSV_PATH="$(find "../olm/$VERSION" -type f -name '*.clusterserviceversion.yaml')"

# Insert operator image coordinate
yq ea -i ".metadata.annotations.containerImage = \"$OPERATOR_DOCKER_IMAGE:$VERSION\"" "$CSV_PATH"
yq ea -i ".spec.install.spec.deployments[0].spec.template.spec.containers[0].image = \"$OPERATOR_DOCKER_IMAGE:$VERSION\"" "$CSV_PATH"

# Edit the CSV version, replaces, etc.

yq ea -i ".metadata.annotations.createdAt = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" "$CSV_PATH"
yq ea -i ".spec.version = \"$VERSION\"" "$CSV_PATH"
yq ea -i ".metadata.name = \"keycloak-operator.v$VERSION\"" "$CSV_PATH"
yq ea -i '.metadata.namespace = "placeholder"' "$CSV_PATH"

if [[ $REPLACES_VERSION = "NONE" ]]
then
  yq ea -i "del(.spec.replaces)" "$CSV_PATH"
else
  yq ea -i ".spec.replaces = \"keycloak-operator.v$REPLACES_VERSION\"" "$CSV_PATH"
fi

# Mangle the YAML to make it look more like it did before. The bundle extension
# isn't configurable enough to do this itself. No one seems to have the
# expertise to say if the changes it makes are ok or not.
yq ea -i "del(.spec.install.spec.deployments[0].spec.selector.matchLabels)" "$CSV_PATH"
yq ea -i "del(.spec.install.spec.deployments[0].spec.template.metadata.labels)" "$CSV_PATH"
yq ea -i "del(.spec.install.spec.deployments[0].spec.template.metadata.annotations)" "$CSV_PATH"
yq ea -i "del(.spec.install.spec.deployments[0].spec.template.metadata.namespace)" "$CSV_PATH"
yq ea -i "del(.spec.install.spec.deployments[0].spec.template.namespace)" "$CSV_PATH"
yq ea -i "del(.spec.install.spec.deployments[0].spec.template.spec.containers[0].ports)" "$CSV_PATH"
yq ea -i "del(.spec.install.spec.deployments[0].spec.template.spec.containers[0].livenessProbe)" "$CSV_PATH"
yq ea -i "del(.spec.install.spec.deployments[0].spec.template.spec.containers[0].readinessProbe)" "$CSV_PATH"
yq ea -i "del(.spec.install.spec.deployments[0].spec.template.spec.containers[0].startupProbe)" "$CSV_PATH"
yq ea -i 'del(.spec.install.spec.deployments[0].spec.template.spec.containers[0].env[] | select(.name == "KUBERNETES_NAMESPACE"))' "$CSV_PATH"

yq ea -i '.spec.install.spec.deployments[0].spec.template.spec.containers[0].resources = {}' "$CSV_PATH"
yq ea -i '.spec.install.spec.deployments[0].spec.strategy = {}' "$CSV_PATH"
yq ea -i '.spec.apiservicedefinitions = {}' "$CSV_PATH"

yq ea -i '.spec.install.spec.deployments[0].spec.selector.matchLabels.name = "keycloak-operator"' "$CSV_PATH"
yq ea -i '.spec.install.spec.deployments[0].spec.template.metadata.labels.name = "keycloak-operator"' "$CSV_PATH"

yq ea -i '.spec.install.spec.deployments[0].spec.template.spec.containers[0].env += [{"name": "POD_NAME", "valueFrom": {"fieldRef": {"fieldPath": "metadata.name"}}}]' "$CSV_PATH"
yq ea -i '.spec.install.spec.deployments[0].spec.template.spec.containers[0].env += [{"name": "OPERATOR_NAME", "value": "keycloak-operator"}]' "$CSV_PATH"

{ set +x; } 2>/dev/null
echo ""
echo "Created OLM bundle ok!"