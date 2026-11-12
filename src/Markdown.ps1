# LEVEL51-TUNE :: minimal markdown -> HTML renderer
# ---------------------------------------------------------------------------
# Deliberately small: headings, fenced code, tables, flat lists, blockquotes,
# hr, paragraphs, inline code/bold/italic/links/strike, auto TOC of h2.
# All parser state lives in one hashtable so helpers stay scope-safe.
# ---------------------------------------------------------------------------

function Convert-L51Inline {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $t = [System.Net.WebUtility]::HtmlEncode($Text)
    $t = [regex]::Replace($t, '`([^`]+)`', '<code>$1</code>')
    $t = [regex]::Replace($t, '\*\*([^*]+)\*\*', '<strong>$1</strong>')
    $t = [regex]::Replace($t, '~~([^~]+)~~', '<del>$1</del>')
    $t = [regex]::Replace($t, '\[([^\]]+)\]\(([^)\s]+)\)', '<a href="$2">$1</a>')
    return $t
}

function Clear-L51MdPara {
    param($st)
    if ($st.Para.Count -gt 0) {
        $null = $st.Body.AppendLine('<p>' + (Convert-L51Inline ($st.Para -join ' ')) + '</p>')
        $st.Para.Clear()
    }
}

function Clear-L51MdList {
    param($st)
    if ($st.InList) {
        $null = $st.Body.AppendLine("</$($st.ListTag)>")
        $st.InList = $false
    }
}

function Clear-L51MdTable {
    param($st)
    if (-not $st.InTable) { return }
    $rows = @($st.TableRows)
    $st.TableRows.Clear()
    $st.InTable = $false
    if ($rows.Count -eq 0) { return }

    $header = $rows[0]
    $start = 1
    if ($rows.Count -gt 1 -and ($rows[1] -join '|') -match '^[\s:\-\|]+$') { $start = 2 }

    $null = $st.Body.AppendLine('<div class="table-wrap"><table>')
    $null = $st.Body.Append('<thead><tr>')
    foreach ($c in $header) { $null = $st.Body.Append('<th>' + (Convert-L51Inline ([string]$c).Trim()) + '</th>') }
    $null = $st.Body.AppendLine('</tr></thead>')
    if ($rows.Count -gt $start) {
        $null = $st.Body.AppendLine('<tbody>')
        for ($i = $start; $i -lt $rows.Count; $i++) {
            $null = $st.Body.Append('<tr>')
            foreach ($c in $rows[$i]) { $null = $st.Body.Append('<td>' + (Convert-L51Inline ([string]$c).Trim()) + '</td>') }
            $null = $st.Body.AppendLine('</tr>')
        }
        $null = $st.Body.AppendLine('</tbody>')
    }
    $null = $st.Body.AppendLine('</table></div>')
}

