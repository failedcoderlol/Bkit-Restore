exportButton.MouseButton1Click:Connect(function()
    exportButton.Text = "EXPORTING..."
    statusBox.Text = "Scanning scripts..."

    task.spawn(function()
        local ok, result = pcall(function()
            local text, exportStats = buildExportText()
            local copied = copyText(text)

            return {
                text = text,
                stats = exportStats,
                copied = copied,
            }
        end)

        if not ok then
            statusBox.Text = "Export failed:\n" .. tostring(result)
            exportButton.Text = "EXPORT ALL SCRIPTS"
            return
        end

        print(result.text)

        if result.copied then
            statusBox.Text =
                "✓ Export complete.\n\n" ..
                "Full script export copied to clipboard.\n\n" ..
                "Scripts scanned: " .. tostring(result.stats.scanned) .. "\n" ..
                "Sources exported: " .. tostring(result.stats.exported) .. "\n" ..
                "Unreadable/locked: " .. tostring(result.stats.unreadable) .. "\n" ..
                "Skipped exporter GUI: " .. tostring(result.stats.skipped)
        else
            statusBox.Text =
                "Export complete, but clipboard failed.\n\n" ..
                "The full export was printed to console.\n\n" ..
                "Sources exported: " .. tostring(result.stats.exported)
        end

        exportButton.Text = "EXPORT ALL SCRIPTS"
    end)
end)
