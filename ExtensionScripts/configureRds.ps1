$fqdn = $args[0]

$collectionName = $args[1]

Import-module RemoteDesktop

New-SessionDeployment -ConnectionBroker $fqdn -WebAccessServer $fqdn -SessionHost $fqdn

New-RDSessionCollection -CollectionName $collectionName -SessionHost $fqdn -CollectionDescription $collectionName -ConnectionBroker $fqdn