function Convert-L51Markdown {
    param(
        [Parameter(Mandatory)][string]$Markdown,
        [string]$DocTitle = ''
    )

    $st = @{
        Body       = New-Object System.Text.StringBuilder
        Para       = New-Object System.Collections.ArrayList
        TableRows  = New-Object System.Collections.ArrayList
        TOC        = New-Object System.Collections.ArrayList
        InCode     = $false
        CodeLang   = ''
        CodeBuf    = New-Object System.Collections.ArrayList
        InTable    = $false
        InList     = $false
        ListTag    = 'ul'
        InQuote    = $false
        HeadingNo  = 0
    }

    $lines = $Markdown -split "`r?`n"
    foreach ($line in $lines) {

        # ---- fenced code -------------------------------------------------
        if ($line -match '^\s*```(.*)$') {
            if (-not $st.InCode) {
                Clear-L51MdPara $st; Clear-L51MdTable $st; Clear-L51MdList $st
                $st.InCode = $true
                $st.CodeLang = $Matches[1].Trim()
                $st.CodeBuf.Clear()
            } else {
                $langClass = ''
                if ($st.CodeLang) { $langClass = ' class="lang-' + ($st.CodeLang -replace '[^a-zA-Z0-9\-]', '') + '"' }
                $encoded = [System.Net.WebUtility]::HtmlEncode(($st.CodeBuf -join "`n"))
                $null = $st.Body.AppendLine("<pre><code$langClass>$encoded</code></pre>")
                $st.InCode = $false
                $st.CodeLang = ''
                $st.CodeBuf.Clear()
            }
            continue
        }
        if ($st.InCode) { $null = $st.CodeBuf.Add($line); continue }

        # ---- table -------------------------------------------------------
        if ($line -match '^\s*\|.*\|\s*$') {
            Clear-L51MdPara $st; Clear-L51MdList $st
            $cells = @(($line.Trim().Trim('|')) -split '\|')
            $null = $st.TableRows.Add($cells)
            $st.InTable = $true
            continue
        } elseif ($st.InTable) { Clear-L51MdTable $st }

        # ---- blank -------------------------------------------------------
        if ($line -match '^\s*$') {
            Clear-L51MdPara $st; Clear-L51MdList $st
            if ($st.InQuote) { $null = $st.Body.AppendLine('</blockquote>'); $st.InQuote = $false }
            continue
        }

        # ---- hr ----------------------------------------------------------
        if ($line -match '^\s*(---+|\*\*\*+|___+)\s*$') {
            Clear-L51MdPara $st; Clear-L51MdList $st
            $null = $st.Body.AppendLine('<hr>')
            continue
        }

        # ---- headings ----------------------------------------------------
        if ($line -match '^(#{1,6})\s+(.+)$') {
            Clear-L51MdPara $st; Clear-L51MdList $st
            $level = $Matches[1].Length
            $text = $Matches[2].Trim()
            $st.HeadingNo = $st.HeadingNo + 1
            $id = "sec-$($st.HeadingNo)"
            $inline = Convert-L51Inline $text
            $null = $st.Body.AppendLine("<h$level id=`"$id`">$inline</h$level>")
            if ($level -eq 2) { $null = $st.TOC.Add([pscustomobject]@{ Id = $id; Text = $inline }) }
            continue
        }

        # ---- blockquote --------------------------------------------------
        if ($line -match '^\s*>\s?(.*)$') {
            Clear-L51MdPara $st; Clear-L51MdList $st
            if (-not $st.InQuote) { $null = $st.Body.AppendLine('<blockquote>'); $st.InQuote = $true }
            $null = $st.Body.AppendLine('<p>' + (Convert-L51Inline $Matches[1]) + '</p>')
            continue
        } elseif ($st.InQuote) {
            $null = $st.Body.AppendLine('</blockquote>')
            $st.InQuote = $false
        }

        # ---- lists (flat; indented items get a css class) -----------------
        if ($line -match '^(\s*)([-*+]|\d+[.)])\s+(.*)$') {
            Clear-L51MdPara $st
            $indent = $Matches[1].Length
            $marker = $Matches[2]
            $text = $Matches[3]
            $tag = 'ul'
            if ($marker -match '^\d') { $tag = 'ol' }
            if (-not $st.InList -or $tag -ne $st.ListTag) {
                Clear-L51MdList $st
                $st.ListTag = $tag
                $null = $st.Body.AppendLine("<$tag>")
                $st.InList = $true
            }
            $cls = ''
            if ($indent -ge 2) { $cls = ' class="nested"' }
            $null = $st.Body.AppendLine("<li$cls>" + (Convert-L51Inline $text) + '</li>')
            continue
        }
        if ($st.InList) { Clear-L51MdList $st }

        # ---- paragraph ---------------------------------------------------
        $null = $st.Para.Add($line.Trim())
    }

    if ($st.InCode -and $st.CodeBuf.Count -gt 0) {
        $encoded = [System.Net.WebUtility]::HtmlEncode(($st.CodeBuf -join "`n"))
        $null = $st.Body.AppendLine("<pre><code>$encoded</code></pre>")
    }
    if ($st.InTable) { Clear-L51MdTable $st }
    Clear-L51MdPara $st
    Clear-L51MdList $st
    if ($st.InQuote) { $null = $st.Body.AppendLine('</blockquote>') }

    $html = $st.Body.ToString()
    if ($st.TOC.Count -ge 2) {
        $tocHtml = New-Object System.Text.StringBuilder
        $null = $tocHtml.AppendLine('<nav class="toc"><div class="toc-title">ในหน้านี้</div><ol>')
        foreach ($t in $st.TOC) { $null = $tocHtml.AppendLine(('<li><a href="#{0}">{1}</a></li>' -f $t.Id, $t.Text)) }
        $null = $tocHtml.AppendLine('</ol></nav>')
        $firstH2 = $html.IndexOf('<h2')
        if ($firstH2 -gt 0) { $html = $html.Insert($firstH2, $tocHtml.ToString()) }
    }
    return $html
}
