function Test-JSTCPAvailability {
    <#
    .SYNOPSIS
        Tests if different tcp ports are reachable, a few builtin scenarios are included
    .DESCRIPTION
        This tool checks if one or more ports are reachable on one or more hosts. It can also check if RPC is open and it will display
        which RPC Service is available on that port.
    .EXAMPLE
        Test-PortReachable -Scenario WebServer -Target "www.gp.se", "www.svt.se", "www.boras.se", "www.aftonbladet.se", "www.existerarinte.se"
        Connects to the ports included in the scenario "WebServer" and displays the results.
    .EXAMPLE
        (Get-ADComputer -filter *).dnshostname | Test-PortReachable -Port 5985
        Query Active Directory for all computer objects and test if WinRM on port 5985 is available.
    .EXAMPLE
        "Server01", "Server02" | Test-PortReachable -Port 80,443,3389,5985
        Tests if the ports 80, 443,3389 and 5985 are reachable on Server01 and Server02
    .EXAMPLE
        "Server01", "Server02" | Test-PortReachable -CheckRPC
        Tries to connect to all RPC Services on Server01 and Server02 and returns the result in the output.
    .NOTES
        Author: Johan Selmosson
        License: MIT https://opensource.org/licenses/MIT
    #>
    [CmdletBinding()]
    param (
        # What TCP port or ports to test
        [Parameter(Mandatory,ParameterSetName = 'Port')]
        [int32[]]
        $Port,
        # Which Scenario to test
        [Parameter(Mandatory,ParameterSetName = 'Scenario')]
        [ValidateSet(
                'ActiveDirectoryDomainController',
                'ActiveDirectoryCertificateServices',
                'DHCPFailoverPartner',
                'ExchangeServer',
                'MECMServer',
                'SQLServer',
                'WebServer'
            )
        ]
        [string]
        $Scenario,
        # Timeout in milliseconds
        [Parameter()]
        [int32]
        $Timeout = 1000,
        # ComputerName or IpAdress
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,Position = 0,ParameterSetName='CheckRPC')]
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,Position = 0,ParameterSetName='Port')]
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,Position = 0,ParameterSetName='Scenario')]
        [Alias("DNSHostName", "ComputerName")]
        [string[]]
        $Target,
        # Check RPC Ports
        [Parameter(ParameterSetName= 'CheckRPC')]
        [Parameter(ParameterSetName= 'Port')]
        [Parameter(ParameterSetName= 'Scenario')]
        [switch]
        $CheckRPC
    )

    Begin {
        if ($scenario) {

        }

        Function Test-RPC {
            <#
            .SYNOPSIS
                Connects to the RPC-mapper and enumerates all RPC services and tries to connect to them.
            .NOTES
                Based on code found here:
                https://devblogs.microsoft.com/scripting/testing-rpc-ports-with-powershell-and-yes-its-as-much-fun-as-it-sounds/

                Original Author: Rian Ries, Microsoft
            .LINK
                https://devblogs.microsoft.com/scripting/testing-rpc-ports-with-powershell-and-yes-its-as-much-fun-as-it-sounds/
            .EXAMPLE
                Test-RPC
                Shows all RPC Services on localhost
            #>


            [CmdletBinding()]
            Param(
                [Parameter(ValueFromPipeline)]
                [String[]]
                $ComputerName = 'localhost',
                # Timeout in milliseconds
                [Parameter()]
                [int32]
                $Timeout = 1000
            )

            BEGIN {
                # source: https://github.com/fortra/impacket/blob/cd4fe47cfcb72d7d35237a99e3df95cedf96e94f/impacket/dcerpc/v5/epm.py
                # Apache License
                $KnownUUIDS = @{
                    '52C80B95-C1AD-4240-8D89-72E9FA84025E' = '[MC-CCFG]: Server Cluster:'
                    'FA7660F6-7B3F-4237-A8BF-ED0AD0DCBBD9' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '450386DB-7409-4667-935E-384DBBEE2A9E' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '832A32F7-B3EA-4B8C-B260-9A2923001184' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '2D9915FB-9D42-4328-B782-1B46819FAB9E' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '0DD8A158-EBE6-4008-A1D9-B7ECC8F1104B' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '0716CAF8-7D05-4A46-8099-77594BE91394' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    'B80F3C42-60E0-4AE0-9007-F52852D3DBED' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '0344CDDA-151E-4CBF-82DA-66AE61E97754' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '8BED2C68-A5FB-4B28-8581-A0DC5267419F' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '7883CA1C-1112-4447-84C3-52FBEB38069D' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '09829352-87C2-418D-8D79-4133969A489D' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '5B5A68E6-8B9F-45E1-8199-A95FFCCDFFFF' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '9BE77978-73ED-4A9A-87FD-13F09FEC1B13' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    'ED35F7A1-5024-4E7B-A44D-07DDAF4B524D' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '4DFA1DF3-8900-4BC7-BBB5-D1A458C52410' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '370AF178-7758-4DAD-8146-7391F6E18585' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    'C8550BFF-5281-4B1E-AC34-99B6FA38464D' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '08A90F5F-0702-48D6-B45F-02A9885A9768' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '8F6D760F-F0CB-4D69-B5F6-848B33E9BDC6' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    'E7927575-5CC3-403B-822E-328A6B904BEE' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    'DE095DB1-5368-4D11-81F6-EFEF619B7BCF' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '64FF8CCC-B287-4DAE-B08A-A72CBF45F453' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    'EAFE4895-A929-41EA-B14D-613E23F62B71' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    'EF13D885-642C-4709-99EC-B89561C6BC69' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '0191775E-BCFF-445A-B4F4-3BDDA54E2816' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    '31A83EA0-C0E4-4A2C-8A01-353CC2A4C60A' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    'D6C7CD8F-BB8D-4F96-B591-D3A5F1320269' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    'ADA4E6FB-E025-401E-A5D0-C3134A281F07' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    'B7D381EE-8860-47A1-8AF4-1F33B2B1F325' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    'C5C04795-321C-4014-8FD6-D44658799393' = '[MC-IISA]: Internet Information Services (IIS) Application Host COM'
                    'EBA96B22-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    '12A30900-7300-11D2-B0E6-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B24-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    '2CE0C5B0-6E67-11D2-B0E6-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B0E-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'B196B285-BAB4-101A-B69C-00AA00341D07' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    '39CE96FE-F4C5-4484-A143-4C2D5D324229' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E07F-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B1A-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B18-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B23-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B14-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'FD174A80-89CF-11D2-B0F2-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'F72B9031-2F0C-43E8-924E-E6052CDC493F' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E072-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E075-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    '0188401C-247A-4FED-99C6-BF14119D7055' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B15-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E07C-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'BE5F0241-E489-4957-8CC4-A452FCF3E23E' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B1C-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E077-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E078-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'B196B284-BAB4-101A-B69C-00AA00341D07' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E073-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E07D-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B1B-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E079-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E084-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B1F-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    '33B6D07E-F27D-42FA-B2D7-BF82E11E9374' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E07A-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    '0188AC2F-ECB3-4173-9779-635CA2039C72' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E085-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EF0574E0-06D8-11D3-B100-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E086-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'B196B286-BAB4-101A-B69C-00AA00341D07' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D9933BE0-A567-11D2-B0F3-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7AB3341-C9D3-11D1-BB47-0080C7C5A2C0' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E082-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    '0FB15084-AF41-11CE-BD2B-204C4F4F5020' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E083-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B13-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B1D-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B17-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B20-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E074-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    '7FBE7759-5760-444D-B8A5-5E7AB9A84CCE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'B196B287-BAB4-101A-B69C-00AA00341D07' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B12-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B1E-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E07E-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E081-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E07B-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    '64C478FB-F9B0-4695-8A7F-439AC94326D3' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B16-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B19-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B10-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B21-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E076-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B0F-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'EBA96B11-2168-11D3-898C-00E02C074F6B' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    'D7D6E080-DCCD-11D0-AA4B-0060970DEBAE' = '[MC-MQAC]: Message Queuing (MSMQ):'
                    '4639DB2A-BFC5-11D2-9318-00C04FBBBFB3' = '[MS-ADTG]: Remote Data Services (RDS) Transport Protocol'
                    '0EAC4842-8763-11CF-A743-00AA00A3F00D' = '[MS-ADTG]: Remote Data Services (RDS) Transport Protocol'
                    '070669EB-B52F-11D1-9270-00C04FBBBFB3' = '[MS-ADTG]: Remote Data Services (RDS) Transport Protocol'
                    '3DDE7C30-165D-11D1-AB8F-00805F14DB40' = '[MS-BKRP]: BackupKey Remote Protocol'
                    'E3D0D746-D2AF-40FD-8A7A-0D7078BB7092' = '[MS-BPAU]: Background Intelligent Transfer Service (BITS) Peer-'
                    '6BFFD098-A112-3610-9833-012892020162' = '[MS-BRWSA]: Common Internet File System (CIFS) Browser Auxiliary'
                    'AFC07E2E-311C-4435-808C-C483FFEEC7C9' = '[MS-CAPR]: Central Access Policy Identifier (ID) Retrieval Protocol'
                    'B97DB8B2-4C63-11CF-BFF6-08002BE23F2F' = '[MS-CMRP]: Failover Cluster:'
                    '97199110-DB2E-11D1-A251-0000F805CA53' = '[MS-COM]: Component Object Model Plus (COM+) Protocol'
                    '0E3D6630-B46B-11D1-9D2D-006008B0E5CA' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    '3F3B1B86-DBBE-11D1-9DA6-00805F85CFE3' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    '7F43B400-1A0E-4D57-BBC9-6B0C65F7A889' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    '456129E2-1078-11D2-B0F9-00805FC73204' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    '8DB2180E-BD29-11D1-8B7E-00C04FD7A924' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    '182C40FA-32E4-11D0-818B-00A0C9231C29' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    '971668DC-C3FE-4EA1-9643-0C7230F494A1' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    '98315903-7BE5-11D2-ADC1-00A02463D6E7' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    '6C935649-30A6-4211-8687-C4C83E5FE1C7' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    'F131EA3E-B7BE-480E-A60D-51CB2785779E' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    '1F7B1697-ECB2-4CBB-8A0E-75C427F4A6F0' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    'A8927A41-D3CE-11D1-8472-006008B0E5CA' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    'CFADAC84-E12C-11D1-B34C-00C04F990D54' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    '1D118904-94B3-4A64-9FA6-ED432666A7B9' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    '47CDE9A1-0BF6-11D2-8016-00C04FB9988E' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    '0E3D6631-B46B-11D1-9D2D-006008B0E5CA' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    'C2BE6970-DF9E-11D1-8B87-00C04FD7A924' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    'C726744E-5735-4F08-8286-C510EE638FB6' = '[MS-COMA]: Component Object Model Plus (COM+) Remote'
                    'FBC1D17D-C498-43A0-81AF-423DDD530AF6' = '[MS-COMEV]: Component Object Model Plus (COM+) Event System'
                    'F89AC270-D4EB-11D1-B682-00805FC79216' = '[MS-COMEV]: Component Object Model Plus (COM+) Event System'
                    'FB2B72A1-7A68-11D1-88F9-0080C7D771BF' = '[MS-COMEV]: Component Object Model Plus (COM+) Event System'
                    '4E14FB9F-2E22-11D1-9964-00C04FBBB345' = '[MS-COMEV]: Component Object Model Plus (COM+) Event System'
                    'A0E8F27A-888C-11D1-B763-00C04FB926AF' = '[MS-COMEV]: Component Object Model Plus (COM+) Event System'
                    '7FB7EA43-2D76-4EA8-8CD9-3DECC270295E' = '[MS-COMEV]: Component Object Model Plus (COM+) Event System'
                    '99CC098F-A48A-4E9C-8E58-965C0AFC19D5' = '[MS-COMEV]: Component Object Model Plus (COM+) Event System'
                    'FB2B72A0-7A68-11D1-88F9-0080C7D771BF' = '[MS-COMEV]: Component Object Model Plus (COM+) Event System'
                    '4A6B0E16-2E38-11D1-9965-00C04FBBB345' = '[MS-COMEV]: Component Object Model Plus (COM+) Event System'
                    'F4A07D63-2E25-11D1-9964-00C04FBBB345' = '[MS-COMEV]: Component Object Model Plus (COM+) Event System'
                    '4A6B0E15-2E38-11D1-9965-00C04FBBB345' = '[MS-COMEV]: Component Object Model Plus (COM+) Event System'
                    'B60040E0-BCF3-11D1-861D-0080C729264D' = '[MS-COMT]: Component Object Model Plus (COM+) Tracker Service'
                    '23C9DD26-2355-4FE2-84DE-F779A238ADBD' = '[MS-COMT]: Component Object Model Plus (COM+) Tracker Service'
                    '4E6CDCC9-FB25-4FD5-9CC5-C9F4B6559CEC' = '[MS-COMT]: Component Object Model Plus (COM+) Tracker Service'
                    'D99E6E71-FC88-11D0-B498-00A0C90312F3' = '[MS-CSRA]: Certificate Services Remote Administration Protocol'
                    '7FE0D935-DDA6-443F-85D0-1CFB58FE41DD' = '[MS-CSRA]: Certificate Services Remote Administration Protocol'
                    'E1568352-586D-43E4-933F-8E6DC4DE317A' = '[MS-CSVP]: Failover Cluster:'
                    '11942D87-A1DE-4E7F-83FB-A840D9C5928D' = '[MS-CSVP]: Failover Cluster:'
                    '491260B5-05C9-40D9-B7F2-1F7BDAE0927F' = '[MS-CSVP]: Failover Cluster:'
                    'C72B09DB-4D53-4F41-8DCC-2D752AB56F7C' = '[MS-CSVP]: Failover Cluster:'
                    'E3C9B851-C442-432B-8FC6-A7FAAFC09D3B' = '[MS-CSVP]: Failover Cluster:'
                    '4142DD5D-3472-4370-8641-DE7856431FB0' = '[MS-CSVP]: Failover Cluster:'
                    'D6105110-8917-41A5-AA32-8E0AA2933DC9' = '[MS-CSVP]: Failover Cluster:'
                    'A6D3E32B-9814-4409-8DE3-CFA673E6D3DE' = '[MS-CSVP]: Failover Cluster:'
                    '04D55210-B6AC-4248-9E69-2A569D1D2AB6' = '[MS-CSVP]: Failover Cluster:'
                    '2931C32C-F731-4C56-9FEB-3D5F1C5E72BF' = '[MS-CSVP]: Failover Cluster:'
                    '12108A88-6858-4467-B92F-E6CF4568DFB6' = '[MS-CSVP]: Failover Cluster:'
                    '85923CA7-1B6B-4E83-A2E4-F5BA3BFBB8A3' = '[MS-CSVP]: Failover Cluster:'
                    'F1D6C29C-8FBE-4691-8724-F6D8DEAEAFC8' = '[MS-CSVP]: Failover Cluster:'
                    '3CFEE98C-FB4B-44C6-BD98-A1DB14ABCA3F' = '[MS-CSVP]: Failover Cluster:'
                    '88E7AC6D-C561-4F03-9A60-39DD768F867D' = '[MS-CSVP]: Failover Cluster:'
                    '00000131-0000-0000-C000-000000000046' = '[MS-DCOM]: Distributed Component Object Model (DCOM) Remote'
                    '4D9F4AB8-7D1C-11CF-861E-0020AF6E7C57' = '[MS-DCOM]: Distributed Component Object Model (DCOM) Remote'
                    '00000143-0000-0000-C000-000000000046' = '[MS-DCOM]: Distributed Component Object Model (DCOM) Remote'
                    '000001A0-0000-0000-C000-000000000046' = '[MS-DCOM]: Distributed Component Object Model (DCOM) Remote'
                    '99FCFEC4-5260-101B-BBCB-00AA0021347A' = '[MS-DCOM]: Distributed Component Object Model (DCOM) Remote'
                    '4FC742E0-4A10-11CF-8273-00AA004AE673' = '[MS-DFSNM]: Distributed File System (DFS):'
                    '9009D654-250B-4E0D-9AB0-ACB63134F69F' = '[MS-DFSRH]: DFS Replication Helper Protocol'
                    'E65E8028-83E8-491B-9AF7-AAF6BD51A0CE' = '[MS-DFSRH]: DFS Replication Helper Protocol'
                    'D3766938-9FB7-4392-AF2F-2CE8749DBBD0' = '[MS-DFSRH]: DFS Replication Helper Protocol'
                    '4BB8AB1D-9EF9-4100-8EB6-DD4B4E418B72' = '[MS-DFSRH]: DFS Replication Helper Protocol'
                    'CEB5D7B4-3964-4F71-AC17-4BF57A379D87' = '[MS-DFSRH]: DFS Replication Helper Protocol'
                    '7A2323C7-9EBE-494A-A33C-3CC329A18E1D' = '[MS-DFSRH]: DFS Replication Helper Protocol'
                    '20D15747-6C48-4254-A358-65039FD8C63C' = '[MS-DFSRH]: DFS Replication Helper Protocol'
                    'C4B0C7D9-ABE0-4733-A1E1-9FDEDF260C7A' = '[MS-DFSRH]: DFS Replication Helper Protocol'
                    '6BFFD098-A112-3610-9833-46C3F874532D' = '[MS-DHCPM]: Microsoft Dynamic Host Configuration Protocol (DHCP)'
                    '5B821720-F63B-11D0-AAD2-00C04FC324DB' = '[MS-DHCPM]: Microsoft Dynamic Host Configuration Protocol (DHCP)'
                    '4DA1C422-943D-11D1-ACAE-00C04FC2AA3F' = '[MS-DLTM]: Distributed Link Tracking:'
                    '300F3532-38CC-11D0-A3F0-0020AF6B0ADD' = '[MS-DLTW]: Distributed Link Tracking:'
                    'D2D79DF5-3400-11D0-B40B-00AA005FF586' = '[MS-DMRP]: Disk Management Remote Protocol'
                    'DEB01010-3A37-4D26-99DF-E2BB6AE3AC61' = '[MS-DMRP]: Disk Management Remote Protocol'
                    '3A410F21-553F-11D1-8E5E-00A0C92C9D5D' = '[MS-DMRP]: Disk Management Remote Protocol'
                    'D2D79DF7-3400-11D0-B40B-00AA005FF586' = '[MS-DMRP]: Disk Management Remote Protocol'
                    '4BDAFC52-FE6A-11D2-93F8-00105A11164A' = '[MS-DMRP]: Disk Management Remote Protocol'
                    '135698D2-3A37-4D26-99DF-E2BB6AE3AC61' = '[MS-DMRP]: Disk Management Remote Protocol'
                    '50ABC2A4-574D-40B3-9D66-EE4FD5FBA076' = '[MS-DNSP]: Domain Name Service (DNS) Server Management'
                    '7C44D7D4-31D5-424C-BD5E-2B3E1F323D22' = '[MS-DRSR]: Directory Replication Service (DRS) Remote Protocol'
                    '3919286A-B10C-11D0-9BA8-00C04FD92EF5' = '[MS-DSSP]: Directory Services Setup Remote Protocol'
                    '14A8831C-BC82-11D2-8A64-0008C7457E5D' = '[MS-EERR]: ExtendedError Remote Data Structure'
                    'C681D488-D850-11D0-8C52-00C04FD90F7E' = '[MS-EFSR]: Encrypting File System Remote (EFSRPC) Protocol'
                    '82273FDC-E32A-18C3-3F78-827929DC23EA' = '[MS-EVEN]: EventLog Remoting Protocol'
                    '6B5BDD1E-528C-422C-AF8C-A4079BE4FE48' = '[MS-FASP]: Firewall and Advanced Security Protocol'
                    '6099FC12-3EFF-11D0-ABD0-00C04FD91A4E' = '[MS-FAX]: Fax Server and Client Remote Protocol'
                    'EA0A3165-4834-11D2-A6F8-00C04FA346CC' = '[MS-FAX]: Fax Server and Client Remote Protocol'
                    '897E2E5F-93F3-4376-9C9C-FD2277495C27' = '[MS-FRS2]: Distributed File System Replication Protocol'
                    '377F739D-9647-4B8E-97D2-5FFCE6D759CD' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'F411D4FD-14BE-4260-8C40-03B7C95E608A' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '4C8F96C3-5D94-4F37-A4F4-F56AB463546F' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'CFE36CBA-1949-4E74-A14F-F1D580CEAF13' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '8276702F-2532-4839-89BF-4872609A2EA4' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '4A73FEE4-4102-4FCC-9FFB-38614F9EE768' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'F3637E80-5B22-4A2B-A637-BBB642B41CFC' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '1568A795-3924-4118-B74B-68D8F0FA5DAF' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '6F4DBFFF-6920-4821-A6C3-B7E94C1FD60C' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '39322A2D-38EE-4D0D-8095-421A80849A82' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '326AF66F-2AC0-4F68-BF8C-4759F054FA29' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '27B899FE-6FFA-4481-A184-D3DAADE8A02B' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'E1010359-3E5D-4ECD-9FE4-EF48622FDF30' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '8DD04909-0E34-4D55-AFAA-89E1F1A1BBB9' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '96DEB3B5-8B91-4A2A-9D93-80A35D8AA847' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'D8CC81D9-46B8-4FA4-BFA5-4AA9DEC9B638' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'EDE0150F-E9A3-419C-877C-01FE5D24C5D3' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '15A81350-497D-4ABA-80E9-D4DBCC5521FE' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '12937789-E247-4917-9C20-F3EE9C7EE783' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'F76FBF3B-8DDD-4B42-B05A-CB1C3FF1FEE8' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'CB0DF960-16F5-4495-9079-3F9360D831DF' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '4846CB01-D430-494F-ABB4-B1054999FB09' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '6CD6408A-AE60-463B-9EF1-E117534D69DC' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'EE321ECB-D95E-48E9-907C-C7685A013235' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '38E87280-715C-4C7D-A280-EA1651A19FEF' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'BEE7CE02-DF77-4515-9389-78F01C5AFC1A' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '9A2BF113-A329-44CC-809A-5C00FCE8DA40' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '4173AC41-172D-4D52-963C-FDC7E415F717' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'AD55F10B-5F11-4BE7-94EF-D9EE2E470DED' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'BB36EA26-6318-4B8C-8592-F72DD602E7A5' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'FF4FA04E-5A94-4BDA-A3A0-D5B4D3C52EBA' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '22BCEF93-4A3F-4183-89F9-2F8B8A628AEE' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '6879CAF9-6617-4484-8719-71C3D8645F94' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '5F6325D3-CE88-4733-84C1-2D6AEFC5EA07' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '8BB68C7D-19D8-4FFB-809E-BE4FC1734014' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'A2EFAB31-295E-46BB-B976-E86D58B52E8B' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '0770687E-9F36-4D6F-8778-599D188461C9' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'AFC052C2-5315-45AB-841B-C6DB0E120148' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '515C1277-2C81-440E-8FCF-367921ED4F59' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'D2DC89DA-EE91-48A0-85D8-CC72A56F7D04' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '47782152-D16C-4229-B4E1-0DDFE308B9F6' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '205BEBF8-DD93-452A-95A6-32B566B35828' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '1BB617B8-3886-49DC-AF82-A6C90FA35DDA' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '42DC3511-61D5-48AE-B6DC-59FC00C0A8D6' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '426677D5-018C-485C-8A51-20B86D00BDC4' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'E946D148-BD67-4178-8E22-1C44925ED710' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'D646567D-26AE-4CAA-9F84-4E0AAD207FCA' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'F82E5729-6ABA-4740-BFC7-C7F58F75FB7B' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    '2DBE63C4-B340-48A0-A5B0-158E07FC567E' = '[MS-FSRM]: File Server Resource Manager Protocol'
                    'A8E0653C-2744-4389-A61D-7373DF8B2292' = '[MS-FSRVP]: File Server Remote VSS Protocol'
                    'B9785960-524F-11DF-8B6D-83DCDED72085' = '[MS-GKDI]: Group Key Distribution Protocol'
                    '91AE6020-9E3C-11CF-8D7C-00AA00C091BE' = '[MS-ICPR]: ICertPassage Remote Protocol'
                    'E8FB8620-588F-11D2-9D61-00C04F79C5FE' = '[MS-IISS]: Internet Information Services (IIS) ServiceControl'
                    'F612954D-3B0B-4C56-9563-227B7BE624B4' = '[MS-IMSA]: Internet Information Services (IIS) IMSAdminBaseW'
                    '8298D101-F992-43B7-8ECA-5052D885B995' = '[MS-IMSA]: Internet Information Services (IIS) IMSAdminBaseW'
                    '29822AB8-F302-11D0-9953-00C04FD919C1' = '[MS-IMSA]: Internet Information Services (IIS) IMSAdminBaseW'
                    '70B51430-B6CA-11D0-B9B9-00A0C922E750' = '[MS-IMSA]: Internet Information Services (IIS) IMSAdminBaseW'
                    '29822AB7-F302-11D0-9953-00C04FD919C1' = '[MS-IMSA]: Internet Information Services (IIS) IMSAdminBaseW'
                    'BD0C73BC-805B-4043-9C30-9A28D64DD7D2' = '[MS-IMSA]: Internet Information Services (IIS) IMSAdminBaseW'
                    '7C4E1804-E342-483D-A43E-A850CFCC8D18' = '[MS-IMSA]: Internet Information Services (IIS) IMSAdminBaseW'
                    '6619A740-8154-43BE-A186-0319578E02DB' = '[MS-IOI]: IManagedObject Interface Protocol'
                    '8165B19E-8D3A-4D0B-80C8-97DE310DB583' = '[MS-IOI]: IManagedObject Interface Protocol'
                    'C3FCC19E-A970-11D2-8B5A-00A0C9B7C9C4' = '[MS-IOI]: IManagedObject Interface Protocol'
                    '82AD4280-036B-11CF-972C-00AA006887B0' = '[MS-IRP]: Internet Information Services (IIS) Inetinfo Remote'
                    '4E65A71E-4EDE-4886-BE67-3C90A08D1F29' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '866A78BC-A2FB-4AC4-94D5-DB3041B4ED75' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'B0D1AC4B-F87A-49B2-938F-D439248575B2' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'E141FD54-B79E-4938-A6BB-D523C3D49FF1' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '40CC8569-6D23-4005-9958-E37F08AE192B' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '1822A95E-1C2B-4D02-AB25-CC116DD9DBDE' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'B4FA8E86-2517-4A88-BD67-75447219EEE4' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '3C73848A-A679-40C5-B101-C963E67F9949' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '66C9B082-7794-4948-839A-D8A5A616378F' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '01454B97-C6A5-4685-BEA8-9779C88AB990' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'D6BD6D63-E8CB-4905-AB34-8A278C93197A' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '348A0821-69BB-4889-A101-6A9BDE6FA720' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '703E6B03-7AD1-4DED-BA0D-E90496EBC5DE' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '100DA538-3F4A-45AB-B852-709148152789' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '592381E5-8D3C-42E9-B7DE-4E77A1F75AE4' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '883343F1-CEED-4E3A-8C1B-F0DADFCE281E' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '6AEA6B26-0680-411D-8877-A148DF3087D5' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'D71B2CAE-33E8-4567-AE96-3CCF31620BE2' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '8C58F6B3-4736-432A-891D-389DE3505C7C' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '1995785D-2A1E-492F-8923-E621EACA39D9' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'C10A76D8-1FE4-4C2F-B70D-665265215259' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '8D7AE740-B9C5-49FC-A11E-89171907CB86' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '8AD608A4-6C16-4405-8879-B27910A68995' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'B0076FEC-A921-4034-A8BA-090BC6D03BDE' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '640038F1-D626-40D8-B52B-09660601D045' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'BB39E296-AD26-42C5-9890-5325333BB11E' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'B06A64E3-814E-4FF9-AFAC-597AD32517C7' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'A5ECFC73-0013-4A9E-951C-59BF9735FDDA' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '1396DE6F-A794-4B11-B93F-6B69A5B47BAE' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'DD6F0A28-248F-4DD3-AFE9-71AED8F685C4' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '52BA97E7-9364-4134-B9CB-F8415213BDD8' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'E2842C88-07C3-4EB0-B1A9-D3D95E76FEF2' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '312CC019-D5CD-4CA7-8C10-9E0A661F147E' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '345B026B-5802-4E38-AC75-795E08B0B83F' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '442931D5-E522-4E64-A181-74E98A4E1748' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '1B1C4D1C-ABC4-4D3A-8C22-547FBA3AA8A0' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '56E65EA5-CDFF-4391-BA76-006E42C2D746' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'E645744B-CAE5-4712-ACAF-13057F7195AF' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'FE7F99F9-1DFB-4AFB-9D00-6A8DD0AABF2C' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '81FE3594-2495-4C91-95BB-EB5785614EC7' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    'F093FE3D-8131-4B73-A742-EF54C20B337B' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '28BC8D5E-CA4B-4F54-973C-ED9622D2B3AC' = '[MS-ISTM]: iSCSI Software Target Management Protocol'
                    '22E5386D-8B12-4BF0-B0EC-6A1EA419E366' = '[MS-LREC]: Live Remote Event Capture (LREC) Protocol'
                    '12345778-1234-ABCD-EF00-0123456789AB' = '[MS-LSAD]: Local Security Authority (Domain Policy) Remote Protocol'
                    '708CCA10-9569-11D1-B2A5-0060977D8118' = '[MS-MQDS]: Message Queuing (MSMQ):'
                    '77DF7A80-F298-11D0-8358-00A024C480A8' = '[MS-MQDS]: Message Queuing (MSMQ):'
                    '76D12B80-3467-11D3-91FF-0090272F9EA3' = '[MS-MQMP]: Message Queuing (MSMQ):'
                    'FDB3A030-065F-11D1-BB9B-00A024EA5525' = '[MS-MQMP]: Message Queuing (MSMQ):'
                    '41208EE0-E970-11D1-9B9E-00E02C064C39' = '[MS-MQMR]: Message Queuing (MSMQ):'
                    '1088A980-EAE5-11D0-8D9B-00A02453C337' = '[MS-MQQP]: Message Queuing (MSMQ):'
                    '1A9134DD-7B39-45BA-AD88-44D01CA47F28' = '[MS-MQRR]: Message Queuing (MSMQ):'
                    '17FDD703-1827-4E34-79D4-24A55C53BB37' = '[MS-MSRP]: Messenger Service Remote Protocol'
                    '12345678-1234-ABCD-EF00-01234567CFFB' = '[MS-NRPC]: Netlogon Remote Protocol'
                    '00020411-0000-0000-C000-000000000046' = '[MS-OAUT]: OLE Automation Protocol'
                    '00020401-0000-0000-C000-000000000046' = '[MS-OAUT]: OLE Automation Protocol'
                    '00020403-0000-0000-C000-000000000046' = '[MS-OAUT]: OLE Automation Protocol'
                    '00020412-0000-0000-C000-000000000046' = '[MS-OAUT]: OLE Automation Protocol'
                    '00020402-0000-0000-C000-000000000046' = '[MS-OAUT]: OLE Automation Protocol'
                    '00020400-0000-0000-C000-000000000046' = '[MS-OAUT]: OLE Automation Protocol'
                    '00020404-0000-0000-C000-000000000046' = '[MS-OAUT]: OLE Automation Protocol'
                    '784B693D-95F3-420B-8126-365C098659F2' = '[MS-OCSPA]: Microsoft OCSP Administration Protocol'
                    'AE33069B-A2A8-46EE-A235-DDFD339BE281' = '[MS-PAN]: Print System Asynchronous Notification Protocol'
                    '0B6EDBFA-4A24-4FC6-8A23-942B1ECA65D1' = '[MS-PAN]: Print System Asynchronous Notification Protocol'
                    '76F03F96-CDFD-44FC-A22C-64950A001209' = '[MS-PAR]: Print System Asynchronous Remote Protocol'
                    'DA5A86C5-12C2-4943-AB30-7F74A813D853' = '[MS-PCQ]: Performance Counter Query Protocol'
                    '03837510-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '03837543-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '03837533-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '03837541-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '03837544-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '03837524-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '0383753A-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '03837534-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '0383750B-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '0383751A-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '03837512-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '0383753D-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '03837506-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '03837520-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '038374FF-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '03837514-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '03837502-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '03837516-098B-11D8-9414-505054503030' = '[MS-PLA]: Performance Logs and Alerts Protocol'
                    '0B1C2170-5732-4E0E-8CD3-D9B16F3B84D7' = '[MS-RAA]: Remote Authorization API Protocol'
                    'F120A684-B926-447F-9DF4-C966CB785648' = '[MS-RAI]: Remote Assistance Initiation Protocol'
                    '833E4010-AFF7-4AC3-AAC2-9F24C1457BCE' = '[MS-RAI]: Remote Assistance Initiation Protocol'
                    '833E4200-AFF7-4AC3-AAC2-9F24C1457BCE' = '[MS-RAI]: Remote Assistance Initiation Protocol'
                    '3C3A70A7-A468-49B9-8ADA-28E11FCCAD5D' = '[MS-RAI]: Remote Assistance Initiation Protocol'
                    '833E4100-AFF7-4AC3-AAC2-9F24C1457BCE' = '[MS-RAI]: Remote Assistance Initiation Protocol'
                    '833E41AA-AFF7-4AC3-AAC2-9F24C1457BCE' = '[MS-RAI]: Remote Assistance Initiation Protocol'
                    'C323BE28-E546-4C23-A81B-D6AD8D8FAC7B' = '[MS-RAINPS]: Remote Administrative Interface:'
                    '83E05BD5-AEC1-4E58-AE50-E819C7296F67' = '[MS-RAINPS]: Remote Administrative Interface:'
                    '45F52C28-7F9F-101A-B52B-08002B2EFABE' = '[MS-RAIW]: Remote Administrative Interface:'
                    '811109BF-A4E1-11D1-AB54-00A0C91E9B45' = '[MS-RAIW]: Remote Administrative Interface:'
                    'A35AF600-9CF4-11CD-A076-08002B2BD711' = '[MS-RDPESC]: Remote Desktop Protocol:'
                    '12345678-1234-ABCD-EF00-0123456789AB' = '[MS-RPRN]: Print System Remote Protocol'
                    '66A2DB21-D706-11D0-A37B-00C04FC9DA04' = '[MS-RRASM]: Routing and Remote Access Server (RRAS) Management'
                    '66A2DB1B-D706-11D0-A37B-00C04FC9DA04' = '[MS-RRASM]: Routing and Remote Access Server (RRAS) Management'
                    '66A2DB20-D706-11D0-A37B-00C04FC9DA04' = '[MS-RRASM]: Routing and Remote Access Server (RRAS) Management'
                    '66A2DB22-D706-11D0-A37B-00C04FC9DA04' = '[MS-RRASM]: Routing and Remote Access Server (RRAS) Management'
                    '8F09F000-B7ED-11CE-BBD2-00001A181CAD' = '[MS-RRASM]: Routing and Remote Access Server (RRAS) Management'
                    '5FF9BDF6-BD91-4D8B-A614-D6317ACC8DD8' = '[MS-RRASM]: Routing and Remote Access Server (RRAS) Management'
                    '20610036-FA22-11CF-9823-00A0C911E5DF' = '[MS-RRASM]: Routing and Remote Access Server (RRAS) Management'
                    '67E08FC2-2984-4B62-B92E-FC1AAE64BBBB' = '[MS-RRASM]: Routing and Remote Access Server (RRAS) Management'
                    '6139D8A4-E508-4EBB-BAC7-D7F275145897' = '[MS-RRASM]: Routing and Remote Access Server (RRAS) Management'
                    '338CD001-2244-31F1-AAAA-900038001003' = '[MS-RRP]: Windows Remote Registry Protocol'
                    '3BBED8D9-2C9A-4B21-8936-ACB2F995BE6C' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    '8DA03F40-3419-11D1-8FB1-00A024CB6019' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    'D61A27C6-8F53-11D0-BFA0-00A024151983' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    '081E7188-C080-4FF3-9238-29F66D6CABFD' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    '895A2C86-270D-489D-A6C0-DC2A9B35280E' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    'D02E4BE0-3419-11D1-8FB1-00A024CB6019' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    'DB90832F-6910-4D46-9F5E-9FD6BFA73903' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    '4E934F30-341A-11D1-8FB1-00A024CB6019' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    '879C8BBE-41B0-11D1-BE11-00C04FB6BF70' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    '00000000-0000-0000-C000-000000000046' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    '69AB7050-3059-11D1-8FAF-00A024CB6019' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    '7D07F313-A53F-459A-BB12-012C15B1846E' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    'BB39332C-BFEE-4380-AD8A-BADC8AFF5BB6' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    'B057DC50-3059-11D1-8FAF-00A024CB6019' = '[MS-RSMP]: Removable Storage Manager (RSM) Remote Protocol'
                    '894DE0C0-0D55-11D3-A322-00C04FA321A1' = '[MS-RSP]: Remote Shutdown Protocol'
                    'D95AFE70-A6D5-4259-822E-2C84DA1DDB0D' = '[MS-RSP]: Remote Shutdown Protocol'
                    '12345778-1234-ABCD-EF00-0123456789AC' = '[MS-SAMR]: Security Account Manager (SAM) Remote Protocol'
                    '01954E6B-9254-4E6E-808C-C9E05D007696' = '[MS-SCMP]: Shadow Copy Management Protocol'
                    'FA7DF749-66E7-4986-A27F-E2F04AE53772' = '[MS-SCMP]: Shadow Copy Management Protocol'
                    '214A0F28-B737-4026-B847-4F9E37D79529' = '[MS-SCMP]: Shadow Copy Management Protocol'
                    'AE1C7110-2F60-11D3-8A39-00C04F72D8E3' = '[MS-SCMP]: Shadow Copy Management Protocol'
                    '367ABB81-9844-35F1-AD32-98F038001003' = '[MS-SCMR]: Service Control Manager Remote Protocol'
                    '4B324FC8-1670-01D3-1278-5A47BF6EE188' = '[MS-SRVS]: Server Service Remote Protocol'
                    'CCD8C074-D0E5-4A40-92B4-D074FAA6BA28' = '[MS-SWN]: Service Witness Protocol'
                    '1A1BB35F-ABB8-451C-A1AE-33D98F1BEF4A' = '[MS-TPMVSC]: Trusted Platform Module (TPM) Virtual Smart Card'
                    '1C60A923-2D86-46AA-928A-E7F3E37577AF' = '[MS-TPMVSC]: Trusted Platform Module (TPM) Virtual Smart Card'
                    'FDF8A2B9-02DE-47F4-BC26-AA85AB5E5267' = '[MS-TPMVSC]: Trusted Platform Module (TPM) Virtual Smart Card'
                    '112B1DFF-D9DC-41F7-869F-D67FEE7CB591' = '[MS-TPMVSC]: Trusted Platform Module (TPM) Virtual Smart Card'
                    '152EA2A8-70DC-4C59-8B2A-32AA3CA0DCAC' = '[MS-TPMVSC]: Trusted Platform Module (TPM) Virtual Smart Card'
                    '16A18E86-7F6E-4C20-AD89-4FFC0DB7A96A' = '[MS-TPMVSC]: Trusted Platform Module (TPM) Virtual Smart Card'
                    '3C745A97-F375-4150-BE17-5950F694C699' = '[MS-TPMVSC]: Trusted Platform Module (TPM) Virtual Smart Card'
                    '2F5F6521-CA47-1068-B319-00DD010662DB' = '[MS-TRP]: Telephony Remote Protocol'
                    '2F5F6520-CA46-1067-B319-00DD010662DA' = '[MS-TRP]: Telephony Remote Protocol'
                    '1FF70682-0A51-30E8-076D-740BE8CEE98B' = '[MS-TSCH]: Task Scheduler Service Remoting Protocol'
                    '378E52B0-C0A9-11CF-822D-00AA0051E40F' = '[MS-TSCH]: Task Scheduler Service Remoting Protocol'
                    '86D35949-83C9-4044-B424-DB363231FD0C' = '[MS-TSCH]: Task Scheduler Service Remoting Protocol'
                    '44E265DD-7DAF-42CD-8560-3CDB6E7A2729' = '[MS-TSGU]: Terminal Services Gateway Server Protocol'
                    '034634FD-BA3F-11D1-856A-00A0C944138C' = '[MS-TSRAP]: Telnet Server Remote Administration Protocol'
                    '497D95A6-2D27-4BF5-9BBD-A6046957133C' = '[MS-TSTS]: Terminal Services Terminal Server Runtime Interface'
                    '11899A43-2B68-4A76-92E3-A3D6AD8C26CE' = '[MS-TSTS]: Terminal Services Terminal Server Runtime Interface'
                    '5CA4A760-EBB1-11CF-8611-00A0245420ED' = '[MS-TSTS]: Terminal Services Terminal Server Runtime Interface'
                    'BDE95FDF-EEE0-45DE-9E12-E5A61CD0D4FE' = '[MS-TSTS]: Terminal Services Terminal Server Runtime Interface'
                    '484809D6-4239-471B-B5BC-61DF8C23AC48' = '[MS-TSTS]: Terminal Services Terminal Server Runtime Interface'
                    '88143FD0-C28D-4B2B-8FEF-8D882F6A9390' = '[MS-TSTS]: Terminal Services Terminal Server Runtime Interface'
                    '1257B580-CE2F-4109-82D6-A9459D0BF6BC' = '[MS-TSTS]: Terminal Services Terminal Server Runtime Interface'
                    '53B46B02-C73B-4A3E-8DEE-B16B80672FC0' = '[MS-TSTS]: Terminal Services Terminal Server Runtime Interface'
                    'DDE02280-12B3-4E0B-937B-6747F6ACB286' = '[MS-UAMG]: Update Agent Management Protocol'
                    '112EDA6B-95B3-476F-9D90-AEE82C6B8181' = '[MS-UAMG]: Update Agent Management Protocol'
                    '144FE9B0-D23D-4A8B-8634-FB4457533B7A' = '[MS-UAMG]: Update Agent Management Protocol'
                    '70CF5C82-8642-42BB-9DBC-0CFD263C6C4F' = '[MS-UAMG]: Update Agent Management Protocol'
                    '49EBD502-4A96-41BD-9E3E-4C5057F4250C' = '[MS-UAMG]: Update Agent Management Protocol'
                    '7C907864-346C-4AEB-8F3F-57DA289F969F' = '[MS-UAMG]: Update Agent Management Protocol'
                    '46297823-9940-4C09-AED9-CD3EA6D05968' = '[MS-UAMG]: Update Agent Management Protocol'
                    '4CBDCB2D-1589-4BEB-BD1C-3E582FF0ADD0' = '[MS-UAMG]: Update Agent Management Protocol'
                    '8F45ABF1-F9AE-4B95-A933-F0F66E5056EA' = '[MS-UAMG]: Update Agent Management Protocol'
                    '6A92B07A-D821-4682-B423-5C805022CC4D' = '[MS-UAMG]: Update Agent Management Protocol'
                    '54A2CB2D-9A0C-48B6-8A50-9ABB69EE2D02' = '[MS-UAMG]: Update Agent Management Protocol'
                    '0D521700-A372-4BEF-828B-3D00C10ADEBD' = '[MS-UAMG]: Update Agent Management Protocol'
                    'C2BFB780-4539-4132-AB8C-0A8772013AB6' = '[MS-UAMG]: Update Agent Management Protocol'
                    '1518B460-6518-4172-940F-C75883B24CEB' = '[MS-UAMG]: Update Agent Management Protocol'
                    '81DDC1B8-9D35-47A6-B471-5B80F519223B' = '[MS-UAMG]: Update Agent Management Protocol'
                    'BC5513C8-B3B8-4BF7-A4D4-361C0D8C88BA' = '[MS-UAMG]: Update Agent Management Protocol'
                    'C1C2F21A-D2F4-4902-B5C6-8A081C19A890' = '[MS-UAMG]: Update Agent Management Protocol'
                    '07F7438C-7709-4CA5-B518-91279288134E' = '[MS-UAMG]: Update Agent Management Protocol'
                    'C97AD11B-F257-420B-9D9F-377F733F6F68' = '[MS-UAMG]: Update Agent Management Protocol'
                    '3A56BFB8-576C-43F7-9335-FE4838FD7E37' = '[MS-UAMG]: Update Agent Management Protocol'
                    '615C4269-7A48-43BD-96B7-BF6CA27D6C3E' = '[MS-UAMG]: Update Agent Management Protocol'
                    '004C6A2B-0C19-4C69-9F5C-A269B2560DB9' = '[MS-UAMG]: Update Agent Management Protocol'
                    '7366EA16-7A1A-4EA2-B042-973D3E9CD99B' = '[MS-UAMG]: Update Agent Management Protocol'
                    'A376DD5E-09D4-427F-AF7C-FED5B6E1C1D6' = '[MS-UAMG]: Update Agent Management Protocol'
                    '23857E3C-02BA-44A3-9423-B1C900805F37' = '[MS-UAMG]: Update Agent Management Protocol'
                    'B383CD1A-5CE9-4504-9F63-764B1236F191' = '[MS-UAMG]: Update Agent Management Protocol'
                    '76B3B17E-AED6-4DA5-85F0-83587F81ABE3' = '[MS-UAMG]: Update Agent Management Protocol'
                    '0BB8531D-7E8D-424F-986C-A0B8F60A3E7B' = '[MS-UAMG]: Update Agent Management Protocol'
                    '91CAF7B0-EB23-49ED-9937-C52D817F46F7' = '[MS-UAMG]: Update Agent Management Protocol'
                    '673425BF-C082-4C7C-BDFD-569464B8E0CE' = '[MS-UAMG]: Update Agent Management Protocol'
                    'EFF90582-2DDC-480F-A06D-60F3FBC362C3' = '[MS-UAMG]: Update Agent Management Protocol'
                    'D9A59339-E245-4DBD-9686-4D5763E39624' = '[MS-UAMG]: Update Agent Management Protocol'
                    '9B0353AA-0E52-44FF-B8B0-1F7FA0437F88' = '[MS-UAMG]: Update Agent Management Protocol'
                    '503626A3-8E14-4729-9355-0FE664BD2321' = '[MS-UAMG]: Update Agent Management Protocol'
                    '85713FA1-7796-4FA2-BE3B-E2D6124DD373' = '[MS-UAMG]: Update Agent Management Protocol'
                    '816858A4-260D-4260-933A-2585F1ABC76B' = '[MS-UAMG]: Update Agent Management Protocol'
                    '27E94B0D-5139-49A2-9A61-93522DC54652' = '[MS-UAMG]: Update Agent Management Protocol'
                    'E7A4D634-7942-4DD9-A111-82228BA33901' = '[MS-UAMG]: Update Agent Management Protocol'
                    'D40CFF62-E08C-4498-941A-01E25F0FD33C' = '[MS-UAMG]: Update Agent Management Protocol'
                    'ED8BFE40-A60B-42EA-9652-817DFCFA23EC' = '[MS-UAMG]: Update Agent Management Protocol'
                    'A7F04F3C-A290-435B-AADF-A116C3357A5C' = '[MS-UAMG]: Update Agent Management Protocol'
                    '4A2F5C31-CFD9-410E-B7FB-29A653973A0F' = '[MS-UAMG]: Update Agent Management Protocol'
                    'BE56A644-AF0E-4E0E-A311-C1D8E695CBFF' = '[MS-UAMG]: Update Agent Management Protocol'
                    '918EFD1E-B5D8-4C90-8540-AEB9BDC56F9D' = '[MS-UAMG]: Update Agent Management Protocol'
                    '04C6895D-EAF2-4034-97F3-311DE9BE413A' = '[MS-UAMG]: Update Agent Management Protocol'
                    '15FC031C-0652-4306-B2C3-F558B8F837E2' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '4DBCEE9A-6343-4651-B85F-5E75D74D983C' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '1E062B84-E5E6-4B4B-8A25-67B81E8F13E8' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '2ABD757F-2851-4997-9A13-47D2A885D6CA' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '9CBE50CA-F2D2-4BF4-ACE1-96896B729625' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '4DAA0135-E1D1-40F1-AAA5-3CC1E53221C3' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '3858C0D5-0F35-4BF5-9714-69874963BC36' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '40F73C8B-687D-4A13-8D96-3D7F2E683936' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '8F4B2F5D-EC15-4357-992F-473EF10975B9' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    'FC5D23E8-A88B-41A5-8DE0-2D2F73C5A630' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    'B07FEDD4-1682-4440-9189-A39B55194DC5' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '72AE6713-DCBB-4A03-B36B-371F6AC6B53D' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    'B6B22DA8-F903-4BE7-B492-C09D875AC9DA' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '538684E0-BA3D-4BC0-ACA9-164AFF85C2A9' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '75C8F324-F715-4FE3-A28E-F9011B61A4A1' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '90681B1D-6A7F-48E8-9061-31B7AA125322' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '9882F547-CFC3-420B-9750-00DFBEC50662' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '83BFB87F-43FB-4903-BAA6-127F01029EEC' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    'EE2D5DED-6236-4169-931D-B9778CE03DC6' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '9723F420-9355-42DE-AB66-E31BB15BEEAC' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '4AFC3636-DB01-4052-80C3-03BBCB8D3C69' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    'D99BDAAE-B13A-4178-9FDB-E27F16B4603E' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    'D68168C9-82A2-4F85-B6E9-74707C49A58F' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '13B50BFF-290A-47DD-8558-B7C58DB1A71A' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '6E6F6B40-977C-4069-BDDD-AC710059F8C0' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '9AA58360-CE33-4F92-B658-ED24B14425B8' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    'E0393303-90D4-4A97-AB71-E9B671EE2729' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '07E5C822-F00C-47A1-8FCE-B244DA56FD06' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '8326CD1D-CF59-4936-B786-5EFC08798E25' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '1BE2275A-B315-4F70-9E44-879B3A2A53F2' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '0316560B-5DB4-4ED9-BBB5-213436DDC0D9' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '14FBE036-3ED7-4E10-90E9-A5FF991AFF01' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '3B69D7F5-9D94-4648-91CA-79939BA263BF' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    'D5D23B6D-5A55-4492-9889-397A3C2D2DBC' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '88306BB2-E71F-478C-86A2-79DA200A0F11' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '118610B7-8D94-4030-B5B8-500889788E4E' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '0AC13689-3134-47C6-A17C-4669216801BE' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '0818A8EF-9BA9-40D8-A6F9-E22833CC771E' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '6788FAF9-214E-4B85-BA59-266953616E09' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    'B481498C-8354-45F9-84A0-0BDD2832A91F' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '10C5E575-7984-4E81-A56B-431F5F92AE42' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '38A0A9AB-7CC8-4693-AC07-1F28BD03C3DA' = '[MS-VDS]: Virtual Disk Service (VDS) Protocol'
                    '8FB6D884-2388-11D0-8C35-00C04FDA2795' = '[MS-W32T]: W32Time Remote Protocol'
                    '5422FD3A-D4B8-4CEF-A12E-E87D4CA22E90' = '[MS-WCCE]: Windows Client Certificate Enrollment Protocol'
                    'D99E6E70-FC88-11D0-B498-00A0C90312F3' = '[MS-WCCE]: Windows Client Certificate Enrollment Protocol'
                    '1A927394-352E-4553-AE3F-7CF4AAFCA620' = '[MS-WDSC]: Windows Deployment Services Control Protocol'
                    '6BFFD098-A112-3610-9833-46C3F87E345A' = '[MS-WKST]: Workstation Service Remote Protocol'
                    'F1E9C5B2-F59B-11D2-B362-00105A1F8177' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    '423EC01E-2E35-11D2-B604-00104B703EFD' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    '9556DC99-828C-11CF-A37E-00AA003240C7' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    'F309AD18-D86A-11D0-A075-00C04FB68820' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    '9A653086-174F-11D2-B5F9-00104B703EFD' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    'D4781CD6-E5D3-44DF-AD94-930EFE48A887' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    '44ACA674-E8FC-11D0-A07C-00C04FB68820' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    '541679AB-2E5F-11D3-B34E-00104BCC4B4A' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    '027947E1-D731-11CE-A357-000000000001' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    'A359DEC5-E813-4834-8A2A-BA7F1D777D76' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    'C49E32C6-BC8B-11D2-85D4-00105A1F8304' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    'C49E32C7-BC8B-11D2-85D4-00105A1F8304' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    '2C9273E0-1DC3-11D3-B364-00105A1F8177' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    '7C857801-7381-11CF-884D-00AA004B2E24' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    'DC12A681-737F-11CF-884D-00AA004B2E24' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    '8BC3F05E-D86B-11D0-A075-00C04FB68820' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    '44ACA675-E8FC-11D0-A07C-00C04FB68820' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    '1C1C45EE-4395-11D2-B60B-00104B703EFD' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    '674B6698-EE92-11D0-AD71-00C04FD8FDFF' = '[MS-WMI]: Windows Management Instrumentation Remote Protocol'
                    'FC910418-55CA-45EF-B264-83D4CE7D30E0' = '[MS-WSRM]: Windows System Resource Manager (WSRM) Protocol'
                    'C5CEBEE2-9DF5-4CDD-A08C-C2471BC144B4' = '[MS-WSRM]: Windows System Resource Manager (WSRM) Protocol'
                    'F31931A9-832D-481C-9503-887A0E6A79F0' = '[MS-WSRM]: Windows System Resource Manager (WSRM) Protocol'
                    '21546AE8-4DA5-445E-987F-627FEA39C5E8' = '[MS-WSRM]: Windows System Resource Manager (WSRM) Protocol'
                    'BC681469-9DD9-4BF4-9B3D-709F69EFE431' = '[MS-WSRM]: Windows System Resource Manager (WSRM) Protocol'
                    '4F7CA01C-A9E5-45B6-B142-2332A1339C1D' = '[MS-WSRM]: Windows System Resource Manager (WSRM) Protocol'
                    '2A3EB639-D134-422D-90D8-AAA1B5216202' = '[MS-WSRM]: Windows System Resource Manager (WSRM) Protocol'
                    '59602EB6-57B0-4FD8-AA4B-EBF06971FE15' = '[MS-WSRM]: Windows System Resource Manager (WSRM) Protocol'
                    '481E06CF-AB04-4498-8FFE-124A0A34296D' = '[MS-WSRM]: Windows System Resource Manager (WSRM) Protocol'
                    'E8BCFFAC-B864-4574-B2E8-F1FB21DFDC18' = '[MS-WSRM]: Windows System Resource Manager (WSRM) Protocol'
                    '943991A5-B3FE-41FA-9696-7F7B656EE34B' = '[MS-WSRM]: Windows System Resource Manager (WSRM) Protocol'
                    'BBA9CB76-EB0C-462C-AA1B-5D8C34415701' = '[MS-ADTS]: Active Directory Technical Specification'
                    '906B0CE0-C70B-1067-B317-00DD010662DA' = '[MS-CMPO]: MSDTC Connection Manager:'
                    'E3514235-4B06-11D1-AB04-00C04FC2DCD2' = '[MS-DRSR]: Directory Replication Service (DRS) Remote Protocol'
                    'F6BEAFF7-1E19-4FBB-9F8F-B89E2018337C' = '[MS-EVEN6]: EventLog Remoting Protocol'
                    'D049B186-814F-11D1-9A3C-00C04FC9B232' = '[MS-FRS1]: File Replication Service Protocol'
                    'F5CC59B4-4264-101A-8C59-08002B2F8426' = '[MS-FRS1]: File Replication Service Protocol'
                    '5A7B91F8-FF00-11D0-A9B2-00C04FB6E6FC' = '[MS-MSRP]: Messenger Service Remote Protocol'
                    'F5CC5A18-4264-101A-8C59-08002B2F8426' = '[MS-NSPI]: Name Service Provider Interface (NSPI) Protocol'
                    'E33C0CC4-0482-101A-BC0C-02608C6BA218' = '[MS-RPCL]: Remote Procedure Call Location Services Extensions'
                    'AFA8BD80-7D8A-11C9-BEF4-08002B102989' = '[MS-RPCE]: Remote Management Interface'
                    '00000134-0000-0000-C000-000000000046' = '[MS-DCOM]: Distributed Component Object Model (DCOM)'
                    '18F70770-8E64-11CF-9AF1-0020AF6E72F4' = '[MS-DCOM]: Distributed Component Object Model (DCOM)'
                    '958F92D8-DA20-467A-BBE3-65E7E9B4EDCF' = '[MS-TSGU]: Terminal Services Gateway Server Management Interface'
                    '6050B110-CE87-4126-A114-50AEFCFC95F8' = '[MS-DCOM]: Distributed Component Object Model (DCOM)'
                    '1544F5E0-613C-11D1-93DF-00C04FD7BD09' = '[MS-OXABREF]: Address Book Name Service Provider Interface (NSPI) Referral Protocol'
                    'A4F1DB00-CA47-1067-B31F-00DD010662DA' = '[MS-OXCRPC]: Wire Format Protocol'
                    '5261574A-4572-206E-B268-6B199213B4E4' = '[MS-OXCRPC]: Wire Format Protocol'
                    'b25a52bf-e5dd-4f4a-aea6-8ca7272a0e86' = '[MS-Unknown]: LSASS - CNG Key Isolation https://learn.microsoft.com/en-us/windows/win32/seccng/key-storage-and-retrieval'
                    '51a227ae-825b-41f2-b4a9-1ac9557a1018' = 'Ngc Pop Key Service'
                    '29770a8f-829b-4158-90a2-78cd488501f7' = ''
                }

                Set-StrictMode -Version Latest
                $PInvokeCode = @'
        using System;
        using System.Collections.Generic;
        using System.Runtime.InteropServices;

        public class Rpc
        {
            // I found this crud in RpcDce.h

            [DllImport("Rpcrt4.dll", CharSet = CharSet.Auto)]
            public static extern int RpcBindingFromStringBinding(string StringBinding, out IntPtr Binding);

            [DllImport("Rpcrt4.dll")]
            public static extern int RpcBindingFree(ref IntPtr Binding);

            [DllImport("Rpcrt4.dll", CharSet = CharSet.Auto)]
            public static extern int RpcMgmtEpEltInqBegin(IntPtr EpBinding,
                                                    int InquiryType, // 0x00000000 = RPC_C_EP_ALL_ELTS
                                                    int IfId,
                                                    int VersOption,
                                                    string ObjectUuid,
                                                    out IntPtr InquiryContext);

            [DllImport("Rpcrt4.dll", CharSet = CharSet.Auto)]
            public static extern int RpcMgmtEpEltInqNext(IntPtr InquiryContext,
                                                    out RPC_IF_ID IfId,
                                                    out IntPtr Binding,
                                                    out Guid ObjectUuid,
                                                    out IntPtr Annotation);

            [DllImport("Rpcrt4.dll", CharSet = CharSet.Auto)]
            public static extern int RpcBindingToStringBinding(IntPtr Binding, out IntPtr StringBinding);

            public struct RPC_IF_ID
            {
                public Guid Uuid;
                public ushort VersMajor;
                public ushort VersMinor;
            }

            // Returns a dictionary of <Uuid, port>
            public static Dictionary<int, string> QueryEPM(string host)
            {
                Dictionary<int, string> ports_and_uuids = new Dictionary<int, string>();
                int retCode = 0; // RPC_S_OK

                IntPtr bindingHandle = IntPtr.Zero;
                IntPtr inquiryContext = IntPtr.Zero;
                IntPtr elementBindingHandle = IntPtr.Zero;
                RPC_IF_ID elementIfId;
                Guid elementUuid;
                IntPtr elementAnnotation;

                try
                {
                    retCode = RpcBindingFromStringBinding("ncacn_ip_tcp:" + host, out bindingHandle);
                    if (retCode != 0)
                        throw new Exception("RpcBindingFromStringBinding: " + retCode);

                    retCode = RpcMgmtEpEltInqBegin(bindingHandle, 0, 0, 0, string.Empty, out inquiryContext);
                    if (retCode != 0)
                        throw new Exception("RpcMgmtEpEltInqBegin: " + retCode);

                    do
                    {
                        IntPtr bindString = IntPtr.Zero;
                        retCode = RpcMgmtEpEltInqNext (inquiryContext, out elementIfId, out elementBindingHandle, out elementUuid, out elementAnnotation);
                        if (retCode != 0)
                            if (retCode == 1772)
                                break;

                        retCode = RpcBindingToStringBinding(elementBindingHandle, out bindString);
                        if (retCode != 0)
                            throw new Exception("RpcBindingToStringBinding: " + retCode);

                        string s = Marshal.PtrToStringAuto(bindString).Trim().ToLower();
                        if(s.StartsWith("ncacn_ip_tcp:"))
                            if (ports_and_uuids.ContainsKey(int.Parse(s.Split('[')[1].Split(']')[0])) == false) ports_and_uuids.Add(int.Parse(s.Split('[')[1].Split(']')[0]), elementIfId.Uuid.ToString());

                        RpcBindingFree(ref elementBindingHandle);

                    }
                    while (retCode != 1772); // RPC_X_NO_MORE_ENTRIES

                }
                catch(Exception ex)
                {
                    Console.WriteLine(ex);
                    return ports_and_uuids;
                }
                finally
                {
                    RpcBindingFree(ref bindingHandle);
                }

                return ports_and_uuids;
            }
        }
'@

                try {
                    [rpc] | Out-Null
                }
                catch {
                    Add-Type $PInvokeCode
                }
            }
            PROCESS {
                [Bool]$EPMOpen = $False
                $Socket = New-Object Net.Sockets.TcpClient

                Try {
                    $Socket.Connect($ComputerName, 135)
                    If ($Socket.Connected) {
                        $EPMOpen = $True
                    }
                    $Socket.Close()
                }
                Catch {
                    $Socket.Dispose()
                }

                If ($EPMOpen) {
                    # Dictionary <Uuid, Port>
                    $RPC_ports_and_uuids = [Rpc]::QueryEPM($ComputerName)
                    #$PortDeDup = ($RPC_ports_and_uuids.Keys) | Sort-Object -Unique
                    Foreach ($Port In $RPC_ports_and_uuids.Keys) {
                        $Socket = New-Object Net.Sockets.TcpClient
                        Try {
                            Write-Verbose "Testing Adress: [$ComputerName], Port: [$Port], TimeOut: [$TimeOut]"
                            $Result = $Socket.BeginConnect("$ComputerName", "$Port", $null, $null)
                            if (!$Result.AsyncWaitHandle.WaitOne($timeout, $False)) {
                                throw [System.Exception]::new('Connection Timeout')
                            }

                            $socket.EndConnect($Result) | Out-Null
                            #    $Socket.Connect($ComputerName, $Port)
                            If ($Socket.Connected) {
                                $PortReachable = $True
                                $LocalAddress = $Socket.Client.LocalEndPoint.Address.IPAddressToString
                                $RemoteAddress = $Socket.Client.RemoteEndPoint.Address.IPAddressToString
                            }
                            $Socket.Close()
                        }
                        Catch {
                            $PortReachable = $False
                            $LocalAddress = $Socket.Client.LocalEndPoint.Address.IPAddressToString
                            $RemoteAddress = "" #$socket.Client.RemoteEndPoint.Address.IPAddressToString
                            $Socket.Dispose()
                        }
                        [PSCustomObject]@{
                            Port          = $Port
                            Reachable     = $PortReachable
                            LocalAddress  = $LocalAddress
                            RemoteAddress = $RemoteAddress
                            UUID          = $RPC_ports_and_uuids[$port]
                            Protocol      = $KnownUUIDS[$RPC_ports_and_uuids[$port]]
                        }
                    }

                }
            }
            END {
            }
        }
        Function TestTCP {
            [CmdletBinding()]
            Param(
                $Address,
                $Port,
                $TimeOut = 2000
            )

            $Socket = New-Object System.Net.Sockets.TcpClient
            Write-Verbose "Function Address: [$Address], Port: [$Port], TimeOut: [$TimeOut]"
            try {
                $result = $socket.BeginConnect("$address", "$port", $null, $null)
                if (!$result.AsyncWaitHandle.WaitOne($timeout, $False)) {
                    throw [System.Exception]::new('Connection Timeout')
                }
                $socket.EndConnect($result) | Out-Null
                [PSCustomObject]@{
                    Target        = $Address
                    Port          = $Port
                    Result        = if ($socket.Connected -eq 'True') { $true } else { $False }
                    LocalAddress  = $Socket.Client.LocalEndPoint.Address.IPAddressToString
                    RemoteAddress = $socket.Client.RemoteEndPoint.Address.IPAddressToString
                }
            }
            catch {
                [PSCustomObject]@{
                    Target        = $Address
                    Port          = $Port
                    Result        = $False
                    LocalAddress  = $Socket.Client.LocalEndPoint.Address.IPAddressToString
                    RemoteAddress = $socket.Client.RemoteEndPoint.Address.IPAddressToString
                }
            }

            finally {
                $socket.Close()
            }
        }

        if ($Scenario -eq 'ADCS') {
            $PortDescription = @{
                445  = "SMB"
                135  = "RPC Endpoint Mapper"
            }
            $Port = $PortDescription.Keys

            $UUIDRequirements = "91ae6020-9e3c-11cf-8d7c-00aa00c091be" #[MS-ICPR]: ICertPassage Remote Protocol

            $CheckRPC = $True
        }

        if ($Scenario -eq 'ActiveDirectoryServer') {
            $PortDescription = @{
                53   = "DNS (TCP)"
                88   = "Kerberos KDC (TCP)"
                135  = "RPC"
                389  = "LDAP"
                636  = "LDAPS"
                445  = "SMB"
                464  = "Kerberos Password Change"
                9389 = "Active Directory Web Services"
                3268 = "Global Catalog"
                3269 = "Global Catalog TLS"
            }
            $Port = $PortDescription.Keys

            $CheckRPC = $True
        }


        if ($Scenario -eq 'ExchangeServer') {
            $PortDescription = @{
                25   = "SMTP"
                587  = "SMTP TLS"
                135  = "RPC"
                443  = "HTTPS"
            }
            $Port = $PortDescription.Keys

            $CheckRPC = $True
        }

        if ($Scenario -eq 'MECMServer') {
            $PortDescription = @{
                135  = "RPC"
                80   = 'http'
                443  = 'https'
                445 = 'SMB (File Server)'
                8530 = 'WSUS'
                10123 = 'Client Notification'
            }
            $Port = $PortDescription.Keys

            $CheckRPC = $True
        }


        if ($Scenario -eq 'DHCPFailoverPartner') {
            $PortDescription = @{
                647  = "DHCP Failover"
            }
            $Port = $PortDescription.Keys

            $CheckRPC = $True
        }


        if ($Scenario -eq 'SQLServer') {
            Write-Warning "The scenario $scenario is just currently just a poc, do not solely rely on this output"
            $PortDescription = @{
                135  = "RPC"
                1433   = 'SQL Server Database Engine'
                1434  = 'SQL Server database engine, DAC, and SQL Servers "Browse" button.'
                2383 = 'Analysis Services'
                2725 = 'Analysis Services'
                3882 = 'DTS/SSIS'
                4022 = 'Conventional port for the SQL Broker service'
                5022 = 'AlwaysOn default port for primary and secondary replicas'
                7022 = 'Conventional port for Database Mirroring'
            }
            $Port = $PortDescription.Keys

            $CheckRPC = $True
        }

        if ($Scenario -eq 'WebServer') {
            $PortDescription = @{
                80  = "http"
                443 = "https"
            }
            $Port = $PortDescription.Keys
        }

    }
    Process {
        foreach ($TargetItem in $Target) {
            Write-Verbose "Process Block: Target: [$TargetItem] "
            foreach ($Portitem in $Port) {
                Write-Verbose "foreach Address: [$targetItem], Port: [$Portitem], TimeOut: [$TimeOut]"
                try {
                    $Result = TestTCP -Address $TargetItem -Port $PortItem -Timeout $Timeout
                }
                catch {
                    $Result = $false
                }

                [PSCustomObject]@{
                    Target          = $TargetItem
                    Port            = $PortItem
                    LocalAddress    = $Result.LocalAddress
                    RemoteAddress   = $Result.RemoteAddress
                    Reachable       = $Result.Result #-eq 'True') {'OK'} else {'Nope'}
                    PortDescription = try {$PortDescription[$Portitem]} catch {""}
                }
            }

            if ($CheckRPC) {
                try {
                    $rpcresult = Test-RPC  $TargetItem
                }
                catch {
                    <#Do this if a terminating exception happens#>
                }

                foreach ($RPCService in $RPCResult) {

                    if ($UUIDRequirements) {
                        if ($UUIDRequirements -contains $RPCService.UUID) {continue}
                    }

                    [PSCustomObject]@{
                        Target          = $TargetItem
                        Port            = $RPCService.Port
                        LocalAddress    = if ($RPCService.LocalAddress) { $RPCService.LocalAddress } else { "" }
                        RemoteAddress   = if ($RPCService.RemoteAddress) { $RPCService.RemoteAddress } else { "" }
                        Reachable       = $RPCService.Reachable #-eq 'True') {'OK'} else {'Nope'}
                        PortDescription = "$($RPCService.UUID) - $($RPCService.Protocol)"
                    }
                }
            }
        }
    }
    End {

    }
}
