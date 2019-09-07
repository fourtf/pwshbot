# set current directory
Set-Location $PSScriptRoot
[System.Environment]::CurrentDirectory = $PSScriptRoot

# load config
Invoke-Expression $([System.IO.File]::ReadAllText("./config.ps1"))

if ([String]::IsNullOrEmpty($botname)) {
    Write-Host '$botname not set up, please set up config.ps1'
    exit
}

if ([String]::IsNullOrEmpty($botchannel)) {
    Write-Host '$botchannel not set up, please set up config.ps1'
    exit
}

if ([String]::IsNullOrEmpty($ownername) -or $ownername -eq "myname") {
    Write-Host '$ownername not set up, please set up config.ps1'
    exit
}

# function to send a message
function Send {
    Write-Host $args[0]
    $writer.WriteLine("PRIVMSG #$botchannel :$($args[0])")
    $writer.Flush()
}

# commands are here
$commands = @{
    ping = 'Send("$user, pong")'
    pwd  = 'Send("C:\Users\pwshbot")'
}

$admin_commands = @{
    exit = 'exit'
}

# only allow a-z and digits for security(tm)
$allowed_message_regex = [Regex]::new('^>[a-zA-Z0-9\ ]+$');

# regex for tags
# /([^=;]+)=([^;]*)/g
$ircregex = [Regex]::new('^(?:@([^ ]+) )?(?:[:]((?:(\w+)!)?\S+) )?(\S+)(?: (?!:)(.+?))?(?: [:](.+))?$')

function Invoke-Irc-Command {
    $match = $ircregex.Match($args[0])

    $tags = $match.Groups[1].Value
    $prefix = $match.Groups[2].Value
    $user = $match.Groups[3].Value
    $command = $match.Groups[4].Value
    $params = $match.Groups[5].Value # channel for PRIVMSG
    $message = $match.Groups[6].Value

    Write-Host "$user : [$message]"

    if ($message.StartsWith(">") -and $allowed_message_regex.Matches($message)) {
        $words = $message.Substring(1).Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries);

        # select code to run
        $code = $commands[$words[0]]

        if (!$code -and $user -eq $ownername) {
            $code = $admin_commands[$words[0]]
        }

        # try to run
        try {
            if ($code) {
                Invoke-Expression $code
            }
            else {
                Write-Host "nope"
            }
        }
        catch {
            Send("$($_.Exception.Message)")
            Write-Host $_.Exception
        }
    }
}

# bot stuff
$conn = New-Object System.Net.Sockets.TcpClient
$conn.NoDelay = $true
$conn.SendBufferSize = 81920
$conn.ReceiveBufferSize = 81920

Write-Host "connecting..."
$conn.Connect("irc.chat.twitch.tv", 6697)
$stream = $conn.GetStream()

Write-Host "connected"
$sslstream = New-Object System.Net.Security.SslStream $stream, true
$sslstream.AuthenticateAsClient("irc.chat.twitch.tv")

$writer = New-Object System.IO.StreamWriter $sslstream
$writer.NewLine = "`r`n"
$reader = New-Object System.IO.StreamReader $sslstream

$writer.WriteLine("PASS oauth:$(Get-Content ./token.txt)")
$writer.WriteLine("NICK $botname")
$writer.WriteLine("CAP REQ :twitch.tv/tags");
$writer.WriteLine("JOIN #fourtf");
$writer.Flush();

Write-Host "reading..."
$line = $reader.ReadLine()
Write-Host "read"

# Gets the returns all words after index 1.
# To be used in commands.
function After {
    param ($i)

    $out = ""

    for (; $i -lt $words.Length; $i++) {
        $out = [String]::Concat($out, $words[$i], " ")
    }

    return $out
}

while ($line) {
    Invoke-Irc-Command $line

    $line = $reader.ReadLine()
}