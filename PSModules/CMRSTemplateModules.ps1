$ScriptDir = Split-Path -parent $MyInvocation.MyCommand.Path
Import-Module -name  "$ScriptDir\LoggingModule.ps1" -Force 


#Logging Variables
#$logLoc	= "D:\Logs"
$Global:GlobalLogModule = $LogModule

$cmrsTemplateModule = new-module -ascustomobject{

	function SetLoggingVariable($logLoc){
		$logFileName ="CMRSlogs"+$(get-date -Format yyyymmdd_hhmmss)+".log"
		$GlobalLogModule.SetlogPath($logLoc)
		$GlobalLogModule.SetlogFile($logFileName)
	}

	function CreateResourceGroup($ResourceGroupName,$location){
		try{
			Get-AzureRmResourceGroup -Name $ResourceGroupName -Verbose -ErrorAction Stop
			$GlobalLogModule.LogInfo("Cannot create new Resource Group, resource Group $ResourceGroupName already exists")
			return
			}
		catch{
			New-AzureRmResourceGroup -Name $ResourceGroupName -Location $location -Verbose -ErrorAction Stop
			$GlobalLogModule.LogInfo("Resource Group $ResourceGroupName successfully created ")
		}
	}

	#TESTED
	function CreateVNetWithSubnet($vnetName, $vnetAddressSpaceList, $subnetNameList, $subnetAddressSpaceList, $dnsAddressArray, $rgName, $location) { 
	<#
		Creation of VNET with Subnet Consists of 3 Steps :
		1. Creating/Retrieving Resource Group Name
		2. Creating/Retrieving Subnet Object
		3. Creation/Retrieving and then adding the Subnet Object to the Virtual Network Object
	#>	
	#Start of Creating/Retrieving Resource Group Name
	try {  
			$GlobalLogModule.LogInfo("Starting Vnet with Subnet Location : $location , Name :$rgName -")
			$rgObject = Get-AzureRmResourceGroup -Location $location -Name $rgName -Verbose -ErrorAction Stop
			$GlobalLogModule.LogInfo("Verifying if the ResourceGroupName exists or not ?")
			$GlobalLogModule.LogInfo("Successfully retrieved AzureRM ResourceGroup name " + $rgName + " With Location " + $location)
	} 
	catch
	{ 
			$GlobalLogModule.LogInfo("resource group not present, creating resource group")
			try {
				$GlobalLogModule.LogInfo("Creating new Resource with Name "+ $rgName + "Location "+$location )
				$rgObject = New-AzureRmResourceGroup -Name $rgName -Location $location -Verbose -ErrorAction Stop	
				$GlobalLogModule.LogInfo("Creating new Resource group $rgName is successful")
			} 
			catch
			{
				$GlobalLogModule.LogError("Unable to create destination resource group $rgName. Cannot continue further")
			}
	}
	#End of Creating/Retrieving Resource Group Name
	#Start of Step 2: Creating/Retrieving Subnet Object
	$subnetAddressSpaceArray = $subnetAddressSpaceList -split ";"
	$subnetNamesArray = $subnetNameList -split ";"
	$subnetAddressSpaceCounter=0
	$newSubnetArray = New-Object System.Collections.ArrayList
	$GlobalLogModule.LogInfo("Creating New Virtual Network with Subnet")
	foreach ($subnetNameElement in $subnetNamesArray) 
	{
		try{
			#if the VNET exists, then we Add the subnet config to the existing Vnet. Creating Subnet Object
			$subnetNode = New-AzureRmVirtualNetworkSubnetConfig -Name $subnetNameElement -AddressPrefix $subnetAddressSpaceArray[$subnetAddressSpaceCounter] -Verbose
			$GlobalLogModule.LogInfo("Adding Address prefix " + $subnetAddressSpaceArray[$subnetAddressSpaceCounter] + " into Existing VNet")
			$GlobalLogModule.LogInfo("Adding SubnetNode =" + $subnetNameElement + " in newSubnetArray ")
			New-Variable -Name "Subnet$subnetCounter" -Value $subnetNode
			$newSubnetArray.add($subnetNode)

			$executeVnetConfig = 1
		}
		catch{
			$GlobalLogModule.LogError("Unable to create Subnet. Cannot continue further.")
		}
		$subnetAddressSpaceCounter++
	}
	#End of Step 2: Creating/Retrieving Subnet Object

	#Start of Step 3. Creation/Retrieving and then adding the Subnet Object to the Virtual Network Object
	if($executeVnetConfig -eq 1)
	{
		$GlobalLogModule.LogInfo("Creating/Updating Network...")
		#if the specified VNet exist then can't be created again, so get the context only
		$vnetAddressSpaceArray = $vnetAddressSpaceList -split ";"
		try{
				$GlobalLogModule.LogInfo("Creating the the VirtualNetwork  "+ $vnetName + " ResourceGroupName : $rgName,  Name: $vnetName, AddressPrefix :  $vnetAddressSpaceArray , Location:$location , Subnet:$newSubnetArray")
				#Creating VNET Object Context 
				######			$vnetObject = New-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name $vnetName -AddressPrefix $vnetAddressSpaceArray -Location $location -Subnet $newSubnetArray -DnsServer $dnsAddressArray -Verbose -ErrorAction Stop
				$vnetObject = New-AzureRmVirtualNetwork -ResourceGroupName $rgName -Name $vnetName -AddressPrefix $vnetAddressSpaceArray -Location $location -Subnet $newSubnetArray -Verbose -ErrorAction Stop
		}
		catch
		{
			$GlobalLogModule.LogError($_.Exception.Message)
			$GlobalLogModule.LogInfo("VNET $vnetName not present, setting VNET config")
			try
			{	
				$GlobalLogModule.LogInfo("Starting provisioning the network after reading the VNET and subnet config... Name:$vnetName, ResourceGroupName :$rgName")
				#After the VNET and Subnet config have been read and verified, now we provision the network
				#Getting VNET Object Context 
				$vnetObject = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $rgName -Verbose -ErrorAction Stop
				Set-AzureRmVirtualNetwork -VirtualNetwork $vnetObject -Verbose
			}
			catch{
				$GlobalLogModule.LogError($_.Exception.Message)
				$GlobalLogModule.LogError("Unable to create VNET $vnetName. Cannot continue further.")
				return
			}
		}
		#End of Step 3. Creation/Retrieving and then adding the Subnet Object to the Virtual Network Object
	}
	else
	{
		$GlobalLogModule.LogInfo("VNET / Subnet are up-to-date...")
	}
	$GlobalLogModule.LogInfo(" .... Vnet Provisioning Process Completed")
    }
	
	#TESTED
	function CreateAvailabilitySets($availabilitySetNameList,$rgName,$location){
	try {  
		$GlobalLogModule.LogInfo("Getting ResourceGroup from location " + $location + " with Name " + $rgName )
		$rgObject = Get-AzureRmResourceGroup -Location $location -Name $rgName -Verbose -ErrorAction Stop
	} 
	catch
	{ 
		$GlobalLogModule.LogError($_.Exception.Message)
		$GlobalLogModule.LogError("resource group not present on location " + $location + " with Name " + $rgName + ", cannot continue further")
		return
	}
	#flow for checking and creating Availability set(s) 
	$availabilitySetArray = $availabilitySetNameList -split ";"
	foreach ($availabilitysetName in $availabilitySetArray) 
	{
		try
		{
			#Get object to Availability Set
			$GlobalLogModule.LogInfo("Getting Object to Availability set $availabilitysetName")
			$availabilityset = Get-AzureRmAvailabilitySet -ResourceGroupName $rgName -Name $availabilitysetName -Verbose -ErrorAction Stop
		}
		catch{
			$GlobalLogModule.LogInfo("Availability Set $availabilitysetName not present, creating it..")
			try
			{
				$GlobalLogModule.LogInfo("Creating new Availability Set $availabilitysetName")
				New-AzureRmAvailabilitySet -Location $location -Name $availabilitysetName -ResourceGroupName $rgName -Verbose -ErrorAction Stop 
			}
			catch{
				$GlobalLogModule.LogError($_.Exception.Message)
				$GlobalLogModule.LogError("Availability Set cannot be created..")
			}
		}
	}
	$GlobalLogModule.LogInfo(" .... Availability Set Provisioning Process Completed")
	}

    function CreateStorageAccount($storageAccountName, $storageType, $rgName, $location)
	{
		<#
			$storageType can be of the following types ONLY
			1. Standard_LRS
			2. Standard_ZRS
			3. Standard_GRS
			4. Standard_RAGRS
			5. Premium_LRS
		#>
		try
		{
			$GlobalLogModule.LogInfo("Getting Storage Account Info... Name = "+$storageAccountName + " ResourceGroupName " + $rgName)
			$stgObject = Get-AzureRmStorageAccount -Name $storageAccountName -ResourceGroupName $rgName -Verbose -ErrorAction Stop
			$GlobalLogModule.LogError("Storage Account already taken..." + $storageAccountName )
		}
		catch{
			try{
				$GlobalLogModule.LogInfo("Creating storage account..." + $storageAccountName )
				New-AzureRmStorageAccount -Location $location -Name $storageAccountName -ResourceGroupName $rgName -SkuName $storageType -Verbose -ErrorAction Stop
				$storageKeys = GetStorageAccountKey $storageAccountName $rgName
				$GlobalLogModule.LogInfo("Storage Key " +  $storageKeys[0].Value )
				$storageContext = New-AzureStorageContext -StorageAccountKey $storageKeys[0].Value -StorageAccountName $storageAccountName -Verbose -ErrorAction Stop
				$GlobalLogModule.LogInfo("Creating vhds container...")
				New-AzureStorageContainer -Name vhds -Context $storageContext -Verbose -ErrorAction Stop
			}
			catch{
				$ErrorMessage = $_.Exception.Message
				$FailedItem = $_.Exception.ItemName
				$GlobalLogModule.LogError($ErrorMessage)
				$GlobalLogModule.LogError($FailedItem)
				$GlobalLogModule.LogError("Unable to create storage account $storageAccountName . Cannot continue further")
				return
			}
		}
	}
	
	function GetStorageNameFromUri($storageUri)
	{
		$nameArray = $storageUri.Split("/")
		foreach($name in $nameArray)
		{
			if($name.Contains(".blob.core.windows.net"))
			{
				$storageName = $name.Split(".")[0]
			}
		}
		return $storageName
	}

    function GetStorageAccountKey($storageName, $rgName)
    {
        try{
			$GlobalLogModule.LogInfo("Getting Storage Account Details... Storage name : $storageName , ResourceGroupName : $rgName")
            $storageObject = Get-AzureRmStorageAccountKey -Name $storageName -ResourceGroupName $rgName -ErrorAction Stop
            return $storageObject
        }
        catch{
            $ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			$GlobalLogModule.LogError("Invalid storage account $storageName. Cannot continue further")
			return $null
        }
    }

	#TESTED
	function CreateInternalLoadBalancerWithNAT($loadBalancerName, $loadBalancerIPAddress, $natRuleList, $rgName, $location, $vnetName, $subnetName)
	{
		try{
			$GlobalLogModule.LogInfo("Getting VNET info ... Name : $vnetName")
			$vnetObject = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $rgName -ErrorAction Stop
		}
		catch{
			$GlobalLogModule.LogError($_.Exception.Message)
			$GlobalLogModule.LogError($vnetName + " VNET not present.. Resource Group name  = " +$rgName+ ", cannot continue further")
			return
		}
		try{
			$GlobalLogModule.LogInfo("Getting VM Subnet Config ")
			$frontEndSubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnetObject -Name $subnetName -ErrorAction Stop
		}
		catch{
			$GlobalLogModule.LogError($_.Exception.Message)
			$GlobalLogModule.LogError($subnetName + " Subnet not present, cannot continue further")
			return
		}
		
		#natRuleList is a list of NAT rules which need to be created, the structure of the array should be of the following format
		<#
			natRuleName~frontEndport,backEndport;natRuleName~frontEndport,backEndport
			Splitting flow:
			1. First on ";"
			2. then "~" and ","
		#>
		$tempNumber = get-random -maximum 1000
		$GlobalLogModule.LogInfo("Front end Config Name " + "LB-Frontend-" + $loadBalancerName + $tempNumber)
		$frontEndConfigName = "LB-Frontend-" + $loadBalancerName + $tempNumber
		
		$requiredNatRuleArray = $natRuleList -split ";"
		
		$natRuleNameArray = New-Object System.Collections.ArrayList
		$natRuleFrontendPortArray = New-Object System.Collections.ArrayList
		$natRuleBackendPortArray = New-Object System.Collections.ArrayList
		
		foreach($natRuleConfigGiven in $requiredNatRuleArray)
		{
			$tempArray = $natRuleConfigGiven -split "~"
			#$tempArray[0] -> this is rule Name
			$tempArray2 = $tempArray[1] -split ","
			#$tempArray2[0] -> this is frontEndport
			#$tempArray2[1] -> this is backEndport
			$natRuleNameArray.Add($tempArray[0]) > $null
			$natRuleFrontendPortArray.Add($tempArray2[0]) > $null
			$natRuleBackendPortArray.Add($tempArray2[1]) > $null
		}
		#Create LoadBalancer config name
		$configName = $frontEndConfigName + $loadBalancerName
		$GlobalLogModule.LogInfo("Config Name  = " + $configName)
		$GlobalLogModule.LogInfo("Create a front end IP pool using the private IP address $loadBalancerIPAddress for the Frontend subnet which will be the incoming network traffic endpoint.")
		
		#Create a front end IP pool using the private IP address 125.16.91.52 for the Frontend subnet which will be the incoming network traffic endpoint.
		$frontendIPConfig = New-AzureRmLoadBalancerFrontendIpConfig -Name $frontEndConfigName -PrivateIpAddress $loadBalancerIPAddress -SubnetId $frontEndSubnet.Id
		#NAT Rules counter 
		$natRuleCounter = 0
		#Loop through each NAT rule and add to the Nat Rule ArrayList
		$natRuleArrayList = New-Object System.Collections.ArrayList #New-Object "System.Collections.Generic.List[PSInboundNatPool]"
	
		foreach ($natRuleName in $natRuleNameArray) 
		{
			$natRule = New-AzureRmLoadBalancerInboundNatRuleConfig -Name $natRuleName -FrontendIpConfiguration $frontendIPConfig -Protocol TCP -FrontendPort $natRuleFrontendPortArray[$natRuleCounter] -BackendPort $natRuleBackendPortArray[$natRuleCounter]
			$natRuleArrayList.Add($natRule) > $null
			$natRuleCounter+=1
		}
		#Create the load balancer adding all objects (NAT rules, Load balancer rules, probe configurations) together
		$GlobalLogModule.LogInfo("Creating Load Balancer $loadBalancerName")
		$internalLoadBalancer = New-AzureRmLoadBalancer -ResourceGroupName $rgName -Name $loadBalancerName -Location $location -FrontendIpConfiguration $frontendIPConfig -InboundNatRule $natRuleArrayList -ErrorAction Stop
	}
	
	#TESTED
	function CreateInternalLoadBalancerWithBackendPool($loadBalancerName, $loadBalancerIPAddress, $loadBalanceRuleList, $loadBalancerProbeList,$loadBalancerRuleandProbeMappingList, $backendPoolName, $rgName, $location, $vnetName, $subnetName)
	{
	<#
		Step 1 : Get Virtual Network Info
		Step 2 : Get Subnet Info
		Step 3 : Create a New Load Balancer with BackendPool Name
		Step 4 : Assign the Ip to Load balancer and mapped it with its subnet ID
		Step 5 : Create new Load Balancer Probe Config Rules and add it into Array
		Step 6 : Create a list of Load Balancer Rule Name, Load Balancer Front end port ,Load Balancer Back end port and add them into the array
		Step 7 : Create new load balancer config rules and add them into the array
		Step 8 : Create Load Balancer
	#>
		# Step 1 : Get Virtual Network Info
		try{
			$GlobalLogModule.LogInfo("Getting VNET info ... $vnetName ... Resource Name  $rgName ")
			$vnetObject = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $rgName -ErrorAction Stop
		}
		catch{
			$GlobalLogModule.LogError($_.Exception.Message)
			$GlobalLogModule.LogError($vnetName + " VNET not present, cannot continue further")
			return
		}
		
		# Step 2 : Get Subnet Info
		try{
			$GlobalLogModule.LogInfo("Getting VNET Subnet info ...  $subnetName ")
			$frontEndSubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnetObject -Name $subnetName -ErrorAction Stop
		}
		catch{
			$GlobalLogModule.LogError($_.Exception.Message)
			$GlobalLogModule.LogError($subnetName + " Subnet not present, cannot continue further")
			return
		}
		
		# Step 3 : Create a New Load Balancer with BackendPool Name
		$tempNumber = get-random -maximum 1000
		#Set up a back end address pool used to receive incoming traffic from front end IP pool.
		$GlobalLogModule.LogInfo("Backend Pool Name = $backendPoolName")
		$backendAddressPoolConfig = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $backendPoolName
		
		#Step 4 : Assign the Ip to Load balancer and mapped it with its subnet ID
		$frontEndConfigName = "LB-Frontend-" + $loadBalancerName + $tempNumber
		#Create LoadBalancer config name
		$configName = $frontEndConfigName + $loadBalancerName
		$GlobalLogModule.LogInfo("Create a front end IP pool using the private IP address $loadBalancerIPAddress for the Frontend subnet "+ $frontEndSubnet.Id+"which will be the incoming network traffic endpoint.")
		#Create a front end IP pool using the private IP address 125.16.91.52 for the Frontend subnet which will be the incoming network traffic endpoint.
		$frontendIPConfig = New-AzureRmLoadBalancerFrontendIpConfig -Name $frontEndConfigName -PrivateIpAddress $loadBalancerIPAddress -SubnetId $frontEndSubnet.Id
		
		#Step 5 : Create new Load Balancer Probe Config Rules and add it into Array
		#loadBalancerProbeList is in a list of the probe list for the VM in the backend pool, the structure of the array should be of the following format
		<#
			probeRuleName:tcpPort;probeRuleName:tcpPort;
		#>
		$GlobalLogModule.LogInfo(" loadBalancerProbeList = " + $loadBalancerProbeList)
		$loadBalancerProbeArray = $loadBalancerProbeList -split ";"
		
		#this final array will be used to map to the load balancing rule
		$finalProbeArray = New-Object System.Collections.ArrayList
		foreach($probeRule in $loadBalancerProbeArray)
		{
			$tempArray = $probeRule -split "~"
			#$tempArray[0] -> this is probe name
			#$tempArray[1] -> ths is port
			$backendProbe = New-AzureRmLoadBalancerProbeConfig -Name $tempArray[0] -Protocol TCP -Port $tempArray[1] -IntervalInSeconds 5 -ProbeCount 2
			$finalProbeArray.Add($backendProbe) > $null
		}
		
		#Step 6 : Create a list of Load Balancer Rule Name, Load Balancer Front end port ,Load Balancer Back end port and add them into the array
		#loadBalanceRuleList is a list of LB rules which need to be created, the structure of the array should be of the following format
		<#
			lbRuleName~frontEndport,backEndport;lbRuleName~frontEndport,backEndport
			Splitting flow:
			1. First on ";"
			2. then "~" and ","
		#>
		$GlobalLogModule.LogInfo(" loadBalanceRuleList = " + $loadBalanceRuleList)
		$requiredLBRuleArray = $loadBalanceRuleList -split ";"
		
		$lbRuleNameArray = New-Object System.Collections.ArrayList
		$lbRuleFrontendPortArray = New-Object System.Collections.ArrayList
		$lbRuleBackendPortArray = New-Object System.Collections.ArrayList
		
		foreach($lbRuleConfigGiven in $requiredLBRuleArray)
		{
			$tempArray = $lbRuleConfigGiven -split "~"
			#$tempArray[0] -> this is rule Name
			$tempArray2 = $tempArray[1] -split ","
			#$tempArray2[0] -> this is frontEndport
			#$tempArray2[1] -> this is backEndport
			$lbRuleNameArray.Add($tempArray[0]) > $null
			$lbRuleFrontendPortArray.Add($tempArray2[0]) > $null
			$lbRuleBackendPortArray.Add($tempArray2[1]) > $null
		}
		
		#Step 7 : Create new load balancer config rules and add them into the array
		#loadBalancerRuleandProbeMappingList is the mapping of the Probe with the Load balancing Rule, one to one mapping exists between these
		#the name of the Probe is mapped with the name of the LB Rule name, to attach the Probe to the rule.
		<#
			lbRuleName~lbProbeName;lbRuleName~lbProbeName
			Splitting flow:
			1. First on ";"
			2. then "~"
		#>
		$GlobalLogModule.LogInfo(" loadBalancerRuleandProbeMappingList = " + $loadBalancerRuleandProbeMappingList)
		$loadBalancerRuleandProbeMappingArray = $loadBalancerRuleandProbeMappingList -split ";"
		$finalLoadbalancingRuleList = New-Object System.Collections.ArrayList
		
		foreach($mappingElement in $loadBalancerRuleandProbeMappingArray)
		{
			$tempArray = $mappingElement -split "~"
			#$tempArray[0] -> this is LB rule Name
			$lbNameTemp = $tempArray[0]
		    #$tempArray[1] -> this is Probe Name
			$tempCounter = 0
			#fetch the probe object and the LB rule port information from the Array
			foreach($loadBalancingRuleName in $lbRuleNameArray)
			{
				if($lbNameTemp -eq $loadBalancingRuleName)
				{
					$backendLbrule = New-AzureRmLoadBalancerRuleConfig -Name $lbNameTemp -FrontendIpConfiguration $frontendIPConfig -BackendAddressPool $backendAddressPoolConfig -Probe $finalProbeArray[$tempCounter] -Protocol Tcp -FrontendPort $lbRuleFrontendPortArray[$tempCounter] -BackendPort $lbRuleBackendPortArray[$tempCounter] 
					
					$finalLoadbalancingRuleList.Add($backendLbrule) > $null
				}
				$tempCounter += 1
			}
		}
		
		#Step 8 : Create Load Balancer
		try{
			$GlobalLogModule.LogInfo("Creating Load Balancer $loadBalancerName .... ")
			$internaLoadBalancer = New-AzureRmLoadBalancer -ResourceGroupName $rgName -Name $loadBalancerName -Location $location -FrontendIpConfiguration $frontendIPConfig -LoadBalancingRule $finalLoadbalancingRuleList -BackendAddressPool $backendAddressPoolConfig -Probe $finalProbeArray  -ErrorAction Stop
			$GlobalLogModule.LogInfo("Load Balancer $loadBalancerName Successfully Created")
		}
		catch{
			$GlobalLogModule.LogError($_.Exception.Message)
		}
	}

	function CreateInternetFacingLoadBalancerWithBackendPool($loadBalancerName, $loadBalancerPublicIpDnsName, $loadBalanceRuleList, $loadBalancerProbeList,$loadBalancerRuleandProbeMappingList, $backendPoolName, $rgName, $location, $vnetName, $subnetName)
	{
		try{
			$GlobalLogModule.LogInfo("Getting Virtual Network Info .... $vnetName")
			$vnetObject = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $rgName -ErrorAction Stop
		}
		catch{
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			$GlobalLogModule.LogError($vnetName + " VNET not present, cannot continue further")
			return
		}
		try{
			$GlobalLogModule.LogInfo("Getting Subnet Info .... Subnet Name : $subnetName VNET Name : $vnetName")
			$frontEndSubnet = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnetObject -Name $subnetName -ErrorAction Stop
		}
		catch{
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			$GlobalLogModule.LogError($subnetName + " Subnet not present, cannot continue further")
			return
		}

		$tempNumber = get-random -maximum 1000
		#Set up a back end address pool used to receive incoming traffic from front end IP pool.
		$backendAddressPoolConfig = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name $backendPoolName
		
		$frontEndConfigName = "LB-Frontend-" + $loadBalancerName + $tempNumber
		$GlobalLogModule.LogInfo("FrontEndConfigName = " + $frontEndConfigName)

		#Create LoadBalancer config name
		$configName = $frontEndConfigName + $loadBalancerName
		$pipName = "cmrs-elb-" + $loadBalancerName 
		#Create a front end IP pool attaching the public IP address to the Frontend subnet which will be the incoming network traffic endpoint.
		try{
			$publicIpObject = New-AzureRmPublicIpAddress -AllocationMethod Static -ResourceGroupName $rgName -DomainNameLabel $loadBalancerPublicIpDnsName -Location $location -Name $pipName
		}
		catch{
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			$GlobalLogModule.LogError("Unable to create Public IP address for the load balancer, cannot continue further")
			return
		}
		
		try{
			$frontendIPConfig = New-AzureRmLoadBalancerFrontendIpConfig -Name $frontEndConfigName -PublicIpAddress $publicIpObject #-SubnetId $frontEndSubnet.Id
		}
		catch{
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			$GlobalLogModule.LogError("Unable to create Load balancer configuration, cannot continue further")
			return
		}
		#loadBalancerProbeList is in a list of the probe list for the VM in the backend pool, the structure of the array should be of the following format
		<#
			probeRuleName:tcpPort;probeRuleName:tcpPort;
		#>
		$loadBalancerProbeArray = $loadBalancerProbeList -split ";"
		
		#this final array will be used to map to the load balancing rule
		$finalProbeArray = New-Object System.Collections.ArrayList
		foreach($probeRule in $loadBalancerProbeArray)
		{
			$tempArray = $probeRule -split "~"
			#$tempArray[0] -> this is probe name
			#$tempArray[1] -> ths is port
			$backendProbe = New-AzureRmLoadBalancerProbeConfig -Name $tempArray[0] -Protocol TCP -Port $tempArray[1] -IntervalInSeconds 5 -ProbeCount 2
			$finalProbeArray.Add($backendProbe) > $null
		}
		
		#loadBalanceRuleList is a list of LB rules which need to be created, the structure of the array should be of the following format
		<#
			lbRuleName~frontEndport,backEndport;lbRuleName~frontEndport,backEndport
			Splitting flow:
			1. First on ";"
			2. then "~" and ","
		#>
		$requiredLBRuleArray = $loadBalanceRuleList -split ";"

		$lbRuleNameArray = New-Object System.Collections.ArrayList
		$lbRuleFrontendPortArray = New-Object System.Collections.ArrayList
		$lbRuleBackendPortArray = New-Object System.Collections.ArrayList
		
		foreach($lbRuleConfigGiven in $requiredLBRuleArray)
		{
			$tempArray = $lbRuleConfigGiven -split "~"
			#$tempArray[0] -> this is rule Name
			$tempArray2 = $tempArray[1] -split ","
			#$tempArray2[0] -> this is frontEndport
			#$tempArray2[1] -> this is backEndport
			$lbRuleNameArray.Add($tempArray[0]) > $null
			$lbRuleFrontendPortArray.Add($tempArray2[0]) > $null
			$lbRuleBackendPortArray.Add($tempArray2[1]) > $null
		}
		
		
		#loadBalancerRuleandProbeMappingList is the mapping of the Probe with the Load balancing Rule, one to one mapping exists between these
		#the name of the Probe is mapped with the name of the LB Rule name, to attach the Probe to the rule.
		<#
			lbRuleName~lbProbeName;lbRuleName~lbProbeName
			Splitting flow:
			1. First on ";"
			2. then "~"
		#>
		$loadBalancerRuleandProbeMappingArray = $loadBalancerRuleandProbeMappingList -split ";"
		$finalLoadbalancingRuleList = New-Object System.Collections.ArrayList
		
		foreach($mappingElement in $loadBalancerRuleandProbeMappingArray)
		{
			$tempArray = $mappingElement -split "~"
			#$tempArray[0] -> this is LB rule Name
			$lbNameTemp = $tempArray[0]
		    #$tempArray[1] -> this is Probe Name
			$tempCounter = 0
			#fetch the probe object and the LB rule port information from the Array
			foreach($loadBalancingRuleName in $lbRuleNameArray)
			{
				if($lbNameTemp -eq $loadBalancingRuleName)
				{
					$backendLbrule = New-AzureRmLoadBalancerRuleConfig -Name $lbNameTemp -FrontendIpConfiguration $frontendIPConfig -BackendAddressPool $backendAddressPoolConfig -Probe $finalProbeArray[$tempCounter] -Protocol Tcp -FrontendPort $lbRuleFrontendPortArray[$tempCounter] -BackendPort $lbRuleBackendPortArray[$tempCounter]
					
					$finalLoadbalancingRuleList.Add($backendLbrule) > $null
				}
				$tempCounter += 1
			}
		}
		try{
			$GlobalLogModule.LogInfo("Creating New Azure Rm LoadBalancer $loadBalancerName" )
			$internaLoadBalancer = New-AzureRmLoadBalancer -ResourceGroupName $rgName -Name $loadBalancerName -Location $location -FrontendIpConfiguration $frontendIPConfig -LoadBalancingRule $finalLoadbalancingRuleList -BackendAddressPool $backendAddressPoolConfig -Probe $finalProbeArray
		}
		catch{
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			$GlobalLogModule.LogError("Unable to create Load Balancer, cannot continue further")
			return
		}
	}
	
	function CreateTrafficManager($trafficManagerName,$trafficManagerDnsName,$httpMonitorPath,$httpMonitorPort,$dnsTimeToLiveInSecs,$rgName)
	{
		try{
			$GlobalLogModule.LogInfo("Creating Traffic manager profile ")
			$trafficManagerObj = New-AzureRmTrafficManagerProfile -MonitorPath $httpMonitorPath -MonitorPort $httpMonitorPort -MonitorProtocol HTTP -Name $trafficManagerName -RelativeDnsName $trafficManagerDnsName -ResourceGroupName $rgName -TrafficRoutingMethod Priority -Ttl $dnsTimeToLiveInSecs -ProfileStatus Enabled -Verbose -ErrorAction Stop
			return $trafficManagerObj
		}
		catch{
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			$GlobalLogModule.LogError("Unable to create Traffic manager profile, cannot continue further")
			return
		}		
	}
	
	function AddEndpointToTrafficManager($trafficManagerName,$trafficManagerResourceGroupName,$endPointName,$vmNameToAttach, $vmResourceGroupName)
	{
		try{
			$GlobalLogModule.LogInfo("Getting Traffic manager profile Info ...")
			$trafficManagerObj = Get-AzureRmTrafficManagerProfile -Name $trafficManagerName -ResourceGroupName $trafficManagerResourceGroupName -Verbose -ErrorAction Stop
		}
		catch{
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			$GlobalLogModule.LogError("Specified Traffic manager does not exists. Cannot continue further")
			return
		}		
		try{
			#get the Public IP address of the resoruce and the add the resouceid as the target resrouce ID to the TM profile.
			try{
				$GlobalLogModule.LogInfo("Getting VM info ...")
				$vmObj = Get-AzureRmVM -Name $vmNameToAttach -ResourceGroupName $vmResourceGroupName -Verbose -ErrorAction Stop
			}
			catch{
				$ErrorMessage = $_.Exception.Message
				$FailedItem = $_.Exception.ItemName
				$GlobalLogModule.LogError($ErrorMessage)
				$GlobalLogModule.LogError($FailedItem)
				$GlobalLogModule.LogError("Invalid VM specified. Cannot continue further")
				return
			}
			if($vmObj.NetworkInterfaceIDs.Count -gt 0)
			{
				$nicNameArray = $vmObj.NetworkProfile.NetworkInterfaces[0].Id.Split("/")
				$nicName = $nicNameArray[$nicNameArray.Count-1]
				$nicObj = Get-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $trafficManagerResourceGroupName
				if($nicObj.IpConfigurations[0].PublicIpAddress.Id.Length -gt 1)
				{
					$targetResourceID = $nicObj.IpConfigurations[0].PublicIpAddress.Id
				}
				else
				{
					$GlobalLogModule.LogError("Invalid VM specified. Public IP Address not present.")
					return
				}
			}
			else
			{
				$GlobalLogModule.LogError("Invalid VM specified. NIC not present.")
				return
			}
			Add-AzureRmTrafficManagerEndpointConfig -EndpointName $endPointName -EndpointStatus Enabled -TrafficManagerProfile $trafficManagerObj -Type AzureEndpoints -TargetResourceId $targetResourceID -Verbose -ErrorAction Stop
			Set-AzureRmTrafficManagerProfile -TrafficManagerProfile $trafficManagerObj -Verbose -ErrorAction Stop
		} 
		catch{
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			$GlobalLogModule.LogError("Unable to Add Traffic manager endpoint to the Traffic manager profile. Cannot continue further")
			return
		}
	}
	
	function CloneVM($srcVmName, $srcVMResourceGroup, $srcAzureSubscriptionId, $trgtAzureSubscriptionId, $trgVNetName, $trgtVMSubnetName, $trgtVMName, $trgtVMResourceGroup, $trgtVMLocation, $trgtVMSize, $trgtVMOSDiskStorageName, $trgtVMDataDiskStorageName, $trgtAvailabilitySetName, $trgtPrivateIPAddress, $trgtRequirePublicIPAddress, $trgtDNSArray, $trgtVMLoadbalancerName, $trgtVMNATRuleNameList, $trgtVMBackendPoolName)
	{
		$tempNumber = get-random -maximum 1000
		
		$currentTime = Get-Date -format G
		$GlobalLogModule.LogInfo(".... fetching source VM information")
		#Switch to Source VM Subscription ID to fetch data from Source VM
		Get-AzureRmSubscription -SubscriptionId $srcAzureSubscriptionId | Select-AzureRmSubscription
		<#
			1. Use the source VM to get the OS and Data disk information.
			2. Copy the VHDs to the new destination storage context
			3. Copy the NSG information from the source VM to the new VMs
		 Iterate through each of the VM Names to check for the following
		 1. VM Names
		 2. VM Sizes
		 3. Subnet to which the VM belongs
		 4. OS Disk to Attach
		 # 5. Public IP Address to Attach / Create 
		 # 6. Create NIC and Attach PIP to it with DNS endpoints specified
		 #  a. Create NSG using the NSG Rules collection and set it against NIC
		 # 7. Availablity Set to which the VM belongs
		 # 8. Attaches appropriate Nic's to the Internal Load Balancer to direct trafffic of RDP/IIS/MQ/SFTP to the Inbound machines
		 #>
		$oldVM = Get-AzureRmVM -Name $srcVmName -ResourceGroupName $srcVMResourceGroup 
		#fetches OS Disk attached to the VM
		$diskname = $oldVM.StorageProfile.OsDisk.Name
		#fetches Data Disk attached to the VM
		$scrDataDisk = $oldVM.StorageProfile.DataDisks
		### Source VHD - authenticated container ###
		$srcUri = $oldVM.StorageProfile.OsDisk.Vhd.Uri 
		### Source Storage Context
		$osStorageName = $cmrsTemplateModule.GetStorageNameFromUri($srcUri)
		$GlobalLogModule.LogInfo("Source VM OS Storage disk account name: " + $osStorageName )
		$storageOSKeys = $cmrsTemplateModule.GetStorageAccountKey($osStorageName, $srcVMResourceGroup)
		$GlobalLogModule.LogInfo("Source VM Data Disk Storage account key: " + $storageOSKeys[0].Value )
		$srcOSStorageContext = New-AzureStorageContext -StorageAccountKey $storageOSKeys[0].Value -StorageAccountName $osStorageName
		
		<# OLD CODE
		#$srcOSStorageArray = $srcVMOSDiskStorageKeyValue -split ";"
		#$srcDataDiskStorageArray = $srcVMDataDiskStorageKeyValue -split ";"
		#$srcOSStorageContext = New-AzureStorageContext -StorageAccountKey $srcOSStorageArray[1] -StorageAccountName $srcOSStorageArray[0]
		#$srcDDStorageContext = New-AzureStorageContext -StorageAccountKey $srcDataDiskStorageArray[1] -StorageAccountName $srcDataDiskStorageArray[0]
		
		### Destination Storage Context
		#$destOSStorageArray = $trgtVMOSDiskStorageKeyValue -split ";"
		#$destDataDiskStorageArray = $trgtVMDataDiskStorageKeyValue -split ";"
		#$destStorageContext = New-AzureStorageContext -StorageAccountKey $destOSStorageArray[1] -StorageAccountName $destOSStorageArray[0] 
		#$destOSStorageContext = New-AzureStorageContext -StorageAccountKey $destOSStorageArray[1] -StorageAccountName $destOSStorageArray[0] 
		#$destDDStorageContext = New-AzureStorageContext -StorageAccountKey $destDataDiskStorageArray[1] -StorageAccountName $destDataDiskStorageArray[0] 
		#>
		
		$destOSDiskStorageKeys = $cmrsTemplateModule.GetStorageAccountKey($trgtVMOSDiskStorageName, $trgtVMResourceGroup)
		$GlobalLogModule.LogInfo("Target VM OS Storage disk account key: " + $destOSDiskStorageKeys[0].Value)
		$destDiskStorageKeys = $cmrsTemplateModule.GetStorageAccountKey($trgtVMDataDiskStorageName, $trgtVMResourceGroup)
		$GlobalLogModule.LogInfo("Target VM Data disk Storage account key: " + $destDiskStorageKeys[0].Value)
		$destOSStorageContext = New-AzureStorageContext -StorageAccountKey $destOSDiskStorageKeys[0].Value -StorageAccountName $trgtVMOSDiskStorageName 
		$destDDStorageContext = New-AzureStorageContext -StorageAccountKey $destDiskStorageKeys[0].Value -StorageAccountName $trgtVMDataDiskStorageName
		
		##Creates the Target OS container, if not already existing
		$containerName = "vhds"
		#Switch to Target VM Subscription ID to setup storage container in the Target Subscription
		Get-AzureRmSubscription -SubscriptionId $trgtAzureSubscriptionId | Select-AzureRmSubscription
		try {  
				$GlobalLogModule.LogInfo("Getting Storage Container Info ....")
				$storageContainerContext = Get-AzureStorageContainer -Name $containerName -Context $destOSStorageContext -Verbose -ErrorAction Stop
		} 
		catch
		{ 
			  $GlobalLogModule.LogInfo("container not present, creating container")
			  try {
				$GlobalLogModule.LogInfo("Creating New container")
				$storageContainerContext = New-AzureStorageContainer -Name $containerName -Context $destOSStorageContext -Permission Off -Verbose -ErrorAction Stop	
			  } 
			  catch
			  {
				$ErrorMessage = $_.Exception.Message
				$FailedItem = $_.Exception.ItemName
				$GlobalLogModule.LogError($ErrorMessage)
				$GlobalLogModule.LogError($FailedItem)
				$GlobalLogModule.LogError("Unable to create destination container. Cannot continue further")
				return
			  }
		}
		##Creates the Target DataDisk container, if not already existing
		try {  
				$GlobalLogModule.LogInfo("Getting Container Info ..")
				$storageContainerContext = Get-AzureStorageContainer -Name $containerName -Context $destDDStorageContext -Verbose -ErrorAction Stop
		} 
		catch
		{ 
			  $GlobalLogModule.LogInfo("container not present, creating container")
			  try {
				$storageContainerContext = New-AzureStorageContainer -Name $containerName -Context $destDDStorageContext -Permission Off -Verbose -ErrorAction Stop	
			  } 
			  catch
			  {
				$ErrorMessage = $_.Exception.Message
				$FailedItem = $_.Exception.ItemName
				$GlobalLogModule.LogError($ErrorMessage)
				$GlobalLogModule.LogError($FailedItem)
				$GlobalLogModule.LogError("Unable to create destination container. Cannot continue further")
				return
			  }
		}

		$currentTime = Get-Date -format G
		$GlobalLogModule.LogInfo(".... stopping source VM")
		
		#Switch to Source VM Subscription ID to Stop the VM before copying the VHD, -StayProvisioned to make sure the IP address lease is not lost
		Get-AzureRmSubscription -SubscriptionId $srcAzureSubscriptionId | Select-AzureRmSubscription
		Stop-AzureRmVM -Name $srcVmName -ResourceGroupName $srcVMResourceGroup -Force
			
		$vmStatus = Get-AzureRmVM -Name $srcVmName -ResourceGroupName $srcVMResourceGroup -Status
		if($vmStatus.Statuses.Count -gt 0){	
			$GlobalLogModule.LogInfo("VM Status = " + $vmStatus.Statuses[1].DisplayStatus)
		}
		### Loop until complete ###                                    
		While($vmStatus.Statuses[1].DisplayStatus -ne "StoppedDeallocated" -and $vmStatus.Statuses[1].DisplayStatus -ne "VM deallocated" -and $vmStatus.Statuses[1].DisplayStatus -ne "StoppedVM"){
			$vmStatus = Get-AzureRmVM -Name $srcVmName -ResourceGroupName $srcVMResourceGroup -Status
			Start-Sleep 10
			### Print out status ###
			if($vmStatus.Statuses.Count -gt 0){	
				$GlobalLogModule.LogInfo("VM Status 1 = " + $vmStatus.Statuses[1].DisplayStatus)
			}
		 }

		$currentTime = Get-Date -format G
		$GlobalLogModule.LogInfo(" .... Copy of source VM OS started")
		### Start the asynchronous copy of the OS disk - specify the source authentication with -SrcContext ### 
		$destFileName = "OSDisk-" + $diskname + $trgtVMName + ".vhd"
		$GlobalLogModule.LogInfo(" DestFilename = " + $destFileName)
		try{
			$blobOSCopy = Start-AzureStorageBlobCopy -srcUri $srcUri -SrcContext $srcOSStorageContext -DestContainer $containerName -DestBlob $destFileName -DestContext $destOSStorageContext -Verbose -ErrorAction Stop
		}
		 catch{
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			$GlobalLogModule.LogError("Unable to copy source OS. Cannot continue further")
			return
		}
		## After starting the copy of the Data disk then, we will check for OS disk copy status

		 ## Start - Loop to get Data Disk from the existing VM ##
		$dataDisks = New-Object System.Collections.ArrayList
		if($scrDataDisk.Count -gt 1)
		{
			foreach ($element in $scrDataDisk) 
			{
				$dataDisks.Add($element) > $null
			}
			#$dataDisks.Count
			for($i=0; $i -le $dataDisks.Count; $i++)
			{
				$GlobalLogModule.LogInfo($dataDisks[$i].Vhd.Uri)
			}
		}
		if($scrDataDisk.Count -eq 1) 
		{
			#Write-Host $scrDataDisk.MediaLink.AbsoluteUri
			$GlobalLogModule.LogInfo($scrDataDisk[0].Vhd.Uri)
			$dataDisks.Add($scrDataDisk) > $null
		}
		if ($scrDataDisk.Count -eq 0) 
		{
			$GlobalLogModule.LogInfo("No Data disk found")
		}
		## Loop to copy DataDisk from source storage blob to destination storage blob
		## Variable to store multiple Data Disk Names ##
		$dataDiskNames = New-Object System.Collections.ArrayList
		## Variable to store Blob object to be used to check for copy status
		$dataBlobList = New-Object System.Collections.ArrayList
		if($scrDataDisk.Count -gt 0)
		{
			foreach ($diskElement in $dataDisks) 
			{
				
				#fetch the storage name and key, as per the VHD uri and then setup context accordingly
				$diskStorageName = $cmrsTemplateModule.GetStorageNameFromUri($diskElement.Vhd.Uri)
				$diskStorageKey = $cmrsTemplateModule.GetStorageAccountKey($diskStorageName, $srcVMResourceGroup)
				$srcDDStorageContext = New-AzureStorageContext -StorageAccountKey $diskStorageKey[0].Value -StorageAccountName $diskStorageName
			
				$tempDate = Get-Date -Format Mdyyyyhhmmssss
                $destDataFileName = $srcVmName + "DataDisk-" + $tempDate + ".vhd"
				$GlobalLogModule.LogInfo($destDataFileName)
				$dataDiskNames.Add($destDataFileName) > $null
				### Start the asynchronous copy - specify the source authentication with -SrcContext ### 
				try{
					$dataBlob = Start-AzureStorageBlobCopy -srcUri $diskElement.Vhd.Uri -SrcContext $srcDDStorageContext -DestContainer $containerName -DestBlob $destDataFileName -DestContext $destDDStorageContext 
					$dataBlobList.Add($dataBlob) > $null
					$currentTime = Get-Date -format G
					$GlobalLogModule.LogInfo($currentTime + " .... Copy of source VM Data Disk started for " +$destDataFileName )
				}
				 catch{
					$ErrorMessage = $_.Exception.Message
					$FailedItem = $_.Exception.ItemName
					$GlobalLogModule.LogError($ErrorMessage)
					$GlobalLogModule.LogError($FailedItem)
					$GlobalLogModule.LogError("Unable to copy source Data Disk. Cannot continue further")
					return
				}
			}
			
			##loop through the status to find out when the copy is complete, the idea being by the time the first copy finishes, the others would aslo be completed.
			### Retrieve the current status of the copy operation ###
			foreach ($blobElement in $dataBlobList)
			{
				$dataCopyStatus = $blobElement | Get-AzureStorageBlobCopyState 
				### Print out status ### 
				$GlobalLogModule.LogInfo("Source: " + $dataCopyStatus.Source)
				$GlobalLogModule.LogInfo("CopiedBytes: " + $dataCopyStatus.BytesCopied)
				$GlobalLogModule.LogInfo("TotalBytes: " + $dataCopyStatus.TotalBytes)

				### Loop until complete ###                                    
				While($dataCopyStatus.Status -eq "Pending"){
					$dataCopyStatus = $blobElement | Get-AzureStorageBlobCopyState 
					Start-Sleep 60
					### Print out status ###
					$GlobalLogModule.LogInfo("Source: " + $dataCopyStatus.Source)
					$GlobalLogModule.LogInfo("CopiedBytes: " + $dataCopyStatus.BytesCopied)
					$GlobalLogModule.LogInfo("TotalBytes: " + $dataCopyStatus.TotalBytes)
				 }
			}
		}
		## End - Loop to get Data Disk from the existing VM ##

											
		### Retrieve the current status of the OS Disk copy operation ###
		$status = $blobOSCopy | Get-AzureStorageBlobCopyState 
		### Print out status ### 
		$status 
		### Loop until complete ###                                    
		While($status.Status -eq "Pending"){
			$status = $blobOSCopy | Get-AzureStorageBlobCopyState 
			Start-Sleep 60
			### Print out status ###
			$GlobalLogModule.LogInfo("Source: " + $status.Source)
			$GlobalLogModule.LogInfo("CopiedBytes: " + $status.BytesCopied)
			$GlobalLogModule.LogInfo("TotalBytes: " + $status.TotalBytes)
		 }

		###Attach ARM resource to the new VM Config for provisioning 
		$osDiskName = $vmName + "OSDisk"
		$osDiskUri = (Get-AzureStorageBlob -Container $containerName -Blob $destFileName -Context $destOSStorageContext).ICloudBlob.uri.AbsoluteUri
		$dataDiskUri = New-Object System.Collections.ArrayList
		## Loop to get the final data disk URL
		foreach ($diskNameElement in $dataDiskNames) 
		{
			$dataDiskUri.Add((Get-AzureStorageBlob -Container $containerName -Blob $diskNameElement -Context $destDDStorageContext).ICloudBlob.uri.AbsoluteUri) > $null
		}
		
		#Switch to Target VM Subscription ID to setup the VM configuration
		Get-AzureRmSubscription -SubscriptionId $trgtAzureSubscriptionId | Select-AzureRmSubscription
		##Attach to Availability Set, if specified
		#Get object to Availability Set
		if($trgtAvailabilitySetName -ne "")
		{
			$currentTime = Get-Date -format G
			$GlobalLogModule.LogInfo(" .... Setting up Availability Set for target VM ")
			
			try{
				$availabilityset = Get-AzureRmAvailabilitySet -ResourceGroupName $trgtVMResourceGroup -Name $trgtAvailabilitySetName -Verbose -ErrorAction Stop
			}
			catch{
				$GlobalLogModule.LogInfo("Creating Availability Set " + $trgtAvailabilitySetName)
				try{
					$availabilityset = New-AzureRmAvailabilitySet -Location $trgtVMLocation -Name $availabilitysetName -ResourceGroupName $trgtVMResourceGroup -Verbose -ErrorAction Stop 
				}
				catch{
					$GlobalLogModule.LogError("Unable to create Availability Set " + $trgtAvailabilitySetName + " cannot continue further")
					$ErrorMessage = $_.Exception.Message
					$FailedItem = $_.Exception.ItemName
					$GlobalLogModule.LogError($ErrorMessage)
					$GlobalLogModule.LogError($FailedItem)
					return
				}
			}
		}
		if($trgtRequirePublicIPAddress -eq "true")
		{
			$currentTime = Get-Date -format G
			$GlobalLogModule.LogError("Setting up Public IP for target VM")
			
			#Get Public IP config
			$timestampDate = Get-Date -Format Mdyyyyhhmmssss
			$pipName = "Pip-" + $trgtVMName + $timestampDate
			$domainLabel = "dns" + $timestampDate
			try{
				$pip =  New-AzureRmPublicIpAddress -Name $pipName -Location $trgtVMLocation -AllocationMethod Dynamic -ResourceGroupName $trgtVMResourceGroup -DomainNameLabel $domainLabel -Verbose -ErrorAction Stop
			} 
			catch{
					$ErrorMessage = $_.Exception.Message
					$FailedItem = $_.Exception.ItemName
					$GlobalLogModule.LogError($ErrorMessage)
					$GlobalLogModule.LogError($FailedItem)
					$GlobalLogModule.LogError("Unable to create Public IP Address, cannot continue further")
					return
				}
		}
		#Get VNet Config
		$vnetObject = Get-AzureRmVirtualNetwork -Name $trgVNetName -ResourceGroupName $trgtVMResourceGroup  
		#Get Subnet Config
		$subnetconfig = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnetObject -Name $trgtVMSubnetName  

		$currentTime = Get-Date -format G
		$GlobalLogModule.LogError(" .... Setting up NIC for target VM ")
		#Get NIC Config, attach PublicIpAddress and DNS IP Address
		$timestampDate = Get-Date -Format Mdyyyyhhmmssss
		$nicname = "Nic-" + $trgtVMName + $timestampDate
		try{
			$nic = New-AzureRmNetworkInterface -Location $trgtVMLocation -Name $nicname -ResourceGroupName $trgtVMResourceGroup -Subnet $subnetconfig -PrivateIpAddress $trgtPrivateIPAddress -Verbose -ErrorAction Stop
		}
		catch{
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			$GlobalLogModule.LogError("Unable to create Network Interface, cannot continue further")
			return
		}
		if($trgtRequirePublicIPAddress -eq "true")
		{
			$nic.IpConfigurations[0].PublicIpAddress = $pip
		}
        foreach($dnsIpEntry in $trgtDNSArray)
        {
		    #$nic.DnsSettings.DnsServers = $trgtDNSArray
		    #$nic.DnsSettings.AppliedDnsServers = $trgtDNSArray 
            $nic.DnsSettings.DnsServers.Add($dnsIpEntry)
            $nic.DnsSettings.AppliedDnsServers.Add($dnsIpEntry)
        }
        #Attach to LB, if given name of LB
		if($trgtVMLoadbalancerName -ne "")
		{
			$currentTime = Get-Date -format G
			$GlobalLogModule.LogInfo( " .... Setting up LB profile on the NIC for target VM ")
			$lb = Get-AzureRmLoadBalancer -Name $trgtVMLoadbalancerName -ResourceGroupName $trgtVMResourceGroup
			#Check if NAT Rule List is given or Backend Pool name is to be attached with the Nic
			if($trgtVMBackendPoolName -ne "")
			{
				#Iterate through each of the LB backend Address Pools to add the VM to the specified Address Pool only
				foreach($lbBackendPoolName in $lb.BackendAddressPools)
				{
					if($trgtVMBackendPoolName -eq $lbBackendPoolName.Name)
					{
						$currentTime = Get-Date -format G
						$GlobalLogModule.LogInfo("  .... NIC added to backedpool " + $lbBackendPoolName.Name)
						$nic.IpConfigurations[0].LoadBalancerBackendAddressPools.Add($lbBackendPoolName) > $null
					}
				}
			}
			else
			{
				$vmNatRuleArray = $trgtVMNATRuleNameList -split ";"
				#Iterate through each of the LB NAT Rules and add those NAT rules which match to the NAT rule list given
				foreach($lbNatRule in $lb.InboundNatRules)
				{
					foreach($vmNatRuleName in $vmNatRuleArray)
					{
						if($vmNatRuleName -eq $lbNatRule.Name)
						{
							$currentTime = Get-Date -format G
							$GlobalLogModule.LogInfo( " .... NAT Rule " + $lbNatRule.Name + " added to NIC " + $lbBackendPoolName.Name)
							$nic.IpConfigurations[0].LoadBalancerInboundNatRules.Add($lbNatRule) > $null
						}
					}
				}
			}
		}
		
		#Switch to Source VM Subscription ID to Attach the source VMs NSG rules to the new VM
		Get-AzureRmSubscription -SubscriptionId $srcAzureSubscriptionId | Select-AzureRmSubscription
		#To get to the NSG, We need to get the NIC attached to this VM, and then use the NIC to find out the NSG Name and only then can we get the NSG Rules
		$srcTempNicArray = $oldVM.NetworkProfile.NetworkInterfaces.id -split "/"
		$srcTempNicName = $srcTempNicArray[$srcTempNicArray.Count-1]
		$srcTempNicObject = Get-AzureRmNetworkInterface -Name $srcTempNicName -ResourceGroupName $srcVMResourceGroup
		if(($srcTempNicObject.NetworkSecurityGroup -ne $null) -and ($srcTempNicObject.NetworkSecurityGroup.Id -ne ""))
		{
			$srcTempNsgArray = $srcTempNicObject.NetworkSecurityGroup.Id -split "/"
			if($srcTempNsgArray.Count -gt 0)
			{
				$srcTempNSGName = $srcTempNsgArray[$srcTempNsgArray.Count-1]
				$srcNsg = Get-AzureRmNetworkSecurityGroup -Name $srcTempNSGName -ResourceGroupName $srcVMResourceGroup
			}
			#Switch to Target VM Subscription ID to NSG for the VM
			Get-AzureRmSubscription -SubscriptionId $trgtAzureSubscriptionId | Select-AzureRmSubscription
			$currentTime = Get-Date -format G
			$GlobalLogModule.LogInfo("NSG policy applied to NIC  " )
			#Create a NSG with the BASIC NSG rules
			$trgtNsgName = "NSG-" + $trgtVMName + $tempNumber
			$trgtNsgToApply = New-AzureRmNetworkSecurityGroup -Location $trgtVMLocation -Name $trgtNsgName -ResourceGroupName $trgtVMResourceGroup -Force -SecurityRules $srcNsg.SecurityRules
			$nic.NetworkSecurityGroup = $trgtNsgToApply
		}
		
		#Switch to Target VM Subscription ID to setup NIC for the VM
		Get-AzureRmSubscription -SubscriptionId $trgtAzureSubscriptionId | Select-AzureRmSubscription
		$nic = Set-AzureRmNetworkInterface -NetworkInterface $nic
		#Setup VM Config
    
        #Check if size is not given then take the source machine size
        if($trgtVMSize -eq "")
        {
            $trgtVMSize = $oldVM.HardwareProfile.VmSize
        }

		if($trgtAvailabilitySetName -ne "")
		{
            
			$currentTime = Get-Date -format G
			$GlobalLogModule.LogInfo(" Target VM added to Availability Set " + $trgtAvailabilitySetName )
			$vm = New-AzureRMVMConfig -VMName $trgtVMName -VMSize $trgtVMSize -AvailabilitySetID $availabilityset.Id
		}
		else
		{
			$vm = New-AzureRMVMConfig -VMName $trgtVMName -VMSize $trgtVMSize 
		}
		
        #Setup VM default local admin credentials
        <#
		#$localAccountName ="cmrsAdmin"
        #$localPassword = ConvertTo-SecureString "Sapient@1234" -AsPlainText -Force
        #$psCred = New-Object System.Management.Automation.PSCredential($localAccountName, $localPassword)
        #$computerName = $trgtVMName
        #$vm = Set-AzureRmVMOperatingSystem -VM $vm -Windows -ComputerName $computerName ?Credential $cred
		#>
		
		$vm = Add-AzureRMVMNetworkInterface -VM $vm -Id $nic.Id
		## Loop to attach Data Disk to the VM Config
		$diskCounter=0
		foreach ($diskUriElement in $dataDiskUri) 
		{
			$currentTime = Get-Date -format G
			$GlobalLogModule.LogInfo(" Attaching data disk to target VM " )
			
			$vm = Add-AzureRmVMDataDisk -CreateOption attach -DiskSizeInGB $null -Name $dataDiskNames[$diskCounter] -Lun $dataDisks[$diskCounter].Lun -VhdUri$diskUriElement -VM $vm -Caching ReadWrite
			$diskCounter++
		}
		$vm = Set-AzureRMVMOSDisk -VM $vm -Name $osDiskName -VhdUri $osDiskUri -CreateOption attach -Windows
		
		$currentTime = Get-Date -format G
		$GlobalLogModule.LogInfo("  Starting Target VM Provisioning now" )
			
		try {  
            New-AzureRMVM -ResourceGroupName $trgtVMResourceGroup -Location $trgtVMLocation -VM $vm 
			$GlobalLogModule.LogInfo("Target VM Provisioning completed " )
		} 
		catch{	
		    $ErrorMessage = $_.Exception.Message
		    $FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			$GlobalLogModule.LogError("Unable to create target VM conatiner. Cannot continue further")
		}
        $currentTime = Get-Date -format G
		$GlobalLogModule.LogInfo("Starting Source VM now" )
		Get-AzureRmSubscription -SubscriptionId $srcAzureSubscriptionId | Select-AzureRmSubscription
        Start-AzureRmVM -Name $srcVmName -ResourceGroupName $srcVMResourceGroup
	}
	
	<#
		Function to Attach the Network Security Group to a Network Interface
		Parameters : Network Security Group Name , Network Interface Name , Region Name
	#>
	function AttachNSGToNetworkInterface($nsgName,$nicname,$rgName){
		$sg=Get-AzureRmNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName
		$nic1=Get-AzureRmNetworkInterface -Name $nicname  -ResourceGroupName $rgName
		$nic1.NetworkSecurityGroup=$sg
		$nic1 | Set-AzureRmNetworkInterface
	}

	function GetNsgRuleConfig($aclRuleName){
		$RuleNameCounter = 0
		foreach ($rulename in $GlobalRecordDetails["NetworkACLs"]["ACLRuleName"]){
			if($aclRuleName -eq $rulename){
				return New-AzureRmNetworkSecurityRuleConfig -Name $GlobalRecordDetails["NetworkACLs"]["ACLRuleName"][$RuleNameCounter] -Access  $GlobalRecordDetails["NetworkACLs"]["ACLRuleAction"][$RuleNameCounter] -DestinationAddressPrefix $GlobalRecordDetails["NetworkACLs"]["ACLDestinationAddress"][$RuleNameCounter] -DestinationPortRange $GlobalRecordDetails["NetworkACLs"]["ACLDestinationPort"][$RuleNameCounter] -Direction $GlobalRecordDetails["NetworkACLs"]["ACLDirection"][$RuleNameCounter] -Priority $GlobalRecordDetails["NetworkACLs"]["ACLRulePriorityNumber"][$RuleNameCounter] -Protocol $GlobalRecordDetails["NetworkACLs"]["ACLProtocol"][$RuleNameCounter] -SourceAddressPrefix $GlobalRecordDetails["NetworkACLs"]["ACLSourceAddress"][$RuleNameCounter] -SourcePortRange $GlobalRecordDetails["NetworkACLs"]["ACLSourcePort"][$RuleNameCounter]
				
		#		return  New-AzureRmNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
			}
			$RuleNameCounter++				
		}
	}

	function CreateNetworkSecurityGroups($nsgName,$aclRuleArray,$location,$rgName){
		$nicNSGObj=New-AzureRmNetworkSecurityGroup -Location $location -Name $nsgName -ResourceGroupName $rgName -Force
		foreach($aclRuleName in $aclRuleArray)
		{
			$nsgRule = GetNsgRuleConfig($aclRuleName)
			$nicNSGObj.SecurityRules.Add($nsgRule)
		}	
		Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nicNSGObj
	}
	
function Add-JDAzureRMVMToDomain {
<#
.SYNOPSIS
    The function joins Azure RM virtual machines to a domain.
.EXAMPLE
    Get-AzureRmVM -ResourceGroupName 'ADFS-WestEurope' | Select-Object Name,ResourceGroupName | Out-GridView -PassThru | Add-JDAzureRMVMToDomain -DomainName corp.acme.com -Verbose
.EXAMPLE
    Add-JDAzureRMVMToDomain -DomainName corp.acme.com -VMName AMS-ADFS1 -ResourceGroupName 'ADFS-WestEurope'
.NOTES
    Author   : Johan Dahlbom, johan[at]dahlbom.eu
    Blog     : 365lab.net
    The script are provided “AS IS” with no guarantees, no warranties, and it confer no rights.
#>
 
param(
    [Parameter(Mandatory=$true)]
    [string]$DomainName,
    [Parameter(Mandatory=$false)]
    [System.Management.Automation.PSCredential]$Credentials = (Get-Credential -Message 'Enter the domain join credentials'),
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [Alias('VMName')]
    [string]$Name,
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateScript({Get-AzureRmResourceGroup -Name $_})]
    [string]$ResourceGroupName
)
    begin {
        #Define domain join settings (username/domain/password)
        $Settings = @{
            Name = $DomainName
            User = $Credentials.UserName
            Restart = "true"
            Options = 3
        }
        $ProtectedSettings =  @{
                Password = $Credentials.GetNetworkCredential().Password
        }
        Write-Verbose -Message "Domainname is: $DomainName"
    }
    process {
        try {
            $RG = Get-AzureRmResourceGroup -Name $ResourceGroupName
            $JoinDomainHt = @{
                ResourceGroupName = $RG.ResourceGroupName
                ExtensionType = 'JsonADDomainExtension'
                Name = 'joindomain'
                Publisher = 'Microsoft.Compute'
                TypeHandlerVersion = '1.0'
                Settings = $Settings
                VMName = $Name
                ProtectedSettings = $ProtectedSettings
                Location = $RG.Location
            }
            Write-Verbose -Message "Joining $Name to $DomainName"
            Set-AzureRMVMExtension @JoinDomainHt
        } catch {
            Write-Warning $_
        }
    }
    end { }
}
    function CreateVM($vmName, $vmSize, $domain ,$vnetName, $subnetName, $availabilitysetName, $rgName, $location, $OSStorageName, $ssdDataDiskStorageName, $hddDataDiskStorageName, $ssdDataDiskList, $hddDataDiskList, $privateIPAddress, $requirePublicIPAddress, $localUsername, $localUserPassword, $trgtDNSArray, $trgtVMLoadbalancerName, $trgtVMNATRuleNameList, $trgtVMBackendPoolName, $vmPublisherName, $vmPublisherOfferName, $vmOfferSku, $NSGName,$ADGroupString,$UserString,$UserADGroupString)
    {	
		$tempNumber = get-random -maximum 1000
		$GlobalLogModule.LogInfo(" .... starting VM $vmName configuration")
		<#
		For creating a VM we need the following
		1. OS storage name
		2. Data disk storage name
			2a. List of data disk along with Size and Type to be created with the VM
		3. VM Name
		4. VM Size
		5. ResourceGroupName
		6. Location
		7. VNet Name
		8. Subnet Name
		9. InternalInternal IP Address ID (if provided then make the NIC address as Static)
		10. NSG Rules to Apply (if provided, this is a list of NSG rules that must be applied to the NIC being provisioned to the VM)
		11. DNS Array Addresses
		12. Availability Set Name (if provided then add to the ASET name)
		13. Local Admin Credentials
			13a. User Name
			13b. Admin Password
		14. VM Image Publisher Name
		15. VM Image Offer Name
		16. VM Image Sku Name
		17. Public IP Address (if required to be added)
			17a. DNS name
			17b. Static or Non-Static (preference would be to make it static)
		18. Attach to Load Balancer (if provided, then attach to the LB which matches the name)
			18a. Load balancer name 
			18b. LB NAT rule name to be added into or
			18c. LB Backend pool name to be added into
		 #>

		
		#if VM is not to be added into an Availability Set
		if($availabilitysetName -eq $null -AND $availabilitysetName -ne "")
		{
			$vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize 
		}
		else
		{
			#TODO: check for existence of ASET, if not then raise error and stop processing of this VM
			$GlobalLogModule.LogInfo("Getting AvailabilitySetName : $availabilitysetName")
			$availabilitysetObj = Get-AzureRmAvailabilitySet -ResourceGroupName $rgName -Name $availabilitysetName
			if($availabilitysetObj -eq $null){
				$GlobalLogModule.LogError("Availability Set $availabilitysetName does not exist ... Cannot continue further for this vm $vmName")
				return
			}
			$GlobalLogModule.LogInfo("vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetId $availabilitysetObj.Id")
			$vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetId $availabilitysetObj.Id
		}
		
		
		#TODO: Check for storage existence, if not then exit with error
		#fetch the storage keys
		<#
			1. Get Storage Account Context
			2. Check if there is a VHDS container in it, so as to store VHDs both for data and OS
			3. Get the Storage URI of the blob container so that it can be specified in the disk creation VhdURI parameter
		#>
		$OSStorageAccountObj = Get-AzureRmStorageAccount -Name $OSStorageName -ResourceGroupName $rgName
		$OSStorageKey =  GetStorageAccountKey $OSStorageName $rgName
		$OSStrgContext = New-AzureStorageContext -StorageAccountKey $OSStorageKey[0].Value -StorageAccountName $OSStorageName
	
		if($ssdDataDiskStorageName -ne $null -AND $ssdDataDiskStorageName -ne "")
		{
			$ssdStorageAccountObj = Get-AzureRmStorageAccount -Name $ssdDataDiskStorageName -ResourceGroupName $rgName
			$ssdDataDiskStorageKey = GetStorageAccountKey $ssdDataDiskStorageName  $rgName
			$ssdStrgContext = New-AzureStorageContext -StorageAccountKey $ssdDataDiskStorageKey[0].Value -StorageAccountName $ssdDataDiskStorageName
			#if there a requirement for provisioning SSD drives
			if($ssdDataDiskList -ne $null)
			{
				#split on ';' and add data disk to data disk storage
				$ssdDiskArray = $ssdDataDiskList.split(';')
				$lunCounter = 0
				#TODO: check for existence of VHDS conatiner, if not then create one
				$baseVhdUri = ((Get-AzureStorageContainer -Prefix vhds -Context $ssdStrgContext).CloudBlobContainer).StorageUri.PrimaryUri.AbsoluteUri
				foreach($ssdDiskSize in $ssdDiskArray)
				{
					$tempNumber = get-random -maximum 1000
					$diskName = $vmName + "-SSD-" + $tempNumber
					$vhdUri = $baseVhdUri + "/" + $diskName +".vhd"
					Add-AzureRmVMDataDisk -CreateOption Empty -DiskSizeInGB $ssdDiskSize -Name $diskName -VM $vmConfig -Caching ReadOnly -Lun $lunCounter -VhdUri $vhdUri
					$lunCounter++
				}
			}
		}

		if($hddDataDiskStorageName -ne $null -AND $hddDataDiskStorageName -ne "")
		{
			$hddStorageAccountObj = Get-AzureRmStorageAccount -Name $hddDataDiskStorageName -ResourceGroupName $rgName
			$hddDataDiskStorageKey = GetStorageAccountKey $hddDataDiskStorageName  $rgName
			$hddStrgContext = New-AzureStorageContext -StorageAccountKey $hddDataDiskStorageKey[0].Value -StorageAccountName $hddDataDiskStorageName
			#if there a requirement for provisioning SSD drives
			if($hddDataDiskList -ne $null)
			{
				#split on ';' and add data disk to data disk storage
				$hddDiskArray = $hddDataDiskList.split(';')
				$lunCounter = 0
				#TODO: check for existence of VHDS conatiner, if not then create one
				$baseVhdUri = ((Get-AzureStorageContainer -Prefix vhds -Context $hddStrgContext).CloudBlobContainer).StorageUri.PrimaryUri.AbsoluteUri
				foreach($hddDiskSize in $hddDiskArray)
				{
					$tempNumber = get-random -maximum 1000
					$diskName = $vmName + "-HDD-" + $tempNumber
					$vhdUri = $baseVhdUri + "/" + $diskName +".vhd"
					Add-AzureRmVMDataDisk -CreateOption Empty -DiskSizeInGB $hddDiskSize -Name $diskName -VM $vmConfig -Caching None -Lun $lunCounter -VhdUri $vhdUri
					$lunCounter++
				}
			}
		}

		#Configuring Public IP Address
		if($requirePublicIPAddress -eq "true")
		{
			$GlobalLogModule.LogInfo(" .... Setting up Public IP for target VM $vmName")
			
			#Get Public IP config
			$timestampDate = Get-Date -Format Mdyyyyhhmm
			$pipName = "Pip-" + $vmName + $timestampDate
			$domainLabel = "dns" + $vmName.ToLower() + $timestampDate
			try{
				$pip =  New-AzureRmPublicIpAddress -Name $pipName -Location $location -AllocationMethod Dynamic -ResourceGroupName $rgName -DomainNameLabel $domainLabel -Verbose -ErrorAction Stop
			} 
			catch{
					$GlobalLogModule.LogError("Unable to create Public IP Address, cannot continue further")
					$ErrorMessage = $_.Exception.Message
					$FailedItem = $_.Exception.ItemName
					$GlobalLogModule.LogError($ErrorMessage)
					$GlobalLogModule.LogError($FailedItem)
					return
				}
		}
		#Configuring/Setting up Nic for the VM along with Public Ip Address if required
		#Get VNet Config
		$GlobalLogModule.LogInfo("Getting Virtual Network , Name $vnetName ResourceGroupName $rgName  ")
		$vnetObject = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $rgName  
		#Get Subnet Config
		$GlobalLogModule.LogInfo("Getting Subnet config Details, VirtualNetwork $vnetObject , Name $subnetName  ")
		$subnetconfig = Get-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnetObject -Name $subnetName  
		
		$GlobalLogModule.LogInfo(" .... Setting up NIC for target VM $vmName" )

		#Get NIC Config, attach PublicIpAddress and DNS IP Address
		$timestampDate = Get-Date -Format Mdyyyyhhmm
		$nicname = "Nic-" + $vmName + $timestampDate
		try{
				$GlobalLogModule.LogInfo("Creating Network Interface , Name: $nicname , PrivateIpAddress: $privateIPAddress ")
				$nic = New-AzureRmNetworkInterface -Location $location -Name $nicname -ResourceGroupName $rgName -Subnet $subnetconfig -PrivateIpAddress $privateIPAddress -Verbose -ErrorAction Stop
		}
		catch{
				$GlobalLogModule.LogError("Unable to create Network Interface, cannot continue further")
				$ErrorMessage = $_.Exception.Message
				$FailedItem = $_.Exception.ItemName
				$GlobalLogModule.LogError($ErrorMessage)
				$GlobalLogModule.LogError($FailedItem)
				return
		}
		if($requirePublicIPAddress -eq "true")
		{
			$nic.IpConfigurations[0].PublicIpAddress = $pip
			Set-AzureRmNetworkInterface -NetworkInterface $nic
		}
		

		#Attach to LB, if given name of LB
		if($trgtVMLoadbalancerName -ne "")
		{
			$GlobalLogModule.LogInfo(" .... Setting up LB profile  $trgtVMLoadbalancerName on the NIC for target VM $vmName " )
			$lb = Get-AzureRmLoadBalancer -Name $trgtVMLoadbalancerName -ResourceGroupName $rgName
			#Check if NAT Rule List is given or Backend Pool name is to be attached with the Nic
			if($trgtVMBackendPoolName -ne "")
			{
				#Iterate through each of the LB backend Address Pools to add the VM to the specified Address Pool only
				foreach($lbBackendPoolName in $lb.BackendAddressPools)
				{
					if($trgtVMBackendPoolName -eq $lbBackendPoolName.Name)
					{
						$GlobalLogModule.LogInfo(" .... NIC added to backedpool  "+ $lbBackendPoolName.Name  )
						$GlobalLogModule.LogInfo(" 	$nic.IpConfigurations[0].LoadBalancerBackendAddressPools.Add($lbBackendPoolName)" )
						$nic.IpConfigurations[0].LoadBalancerBackendAddressPools.Add($lbBackendPoolName) > $null
					}
				}
			}
			else
			{
				$vmNatRuleArray = $trgtVMNATRuleNameList -split ";"
				#Iterate through each of the LB NAT Rules and add those NAT rules which match to the NAT rule list given
				foreach($lbNatRule in $lb.InboundNatRules)
				{
					foreach($vmNatRuleName in $vmNatRuleArray)
					{
						if($vmNatRuleName -eq $lbNatRule.Name)
						{
							$GlobalLogModule.LogInfo( " .... NAT Rule " + $lbNatRule.Name + " added to NIC " )
							$GlobalLogModule.LogInfo(" $nic.IpConfigurations[0].LoadBalancerInboundNatRules.Add($lbNatRule)" )
							$nic.IpConfigurations[0].LoadBalancerInboundNatRules.Add($lbNatRule) > $null
						}
					}
				}
			}
		}
		
		#TODO: Add NSG to the NIC
		<#
			1. Use the ACL Rule name to find the parameters
			2. Call the NSG method to add the NSG rule to the NIC
		#>
		<#
		if($accessRuleList -ne $null)
		{
			$nsgName = "NSG-" + $vmName
			$GlobalLogModule.LogInfo(" Creating NetworkSecurityGroup $nsgName")
			$nicNSGObj = New-AzureRmNetworkSecurityGroup -Location $location -Name $nsgName -ResourceGroupName $rgName -Force
			$aclRuleArray = $accessRuleList.split(';')
			foreach($aclRuleName in $aclRuleArray)
			{
				$nsgRule = GetNsgRuleConfig $aclRuleName 
				$nicNSGObj.SecurityRules.Add($nsgRule)
			}
			Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nicNSGObj
			$nic.NetworkSecurityGroup=$nicNSGObj
		}
		#>

		try{
			$GlobalLogModule.Loginfo("Getting NSG Details $nsgName ")
			$nicNSGObj = Get-AzureRmNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName -Verbose -ErrorAction Stop
			$nic.NetworkSecurityGroup=$nicNSGObj
		}
		catch{
			$GlobalLogModule.LogError("Unable to find the NSG Details $nsgName ")
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
		}
		
		Set-AzureRmNetworkInterface -NetworkInterface $nic
		AttachNSGToNetworkInterface $nsgName $nicname $rgName 

		#adding Nic to the Vm Config
		$GlobalLogModule.LogInfo("Adding Nic to VM Config  ..."+$nic.Id)
		$vmConfig = Add-AzureRMVMNetworkInterface -VM $vmConfig -Id $nic.Id
		
		#Setup VM default local admin credentials
		$localPassword = ConvertTo-SecureString $localUserPassword -AsPlainText -Force
		$psCred = New-Object System.Management.Automation.PSCredential($localUsername, $localPassword)
		$vmConfig = Set-AzureRmVMOperatingSystem -VM $vmConfig -Windows -ComputerName $vmName -Credential $psCred -ProvisionVMAgent -EnableAutoUpdate
		$OSDiskName = $vmName + "OSDisk"
		$OSDiskUri = $OSStorageAccountObj.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OSDiskName + ".vhd"
		
		$vmConfig = Set-AzureRmVMOSDisk -VM $vmConfig -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage
		#setup VM Config to the Image,SKU specified for the Vm
		$vmConfig = Set-AzureRmVMSourceImage -VM $vmConfig -PublisherName $vmPublisherName -Offer $vmPublisherOfferName -Skus $vmOfferSku -Version "latest"

		#Starting the provisioning of Vm
		$GlobalLogModule.LogInfo( " .... Starting the provisioning of VM - " + $vmName  )
		try{
			try{
				$VmObj = Get-AzureRmVM -ResourceGroupName $rgName -Name $vmName -Verbose -ErrorAction Stop
				$GlobalLogModule.LogError("...Cannot create VM. VM $vmName already exists... ")
				}
			catch{
				$GlobalLogModule.LogInfo("...Starting creation of VM $vmName ")
				New-AzureRmVM -ResourceGroupName $rgName -Location $location -VM $vmConfig -Verbose -ErrorAction Stop
				$GlobalLogModule.LogInfo("...VM $vmName Creation complete")
			}
		}
		catch{
			$GlobalLogModule.LogError("Unable to create VM , cannot continue further")
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			$GlobalLogModule.LogError($ErrorMessage)
			$GlobalLogModule.LogError($FailedItem)
			return
		}
		
		foreach($dnsIpEntry in $trgtDNSArray)
        {
			$GlobalLogModule.LogInfo("Dns IP Entry $dnsIpEntry")
			$nic.DnsSettings.DnsServers.Add($dnsIpEntry)
			$nic.DnsSettings.AppliedDnsServers.Add($dnsIpEntry)
        }
		Set-AzureRmNetworkInterface -NetworkInterface $nic
		AttachNSGToNetworkInterface $nsgName $nicname $rgName 

		#check if this is the primary AD server, if so then run the custom extension to install & configure Domain Controller on it
		if($vmName -eq "CMRSPAD1")
		{
			$GlobalLogModule.LogInfo( " .... Setting up domain controller on - " + $vmName  )
			$extensionArguments = "$domain test@1234"
			$extensionFileURI = "https://templateautoextension.blob.core.windows.net:443/extensionscripts/newadforest.ps1"
			$scriptName = "newadforest.ps1"

			$extensionFileURI1 = "https://testblobupload.blob.core.windows.net:443/test/ManageAdAccounts.ps1"
			$extensionArguments1 = "$ADGroupString $UserString $UserADGroupString"
			$scriptName1="ManageAdAccounts.ps1"
			try{			
				Set-AzureRmVMCustomScriptExtension -ResourceGroupName $rgName -VMName $vmName -Argument $extensionArguments -FileUri $extensionFileURI -Location $location -Name CustomScriptExtension -Run $scriptName -TypeHandlerVersion 1.8 -Verbose -ErrorAction Stop

				Remove-AzureRmVMCustomScriptExtension -ResourceGroupName $rgName -VMName $vmName -Name CustomScriptExtension -Force -Verbose 

				Set-AzureRmVMCustomScriptExtension -ResourceGroupName $rgName -VMName $vmName -Argument $extensionArguments1 -FileUri $extensionFileURI1 -Location $location -Name ManageAdGroup -Run $scriptName1 -TypeHandlerVersion 1.0 -Verbose -ErrorAction Stop
			}
			catch{
				$GlobalLogModule.LogError("Unable to create domain controller..")
				$ErrorMessage = $_.Exception.Message
				$FailedItem = $_.Exception.ItemName
				$GlobalLogModule.LogError($ErrorMessage)
				$GlobalLogModule.LogError($FailedItem)
				return
			}	
		}
		else{
			#$domain = "cmrsdomain.com"
			$extensionArguments = "$domain cmrsadmin Sapient@1234"
			$extensionFileURI = "https://templateautoextension.blob.core.windows.net:443/extensionscripts/joindomain.ps1"
			$scriptName = "joindomain.ps1"
			$GlobalLogModule.LogInfo( " .... Adding to domain - " + $domain )
			try{
				$DomPwd = ConvertTo-SecureString "Sapient@1234" -AsPlainText -Force
				$psCred = New-Object System.Management.Automation.PSCredential("cmrsdomain\cmrsadmin", $DomPwd)
				Add-JDAzureRMVMToDomain -DomainName $domain -VMName $vmName -ResourceGroupName $rgName -Credentials $psCred -Verbose

				#Set-AzureRmVMCustomScriptExtension -ResourceGroupName $rgName -VMName $vmName -Argument $extensionArguments -FileUri $extensionFileURI -Location $location -Name CustomScriptExtension -Run $scriptName -TypeHandlerVersion 1.8 -Verbose -ErrorAction Stop
			}
			catch{
				$GlobalLogModule.LogError("Unable to create domain controller..")
				$ErrorMessage = $_.Exception.Message
				$FailedItem = $_.Exception.ItemName
				$GlobalLogModule.LogError($ErrorMessage)
				$GlobalLogModule.LogError($FailedItem)
				return
			}	
		}
	
	}	
	
	function TestingFunction(){
	
		}

}
