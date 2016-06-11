﻿<#
.Synopsis
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Create-FirstReceivedFromIPObject
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true
                   )]
        $MessageObject,

        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true
                   )]
        $SavePath
    )

    Begin
    {
        #regex is used for getting IPs from String
        $regex = '\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'

        $firstReceivedFromIP = @()
        $originalIpLocation = @()
        $originalmarker = @()
        $StartingIPObject = @()
    }
    Process
    {
        foreach ($msg in $MessageObject)
        {
            $firstReceivedFromIP = @()

            $firstReceivedFromIP = (Parse-EmailHeader -InputFileName $($msg.header)).From |
                Select-String -Pattern $regex -AllMatches | ForEach-Object -Process { $_.Matches } |
                    ForEach-Object -Process { $_.Value }
            
            $originalIpLocation = @()

            #calling first received from header returned from parse-emailheader. Location is [0]
            $originalIpLocation = Invoke-RestMethod -Uri "http://freegeoip.net/xml/$($firstReceivedFromIP[0])"

            #getting all first received from IP from headers and creating markers
            if (($originalIpLocation.Response.Latitude -ne 0) -or ($originalIpLocation.Response.Longitude -ne 0))
            {
                if (![string]::IsNullOrWhiteSpace($originalIpLocation.Response.Latitude))
                {
                    if (![string]::IsNullOrWhiteSpace($originalIpLocation.Response.Longitude))
                    {
                        #adding json markup data to object.  This will be passed to Get-PhishingGeoLocationStartingIps cmdlet
                        $props = @{
                            marker          = "`{'title': '$($msg.subject -replace "'",' ')', 'lat': '$($originalIpLocation.Response.Latitude)', 'lng': '$($originalIpLocation.Response.Longitude)', 'description': '<div><div></div><h1>$($msg.Subject -replace "'",' ')</h1><div><p><b>Subject</b>: $($msg.Subject -replace "'",' ')</p><p><b>Received Time</b>: $($msg.ReceivedTime)</p><p><b>Sender Email Address</b>: $($msg.SenderEmailAddress)</p><p><b>Sender Email Type</b>: $($msg.SenderEmailType)</p><p><b>Phishing URL</b>: $($msg.URL.RawPhishingLink)</p></div></div>' }"
                            subject         = $msg.Subject
                            SentFromAddress = $msg.SenderEmailAddress
                            SentFromType    = $msg.SenderEmailType
                            ReceivedTime    = $msg.ReceivedTime
                            EmailBody       = $msg.Body
                        }

                        $tempStartingIPObject = New-Object -TypeName PSObject -Property $props
                        $StartingIPObject += $tempStartingIPObject
                    }
                }
            }
        }
    }
    End
    {
        return $StartingIPObject
    }
}