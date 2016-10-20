$ADGroupString = $args[0]
$UserString = $args[1]
$UserADGroupString = $args[2]

$GroupArray = $ADGroupString.Split("~")
$UserArray = $UserString.Split(",")
$UserADGroupArray = $UserADGroupString.Split(",")

##########################
<####
function LogInfo($message)
{
	 $date= Get-Date
	 $outContent = "[$date]`tInfo`t`t$message`n"
	 Add-Content "$Script:logPath\$Script:logFile" $outContent
	 Write-Host $message  -foregroundcolor "Yellow"
}

LogInfo($UserString)

$logPath = "D:\logs"
$logFile ="test"+$(get-date -Format yyyymmdd_hhmmss)+".log"
Set-Variable logPath -Scope Script
Set-Variable logFile -Scope Script

LogInfo($UserADGroupString)
###>
##########################

#$GroupArray =  "TestGroup1","TestGroup2","TestGroup3"
$userHeadingArray = "Username","FirstName","SurName","Password"
#$UserArray=@("User1~FirstUserName~FirstUserSurname~Sapient@1234","User2~SecondUserName~SecondUserSurname~Sapient@1234","User3~ThirdUserName~ThirdUserSurname~Sapient@1234","User4~FourthUserName~FourthUserSurname~Sapient@1234")
#$UserADGroupArray=@("User1~Domain Admins","User1~DnsAdmins","User2~DnsAdmins")

foreach($group in $GroupArray){
	NEW-ADGroup -name $group -GroupScope Global
}

$MainUserDetails = @{}
$htHeadingList = @{}
Foreach ($ht in $userHeadingArray){
    $htHeadingList[$ht] =  New-Object Collections.Arraylist 
}

<#
foreach($user in $UserArray){
    $uArr = $user.Split("~")
    foreach($u in $uArr){
        $htHeadingList[$ht] =  New-Object Collections.Arraylist 
    }
 }
#>

$j=0
foreach($user in $UserArray){
    $uArr = $user.Split("~")
    $i=0
    foreach($u in $uArr){
        $hname =$userHeadingArray[$i]
        $htHeadingList[$hname].Add($u)
        $i = $i+1
    }
    $j = $j +1
}


for($cnt=0;$cnt -le $htHeadingList["FirstName"].Count-1;$cnt++){
	New-ADUser -Name $htHeadingList["UserName"][$cnt] -GivenName $htHeadingList["FirstName"][$cnt]   -samaccountname $htHeadingList["UserName"][$cnt] -Surname $htHeadingList["SurName"][$cnt] -AccountPassword (ConvertTo-SecureString $htHeadingList["Password"][$cnt]  -AsPlainText -force) -PassThru | Enable-ADAccount
}

foreach($uad in $UserADGroupArray){
	$uarr = $uad.Split("~")
	Add-ADGroupMember -Identity $uarr[1] -Member $uarr[0]
}
