$domain = $args[0]
$username = $args[1]
$password = $args[2] | ConvertTo-SecureString -asPlainText -Force
$cred = $args[0].split(".")[0]+"\"+$username
$credential = New-Object System.Management.Automation.PSCredential($cred,$password)
Add-Computer -DomainName $domain -Credential $credential -Verbose -Force -Restart 
