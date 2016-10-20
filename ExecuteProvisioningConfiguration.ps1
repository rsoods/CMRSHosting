# I have removed 2 Ips from the SubnetAddressSPaceList and also have removed 2 names from subnet name list.

$ScriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
Import-Module -name  "$ScriptDir\PSModules\CMRSTemplateModules.ps1" -Force
Import-Module -name  "$ScriptDir\PSModules\LoggingModule.ps1" -Force 

$cmrsTemplateModule.SetLoggingVariable("D:\logs")

#Specify the path of the excel file
$FilePath = "$ScriptDir\EnvironmentConfig.xlsx"

#Specify the Sheet name
$SheetName = "EnvironmentParameters"

# Create an Object Excel.Application using Com interface
$objExcel = New-Object -ComObject Excel.Application
# Disable the 'visible' property so the document won't open in excel
$objExcel.Visible = $false
# Open the Excel file and save it in $WorkBook
$WorkBook = $objExcel.Workbooks.Open($FilePath)
# Load the WorkSheet 'BuildSpecs'
$WorkSheet = $WorkBook.sheets.item($SheetName)
$rowMax = ($WorkSheet.UsedRange.Rows).count 
$GlobalLogModule.LogInfo("Opening and Reading the Excel config File")
#Declaring the Variable from the Excel Config files. Column B is the key and Column D is the Value

#------------ Start of EnvironmentParameters Sheet -------------------
$boolCheckVariable="true"
$VariableArray=@("SubscriptionId","ResourceGroupName","LocationName","VnetName","VnetAddressSpaceList","SubnetNameList","SubnetAddressSpaceList","AvailabilitySetNameList","DomainName","LocalAdminName","LocalAdminPassword")
#Initializing all Variables with Null values
foreach ($var in $VariableArray){
	New-Variable -Name $var -Value $null
}
$ColWiseHeadingList="SubnetNameList","SubnetAddressSpaceList","AvailabilitySetNameList"

#Reading and setting the variables from config file
for ($i = 2; $i -le $rowMax -And $boolCheckVariable -eq "true"; $i++) {
	if ($VariableArray -contains $WorkSheet.Range("B$i").Text -eq "true") {
		foreach($colvar in $ColWiseHeadingList){
			if($WorkSheet.Range("B$i").Text -eq $colvar){
				$startColumn=4
				$str=""
				while($WorkSheet.Cells.Item($i, $startColumn).Value() -ne $null){
					$str += $WorkSheet.Cells.Item($i, $startColumn).Value()+";"
					$startColumn++
				}
				Set-Variable -Name $colvar -Value $str.Substring(0,$str.Length-1)
			}
		}
		
		if ($ColWiseHeadingList -notcontains $WorkSheet.Range("B$i").Text){
			Set-Variable -Name $WorkSheet.Range("B$i").Text -Value $WorkSheet.Range("D$i").Text
		}
	}
	else{
		$boolCheckVariable="false"
	}
}
#Validating if any variable is not defined or NULL
foreach ($var in $VariableArray){
	try{
		if((Get-Variable -Name $var -Value) -eq $null -OR (Get-Variable -Name $var -Value) -eq ""){
				$boolCheckVariable="false"
			}
		}
		catch {
			$boolCheckVariable="false"
		}
}

if ($boolCheckVariable -eq "false"){
	$GlobalLogModule.logError("File Format is not correct, please use correct Template")
}

#------------ End of EnvironmentParameters Sheet -------------------

$WorkBook.Close()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($WorkBook) > $null
$objExcel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($objExcel) > $null
Remove-Variable objExcel
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()


###

