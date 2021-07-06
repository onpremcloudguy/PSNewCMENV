function New-GenerateUsers {
    param(
        [Parameter()]
        [int]
        $numofusers
    )
    $filepath = ".\users.csv"
    if (!(test-path $filepath)) {
        invoke-webrequest -uri "https://raw.githubusercontent.com/microsoft/sql-server-samples/master/samples/databases/adventure-works/oltp-install-script/Person.csv" -usebasicparsing -OutFile $filepath | Out-Null
    }
    $rawusers = import-csv -path $filepath -Header 'ID', 'a', 'b', 'title', 'FirstName', 'middlename', 'lastname', 'd', 'e', 'f', 'schema', 'date' -Delimiter '|'
    $filteredusers = $rawusers | Get-Random -Count ($numofusers * 2)  | Select-object -Property FirstName, middlename, lastname -Unique -First $numofusers
    return $filteredusers
}