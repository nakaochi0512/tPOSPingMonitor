# このps1ファイルのフルパスのうち親ディレクトリまでのフルパスを取得して、カレントディレクトリを移動する
$path = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $path

#再起動実施リミット
$rebootLimit = 12

#通信するIPアドレス
$addressList = @(
    "192.168.11.10",
    "192.168.11.237",
    "192.168.11.38"
    )

$rebootLimit2 = $rebootLimit * $addressList.Count

#保存するフォルダ名
$folderName = @{
    info = "info"
    error = "error"
    device = "device"
    ping = "ping"
}

#ファイル名からPathを作成する関数
function createPath($folderList){
    $folderPathList = @{}
    foreach($folderName in $folderList.Values){
    $folderPathList[$folderName] += Join-Path .\log  $folderName
    }
    return $folderPathList
}

<#$foldernameで指定したディレクトリに特定のディレクトリがあるかを確認。ディレクトリがない場合は作成する。#>
 function confirm_directory($pathList){
    foreach($key in $pathList.keys){
        if(Test-Path $pathList[$key]){
            }else{
               New-Item $pathList[$key] -ItemType Directory
           }
        }
      
}

#ネットワークチェック関数
function netWorkCheck(){
    $ipAddressList = Get-NetIPAddress
    foreach($ipAddress in $ipAddressList){
        logfile $folderName["info"] ($folderName["info"],$ipAddress.InterfaceAlias,$ipAddress.IPAddress)
    }
    $comPort = Get-WmiObject -Class Win32_SerialPort
    logfile $folderName["device"] ($comPort.Caption,$comPort.ProviderType)
    deviceCheck $folderName["device"]
    foreach($address in $addressList) {
        $pingResult = Test-Connection $address -Count 1 -Quiet
		logfile $foldername["info"] ($folderName["info"],$address,$pingResult)
        logfile $foldername["ping"] ($folderName["ping"],$address,$pingResult)
        if(!$pingResult){
            $getNetAdapterList =  Get-NetAdapter
                foreach($ipAddress in $ipAddressList){
                    logfile $folderName["error"] ($folderName["info"],$ipAddress.InterfaceAlias,$ipAddress.IPAddress)
                    }
            logFile $folderName["error"] ($folderName["info"],$address,$pingResult)
            logFile $folderName["error"] ($folderName["device"],$comPort.Caption,$comPort.ProviderType)
            deviceCheck $folderName["error"]
            foreach($getNetAdapter in $getNetAdapterList){
                logFile $folderName["error"] ($folderName["error"],$getNetAdapter.Name,$getNetAdapter.Status)
                }
            }
        }
    }


#正しく認識されていないデバイスをチェックする関数
function deviceCheck($folderName){
    $deviceList = Get-WmiObject Win32_PnpEntity
    $deviceResult = @()
    foreach($device in $deviceList){
        logFile $folderName ("device",$device.Caption,$device.PNPDeviceID,$device.ConfigManagerErrorCode)
    }
}

#ログファイルを生成する
function logFile($fileName,$logString){
    $folderName = Join-Path .\log  $fileName
    $Time = (Get-Date).ToString("yyyy-MM-dd")
    $logfile =  $Time + " " + $fileName + ".log"
    $logpath = Join-Path $folderName $logfile
    $Now = Get-Date
    # Log 出力文字列に時刻を付加(YYYY/MM/DD HH:MM:SS.MMM $LogString)
    $Log = $Now.ToString("yyyy/MM/dd HH:mm:ss.fff") + " "
    $Log += $logString-join","
    Write-Output $Log | Out-File -FilePath $logpath -Encoding Default -append
}

#一番古いファイルを削除(90世代)
function deleteOldFile($folderPathList){
    foreach($key in $folderPathList.Keys){
        Get-ChildItem $folderPathList[$key] -Recurse |
        Sort-Object LastWriteTime -Descending|
        Select-Object -Skip 90|
        foreach{
            Remove-Item -Path  $_.FullName -Force
        }
    }
}

#新しいPingLogを取得
function Find-LatestPingLog($folderPathList){
    $result = @{}
    $pingLog = (Get-ChildItem $folderPathList["ping"] | Sort-Object LastWriteTime -Descending)[0].FullName
    $textlists = Get-Content $pingLog | Select-Object -Last $rebootLimit2 |
    ConvertFrom-Csv -Header @('date', 'ip', 'tf')
    foreach($text in $textlists){
        $result[$text.ip] += @($text.tf); 
    }
    return $result
}

#再起動確認関数
function Check-Reboot($result){
    foreach($address in $addressList){
        if($result[$address].Count -lt $rebootLimit){
            for( $i = 0; $i -ge $rebootLimit; $i++ ){
                if($result[$address][$i] -eq "True"){
                    logfile $foldername["info"] "疎通OK",$address
                    break
                }elseif($i -eq $rebootLimit -1){
                    logfile $foldername["error"] "疎通NG->Reboot",$address
                    shutdown /s /t 60
                }
                    logfile $foldername["error"] "疎通NG",$address
            }
        }
    }
}

#logフォルダの作成
$folderPathList = createPath $folderName
confirm_directory $folderPathList

logfile $foldername["info"] "<START>"
logfile $foldername["error"] "<START>"
logfile $foldername["device"] "<START>"
netWorkCheck
deleteOldFile $folderPathList
$result = Find-LatestPingLog $folderPathList
Check-Reboot $result
logfile $foldername["info"] "<END>"
logfile $foldername["error"] "<END>"
logfile $foldername["device"] "<END>"