$Global:GlobalRecordDetails = @{}
function  ReadColWiseExcel {
	[cmdletbinding()]
	Param (
	[string[]]$headingList,
	[string]$SheetName,
	[int]$rowstart,
	[int]$colstart
	   )
   
	#Specify the path of the excel file
	###$FilePath = "$ScriptDir\config1.xlsx"
	#Specify the Sheet name	
	# Create an Object Excel.Application using Com interface
	$objExcel = New-Object -ComObject Excel.Application
	# Disable the 'visible' property so the document won't open in excel
	$objExcel.Visible = $false
	# Open the Excel file and save it in $WorkBook
	$WorkBook = $objExcel.Workbooks.Open($FilePath)
	# Load the WorkSheet 'BuildSpecs'
	$WorkSheet = $WorkBook.sheets.item($SheetName)
	$rowMax = ($WorkSheet.UsedRange.Rows).count

	$htHeadingList = @{}
	#Declaring Empty ArrayList in HashTable
	Foreach ($ht in $headingList){$htHeadingList[$ht] =  New-Object Collections.Arraylist }
	$inputcounter = 0

	$rowname = "rowName"
	$colname = "colName"
	
	#Dynamically initializing Row,Column
	foreach($cnt in $headingList) {
		New-Variable -Name ${cnt}${rowname} -Value $rowstart -Force
		New-Variable -Name ${cnt}${colname} -Value $colstart -Force
		$colstart++
	}
	
	for ($i=2; $i -le $rowMax-1; $i++)
	{	
		#Reading and inserting the column values in the Hashtable's ArrayList
		foreach($cnt in $headingList) {
			$row = Get-Variable ${cnt}${rowname} -ValueOnly
			$col = Get-Variable ${cnt}${colname} -ValueOnly
			$htHeadingList[$cnt].Add($WorkSheet.Cells.Item($row+$inputcounter,$col).text) > $null
		}
		$inputcounter++ 
	}
	$WorkBook.Close()
	[System.Runtime.Interopservices.Marshal]::ReleaseComObject($WorkBook) > $null
	$objExcel.Quit()
	[System.Runtime.Interopservices.Marshal]::ReleaseComObject($objExcel) > $null
	Remove-Variable objExcel
	[System.GC]::Collect()
	[System.GC]::WaitForPendingFinalizers()

	#Assigning values into Global Variable
	$Global:GlobalRecordDetails[$SheetName] = $htHeadingList
}

$StorageAccountheadingList = "StorageAccountName","StorageType"
$InternalLoadBalancerheadingList = "LoadbalancerName","LoadBalancerSubnetDestination","LoadbalancerIPAddress","LoadbalancerWithNAT","NATRuleList","LoadbalancerBackendPoolName","LoadBalancingRules","LoadBalancerProbes","LoadBalancingRulesandProbeMapping"
$ExternalLoadBalancerheadingList = "LoadbalancerName","LoadBalancerSubnetDestination","LoadBalancerPublicDNSName","LoadbalancerBackendPoolName","LoadBalancingRules","LoadBalancerProbes","LoadBalancingRulesandProbeMapping"
$VMheadingList = "VMName","VMSize","SubnetName","InternalIPAddress","RequirePublicIP","RequireStaticPublicIP","AvailabilitySetName","OSStorageName","HddDataDiskStorageName","SddDataDiskStorageName","HDDetails","SDDetails","DNSIPAddresses","NameOfLoadBalancerToBeAddedInto","LoadBalancerNATRuleNameToAddTo","LoadBalancerBackendPoolToAddTo","VMImagePublisherName","VMImageOfferName","VMImageSKUName","NSGName"
$NACLheadingList = "ACLRuleName","ACLRulePriorityNumber","ACLRuleAction","ACLProtocol","ACLSourceAddress","ACLSourcePort","ACLDestinationAddress","ACLDestinationPort","ACLDirection"
$NSGheadingList = "NSGName","NSGACLs"

$ADGroupNameList = "ADGroupName"
$UserServiceAccountList = "UserName","FirstName","SurName","Password"
$UserADGroupList = "UserName","ADGroup"


$rowstart,$colstart = 3,2

$SheetNameAndHeadingArray = @{"StorageAccount"=$StorageAccountheadingList;"InternalLoadBalancer"=$InternalLoadBalancerheadingList;"ExternalLoadBalancer"=$ExternalLoadBalancerheadingList;"VM"=$VMheadingList;"NetworkACLs"=$NACLheadingList;"NetworkSecurityGroups"=$NSGheadingList;"ADGroup"=$ADGroupNameList;"UserServiceAccount"=$UserServiceAccountList;"UserAdGroup"=$UserADGroupList}

foreach($key in $SheetNameAndHeadingArray.keys){
	$Value = $SheetNameAndHeadingArray[$key]
	ReadColWiseExcel -headingList  $Value -SheetName $key -rowstart $rowstart -colstart $colstart
}

$GlobalLogModule.LogInfo("Reading from the config file is complete")

$dnsAddressSplittedArray = $dnsAddressArray -split ";"
$dnsAddressArray = New-Object Collections.Arraylist 

foreach ($dnsNameElement in $dnsAddressSplittedArray) {
	$dnsAddressArray.add($dnsNameElement) > $null
}

#Create VNET using template method
##########$cmrsTemplateModule.CreateVNetWithSubnet($vnetName, $vnetAddressSpaceList, $subnetNameList, $subnetAddressSpaceList, $dnsAddressArray, $ResourceGroupName, $LocationName)

$NetworkSecurityGroupsCounter=0
foreach ($nsgname in $GlobalRecordDetails["NetworkSecurityGroups"]["NSGName"]){

	##########$cmrsTemplateModule.CreateNetworkSecurityGroups($nsgName ,  $GlobalRecordDetails["NetworkSecurityGroups"]["NSGACLs"][$NetworkSecurityGroupsCounter].split(';'),$LocationName,$ResourceGroupName)
	$NetworkSecurityGroupsCounter++
}

