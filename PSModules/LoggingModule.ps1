param
	(
		[ValidateNotNullOrEmpty()][string]$logPath ="D:\logs\",
		[ValidateNotNullOrEmpty()][string]$logFile ="test"+$(get-date -Format yyyymmdd_hhmmss)+".log"
	)


Set-Variable logPath -Scope Script
#$Script:logPath=$logPath
Set-Variable logFile -Scope Script
   
   
$LogModule = new-module -ascustomobject{

	Function SetlogPath ([string] $name)
	{
		$Script:logPath = $name
	}
	Function GetlogPath 
	{
		return $logPath
	}
	Function SetlogFile ([string] $name)
	{
		$Script:logFile= $name
	}
	Function GetlogFile 
	{
		return $logFile
	}

	function LogInfo($message)
	{
		 $date= Get-Date
		 $outContent = "[$date]`tInfo`t`t$message`n"
		 Add-Content "$Script:logPath\$Script:logFile" $outContent
		 Write-Host $message  -foregroundcolor "Yellow"
	}

	function LogError($message)
	{
		 $date= Get-Date
		 $outContent = "[$date]`tError`t`t $message`n"
		 Add-Content "$Script:logPath\$Script:logFile" $outContent
		 $message = "      $message       "
		 Write-Host $message  -foregroundcolor "RED" -backgroundcolor "White"
	}


}
