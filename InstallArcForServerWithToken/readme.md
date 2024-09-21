---
description: This template creates an Azure VM and install Arc agent for testing purposes.
page_type: sample
products:
- azure
- azure-resource-manager
---
# Create Arc for Server resource in Azure environment for testing

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.appconfiguration%2Fapp-configuration-store-ff%2Fazuredeploy.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.appconfiguration%2Fapp-configuration-store-ff%2Fazuredeploy.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fazure-quickstart-templates%2Fmaster%2Fquickstarts%2Fmicrosoft.appconfiguration%2Fapp-configuration-store-ff%2Fazuredeploy.json)

This template creates an Azure App Configuration store, then creates a feature flag inside the new store.

Feature flag belongs to `keyValues` resource type. To be a feature flag, the key of `keyValues` resource requires prefix `.appconfig.featureflag/`. However, `/` is forbidden in resource's name. `~2F` is used to espace the forward slash character. For more information about the `keyValues` resrouce's name, refer to the `Tip` section of [this tutorial](https://docs.microsoft.com/azure/azure-app-configuration/quickstart-resource-manager).

If you're new to App Configuration, see:

- [Azure App Configuration](https://azure.microsoft.com/services/app-configuration/)
- [Azure App Configuration documentation](https://docs.microsoft.com/azure/azure-app-configuration/)
- [Template reference](https://docs.microsoft.com/azure/templates/microsoft.appconfiguration/allversions)

If you're new to template deployment, see:

- [Azure Resource Manager documentation](https://docs.microsoft.com/azure/azure-resource-manager/)
- [Quickstart: Create an Azure App Configuration store by using an ARM template](https://docs.microsoft.com/azure/azure-app-configuration/quickstart-resource-manager)

`Tags: Azure4Student, AppConfiguration, Beginner, Microsoft.AppConfiguration/configurationStores, Microsoft.AppConfiguration/configurationStores/keyValues`