$storagecounter = 0
foreach ($storageName in $GlobalRecordDetails["StorageAccount"]["StorageAccountName"]){
	$storageType = $GlobalRecordDetails["StorageAccount"]["StorageType"][$storagecounter]
	##########$cmrsTemplateModule.CreateStorageAccount("$storageName", "$storageType", $ResourceGroupName, $LocationName)
	$storagecounter++
}

#Create Availability Sets
##########$cmrsTemplateModule.CreateAvailabilitySets($availabilitySetNameList, $ResourceGroupName, $LocationName)
#Create Internal LB for NATing rules

$IntLoadBalancerCnt = 0
foreach ($NatConfig in $GlobalRecordDetails["InternalLoadBalancer"]["LoadbalancerWithNAT"]){
	$loadBalancerName = $GlobalRecordDetails["InternalLoadBalancer"]["LoadbalancerName"][$IntLoadBalancerCnt]
	$loadBalancerIPAddress  = $GlobalRecordDetails["InternalLoadBalancer"]["LoadbalancerIPAddress"][$IntLoadBalancerCnt]
	$natRuleList  = $GlobalRecordDetails["InternalLoadBalancer"]["NATRuleList"][$IntLoadBalancerCnt]
	$destSubnetNameforLB  = $GlobalRecordDetails["InternalLoadBalancer"]["LoadBalancerSubnetDestination"][$IntLoadBalancerCnt]

	$LoadBalancingRules  = $GlobalRecordDetails["InternalLoadBalancer"]["LoadBalancingRules"][$IntLoadBalancerCnt]
	$LoadBalancerProbes  = $GlobalRecordDetails["InternalLoadBalancer"]["LoadBalancerProbes"][$IntLoadBalancerCnt]
	$LoadBalancingRulesandProbeMapping  = $GlobalRecordDetails["InternalLoadBalancer"]["LoadBalancingRulesandProbeMapping"][$IntLoadBalancerCnt]
	$LoadbalancerBackendPoolName  = $GlobalRecordDetails["InternalLoadBalancer"]["LoadbalancerBackendPoolName"][$IntLoadBalancerCnt]
	if ($NatConfig -eq "Y"){
		#Create Internal LB for NATing rules
	 	##########$cmrsTemplateModule.CreateInternalLoadBalancerWithNAT($loadBalancerName, $loadBalancerIPAddress, $natRuleList, $ResourceGroupName, $LocationName, $vnetName, $destSubnetNameforLB)
	}
	else {
		#Create Internal LB for BackendPool
		##########$cmrsTemplateModule.CreateInternalLoadBalancerWithBackendPool($loadBalancerName, $loadBalancerIPAddress, $LoadBalancingRules, $LoadBalancerProbes,$LoadBalancingRulesandProbeMapping, $LoadbalancerBackendPoolName, $ResourceGroupName, $LocationName, $vnetName, $destSubnetNameforLB)
	}
$IntLoadBalancerCnt++		
}

$ExtLoadBalancerCnt = 0
foreach ($NatConfig in $GlobalRecordDetails["ExternalLoadBalancer"]["LoadbalancerName"]){
	##########$cmrsTemplateModule.CreateInternetFacingLoadBalancerWithBackendPool($GlobalRecordDetails["ExternalLoadBalancer"]["LoadbalancerName"][$ExtLoadBalancerCnt], $GlobalRecordDetails["ExternalLoadBalancer"]["LoadBalancerPublicDNSName"][$ExtLoadBalancerCnt], $GlobalRecordDetails["ExternalLoadBalancer"]["LoadBalancingRules"][$ExtLoadBalancerCnt], $GlobalRecordDetails["ExternalLoadBalancer"]["LoadBalancerProbes"][$ExtLoadBalancerCnt],$GlobalRecordDetails["ExternalLoadBalancer"]["LoadBalancingRulesandProbeMapping"][$ExtLoadBalancerCnt], $GlobalRecordDetails["ExternalLoadBalancer"]["LoadbalancerBackendPoolName"][$ExtLoadBalancerCnt], $ResourceGroupName, $LocationName, $vnetName, $GlobalRecordDetails["ExternalLoadBalancer"]["LoadBalancerSubnetDestination"][$ExtLoadBalancerCnt])
	$ExtLoadBalancerCnt++
}

$ADGroupString = ""
foreach ($ADGroupName in $GlobalRecordDetails["ADGroup"]["ADGroupName"]){
	if($ADGroupString -eq ""){
		$ADGroupString = $ADGroupName
	}
	else{
		$ADGroupString = $ADGroupString+"~"+$ADGroupName
	}
}

