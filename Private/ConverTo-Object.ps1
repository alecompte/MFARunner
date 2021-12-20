
function ConvertTo-Object($hashtable) 
{
   $object = New-Object PSObject
   $hashtable.GetEnumerator() | 
      ForEach-Object { Add-Member -inputObject $object `
	  	-memberType NoteProperty -name $_.Name -value $_.Value }
   $object
}

