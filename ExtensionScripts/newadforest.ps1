$domainName = $args[0]

$password = $args[1]

Set-DnsClient `
    -InterfaceAlias "Ethernet*" `
    -ConnectionSpecificSuffix $domainName
    
Install-WindowsFeature `
    -Name AD-Domain-Services `
    -IncludeManagementTools

$securePassword = ConvertTo-SecureString $password `
    -AsPlainText `
    -Force

Install-ADDSForest `
    -DomainName $domainName `
    -SafeModeAdministratorPassword $securePassword `
    -Force