$UserString = ""
$ucnt = 0
foreach ($UserName in $GlobalRecordDetails["UserServiceAccount"]["UserName"]){
	$compString = $UserName+"~"+$GlobalRecordDetails["UserServiceAccount"]["FirstName"][$ucnt]+"~"+$GlobalRecordDetails["UserServiceAccount"]["SurName"][$ucnt]+"~"+$GlobalRecordDetails["UserServiceAccount"]["Password"][$ucnt]
	if($UserString -eq ""){
		$UserString = $compString
	}
	else{
		$UserString = $UserString +"," + $compString
	}
	$ucnt++
}

$UserADGroupString = ""
$ucnt = 0
foreach ($UserName in $GlobalRecordDetails["UserAdGroup"]["UserName"]){
	$compString = $UserName+"~`""+$GlobalRecordDetails["UserAdGroup"]["ADGroup"][$ucnt]+"`""
	if($UserADGroupString -eq ""){
		$UserADGroupString = $compString
	}
	else{
		$UserADGroupString = $UserADGroupString +"," + $compString
	}
	$ucnt++
}
				
$vmCounter = 0
foreach ($vmName in $GlobalRecordDetails["VM"]["VMName"]){
#	$vmName
	$vmSize = $GlobalRecordDetails["VM"]["VMSize"][$vmCounter]
	$subnetName = $GlobalRecordDetails["VM"]["SubnetName"][$vmCounter]
	$availabilitysetName = $GlobalRecordDetails["VM"]["AvailabilitySetName"][$vmCounter]
	if ($availabilitysetName -eq ""){
		$availabilitysetName = $null
	}
	$OSStorageName = $GlobalRecordDetails["VM"]["OSStorageName"][$vmCounter]
	$dataDiskList = $GlobalRecordDetails["VM"]["HDDetails"][$vmCounter]
	$privateIPAddress = $GlobalRecordDetails["VM"]["InternalIPAddress"][$vmCounter]
	$requirePublicIPAddress = $GlobalRecordDetails["VM"]["RequirePublicIP"][$vmCounter]
	if($requirePublicIPAddress -eq "Y"){
		$requirePublicIPAddress ="true"
	}
	
	<#$localAdminCredentials = $GlobalRecordDetails["VM"]["LocalAdminCredentials"][$vmCounter] -split ";"
	$localUsername = $localAdminCredentials[0]
	$localUserPassword = $localAdminCredentials[1]
	#>

	$trgtDNSArray = $GlobalRecordDetails["VM"]["DNSIPAddresses"][$vmCounter] -split ";"
	$trgtVMLoadbalancerName = $GlobalRecordDetails["VM"]["NameOfLoadBalancerToBeAddedInto"][$vmCounter]
	$trgtVMNATRuleNameList = $GlobalRecordDetails["VM"]["LoadBalancerNATRuleNameToAddTo"][$vmCounter]
	$trgtVMBackendPoolName = $GlobalRecordDetails["VM"]["LoadBalancerBackendPoolToAddTo"][$vmCounter]

	$ssdDataDiskStorageName = $GlobalRecordDetails["VM"]["SddDataDiskStorageName"][$vmCounter]
	$hddDataDiskStorageName = $GlobalRecordDetails["VM"]["HddDataDiskStorageName"][$vmCounter]
	$ssdDataDiskList = $GlobalRecordDetails["VM"]["SDDetails"][$vmCounter]
	$hddDataDiskList = $GlobalRecordDetails["VM"]["HDDetails"][$vmCounter]
	$vmPublisherName = $GlobalRecordDetails["VM"]["VMImagePublisherName"][$vmCounter]
	$vmPublisherOfferName = $GlobalRecordDetails["VM"]["VMImageOfferName"][$vmCounter]
	$vmOfferSku = $GlobalRecordDetails["VM"]["VMImageSKUName"][$vmCounter]
	$NSGName =  $GlobalRecordDetails["VM"]["NSGName"][$vmCounter]
	

	$cmrsTemplateModule.CreateVM($vmName, $vmSize, $DomainName,$vnetName, $subnetName, $availabilitysetName, $ResourceGroupName, $LocationName, $OSStorageName, $ssdDataDiskStorageName, $hddDataDiskStorageName, $ssdDataDiskList, $hddDataDiskList, $privateIPAddress, $requirePublicIPAddress, $LocalAdminName, $LocalAdminPassword, $trgtDNSArray, $trgtVMLoadbalancerName, $trgtVMNATRuleNameList, $trgtVMBackendPoolName, $vmPublisherName, $vmPublisherOfferName, $vmOfferSku, $NSGName,$ADGroupString,$UserString,$UserADGroupString)
	$vmCounter++
}

##$cmrsTemplateModule.TestingFunction()