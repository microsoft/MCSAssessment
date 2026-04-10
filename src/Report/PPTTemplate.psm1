function Get-MCSTemplatePPT {
    $PPTXTemplate = (Join-Path -Path $PSScriptRoot -ChildPath "Template - MCSAW Consolidated Assessment Automated Deck.pptx")

    return $PPTXTemplate
}