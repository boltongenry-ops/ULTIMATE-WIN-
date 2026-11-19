# Run on the STA dispatcher so text editing does not require the runner to own the input desktop.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
$source=[IO.File]::ReadAllText((Resolve-Path 'app/ui.ps1'))
$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$null,[ref]$null)
foreach ($name in 'Row','Label','Table','Fill','SearchTable','FilterTable') {
    $definition=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
    . ([ScriptBlock]::Create($definition.Extent.Text))
}
$Controls=New-Object Windows.Controls.StackPanel
$Body=New-Object Windows.Controls.Grid
$Status=New-Object Windows.Controls.TextBlock
SearchTable
Table
Fill @([pscustomobject]@{Name='Alpha';Publisher='Test';Target=@{}},[pscustomobject]@{Name='Beta';Publisher='Other';Target=@{}})
$searchBox.Text='tesT'
if ($grid.Items.Count -ne 1 -or $grid.Items[0].Name -ne 'Alpha') {throw 'Publisher search failed'}
$searchBox.Text=[guid]::NewGuid().ToString()
if ($grid.Items.Count -ne 0) {throw 'Empty query result expected'}
$searchBox.Clear()
if ($grid.Items.Count -ne 2) {throw 'Inventory reset failed'}
