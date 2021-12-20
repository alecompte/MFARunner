
class Partner {
    [string]$DefaultDomain
    [array]$OtherDomains
    [String]$TenantId
    [Bool]$MFAEnabled
    [Bool]$Managed
    [Int]$LicensedUserCount
    [String]$PercentageMFA
    [Int]$PercentageMFANumeric
    [PSCustomObject]$MFADetails


}